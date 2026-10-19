// OpenUILang — Action execution.
//
// Runs an `ActionPlan`'s steps in order (spec §6.3), producing host
// `ActionEvent`s. There is no upstream executor in the shipped sources (it
// lives in the framework adapters), so this follows the spec text and the
// `ActionEvent` shape in parser/types.ts.

import Foundation

/// Host-provided runtime for action execution.
public struct ActionRuntimeContext {
    /// The state store (`Set`/`Reset` write through it).
    public var store: StateStore
    /// Evaluate a (possibly deferred) AST to a value at step-run time.
    public var evaluate: (ASTNode) -> Value
    /// Declared `$variable` defaults, used by `Reset`.
    public var stateDefaults: [String: Value]
    /// Fire a query by statement id (fire-and-forget; never stops the plan).
    public var runQuery: (String) -> Void
    /// Run a mutation by statement id, awaiting its outcome.
    ///
    /// This is synchronous by contract: the host bridges to its async
    /// mutation runner (e.g. by blocking on the result) — a failed mutation
    /// STOPS the remaining steps of the plan.
    public var runMutation: (String) -> MutationOutcome
    /// Raw form state at step-run time, read lazily per step so a `@Set`
    /// earlier in the same `Action([...])` is visible to later steps.
    public var formState: () -> [(String, Value)]
    /// The form name that triggered this action, if any.
    public var formName: String?

    public init(
        store: StateStore,
        evaluate: @escaping (ASTNode) -> Value,
        stateDefaults: [String: Value] = [:],
        runQuery: @escaping (String) -> Void,
        runMutation: @escaping (String) -> MutationOutcome,
        formState: @escaping () -> [(String, Value)] = { [] },
        formName: String? = nil
    ) {
        self.store = store
        self.evaluate = evaluate
        self.stateDefaults = stateDefaults
        self.runQuery = runQuery
        self.runMutation = runMutation
        self.formState = formState
        self.formName = formName
    }
}

/// The synchronous outcome of running one mutation from an action plan.
public enum MutationOutcome {
    case success(Value)
    case failure
}

/// Run an action plan's steps in order (spec §6.3), returning the host events.
/// - `set` → evaluate `valueAST` NOW, `store.set` (not pristine).
/// - `reset` → restore declared defaults from `stateDefaults` (null if none).
/// - `run` → `runQuery`/`runMutation` by statement id. A failed mutation
///   STOPS the remaining steps; a query never stops the plan.
/// - `continueConversation` → `continue_conversation` event with the message,
///   an optional `context` param, and formState/formName as of this run.
/// - `openUrl` → `open_url` event.
/// - `custom` → event typed by the action name with args keyed by name.
public func runActionPlan(_ plan: ActionPlan, context: ActionRuntimeContext) -> [ActionEvent] {
    var events: [ActionEvent] = []
    for step in plan.steps {
        switch step {
        case .set(let target, let valueAST):
            context.store.set(target, value: context.evaluate(valueAST), pristine: false)

        case .reset(let targets):
            for target in targets {
                context.store.set(target, value: context.stateDefaults[target] ?? .null, pristine: false)
            }

        case .run(let statementId, let refType):
            switch refType {
            case .query:
                context.runQuery(statementId)
            case .mutation:
                switch context.runMutation(statementId) {
                case .success: break
                case .failure: return events // failed mutation stops remaining steps
                }
            }

        case .continueConversation(let messageAST, let contextAST):
            var params: [(String, Value)] = []
            if let contextAST = contextAST {
                params.append(("context", context.evaluate(contextAST)))
            }
            events.append(ActionEvent(
                type: "continue_conversation",
                params: params,
                humanFriendlyMessage: stringValue(context.evaluate(messageAST)),
                formState: context.formState(),
                formName: context.formName))

        case .openUrl(let urlAST):
            let url = context.evaluate(urlAST)
            events.append(ActionEvent(
                type: "open_url",
                params: [("url", url)],
                humanFriendlyMessage: "",
                formState: nil,
                formName: nil))

        case .custom(let name, let args):
            events.append(ActionEvent(
                type: name,
                params: args.map { ($0.0, context.evaluate($0.1)) },
                humanFriendlyMessage: "",
                formState: nil,
                formName: nil))
        }
    }
    return events
}

private func stringValue(_ value: Value) -> String {
    if case .string(let s) = value { return s }
    return ""
}
