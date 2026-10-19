// OpenUISwiftUI — Streaming state machine.
//
// Swift port of react-lang's `useOpenUIState` hook. An ObservableObject that
// owns the streaming parser, state store, query manager, and the current
// evaluated element tree. Feed it chunks; it publishes updates.

import SwiftUI
import OpenUILang
import Combine

/// Streaming state machine for OpenUI. Feed chunks via `push(_:)`; the
/// published `root` updates as the stream progresses.
@MainActor
public final class OpenUIState: ObservableObject {
    // MARK: - Published state

    /// The current evaluated root element (nil while nothing renders).
    @Published public private(set) var root: EvaluatedElement?
    /// Parser + runtime errors.
    @Published public private(set) var errors: [OpenUIError] = []
    /// True after `complete()` is called.
    @Published public private(set) var isComplete: Bool = false
    /// Per-query lifecycle states (for Query spinners).
    @Published public private(set) var queryStates: [String: QueryState] = [:]

    // MARK: - Internal

    private var parser: OUIStreamingParserProtocol
    private var store: StateStore
    private var queryManager: QueryManager
    private let schema: LibrarySchema
    private let functions: [String: CustomFunction]
    private let toolProvider: ToolProvider?
    private var latestResult: ParseResult?
    private var streamGeneration = 0

    // MARK: - Init

    /// - Parameters:
    ///   - schema: The compiled component library.
    ///   - functions: Custom library functions (e.g. from `library.functions`).
    ///   - toolProvider: Backend for Query/Mutation tool calls (nil = no fetching).
    public init(
        schema: LibrarySchema,
        functions: [String: CustomFunction] = [:],
        toolProvider: ToolProvider? = nil
    ) {
        self.toolProvider = toolProvider
        self.schema = schema
        self.functions = functions
        self.parser = createStreamingParser(schema: schema)
        self.store = createStore()
        self.queryManager = QueryManager(provider: toolProvider)
    }

    // MARK: - Streaming

    /// Push a chunk of openui-lang source. Re-evaluates and publishes.
    public func push(_ chunk: String) {
        let result = parser.push(chunk, complete: false)
        update(from: result)
    }

    /// Mark the stream complete. After this, the result equals a batch parse.
    public func complete() {
        let result = parser.push("", complete: true)
        isComplete = true
        update(from: result)
    }

    /// Reset to initial state (for a new stream).
    public func reset() {
        streamGeneration += 1
        queryManager.dispose()
        queryManager = QueryManager(provider: toolProvider)
        parser = createStreamingParser(schema: schema)
        store = createStore()
        latestResult = nil
        root = nil
        errors = []
        queryStates = [:]
        isComplete = false
    }

    /// Explicitly fetch a declared Query after streaming completes.
    /// Results refresh the evaluated tree on the main actor.
    public func runQuery(statementId: String, tool: String, args: Value, defaults: Value = .null) {
        guard isComplete, let result = latestResult,
              result.queryStatements.contains(where: { $0.statementId == statementId }) else { return }
        let generation = streamGeneration
        queryManager.runQuery(statementId: statementId, tool: tool, args: args, defaults: defaults) { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, self.streamGeneration == generation, let result = self.latestResult else { return }
                self.update(from: result)
            }
        }
        update(from: result)
    }

    // MARK: - Private

    private func makeEvaluator(result: ParseResult) -> Evaluator {
        // Box for circular reference (resolveRef needs the evaluator for query defaults).
        final class Box { weak var evaluator: Evaluator! }
        let box = Box()
        let ctx = EvaluationContext(
            getState: { [store] name in store.get(name) ?? .null },
            resolveRef: { [result, queryManager] name in
                // Query → defaults (or fetched data if available); Mutation → idle.
                if let q = result.queryStatements.first(where: { $0.statementId == name }) {
                    if let state = queryManager.queryState(for: name),
                       state.status == .success, let data = state.data {
                        return data
                    }
                    if let defaultsAST = q.defaultsAST {
                        return box.evaluator.evaluate(defaultsAST)
                    }
                    return .null
                }
                if result.mutationStatements.contains(where: { $0.statementId == name }) {
                    return .object([
                        ObjectField(key: "status", value: .string("idle")),
                        ObjectField(key: "data", value: .null),
                        ObjectField(key: "error", value: .null),
                    ])
                }
                return .null
            },
            functions: functions,
            actions: schema.callDefs.filter { $0.value.kind == .action }
        )
        let evaluator = Evaluator(context: ctx, store: store, schema: schema)
        box.evaluator = evaluator
        return evaluator
    }

    private func update(from result: ParseResult) {
        latestResult = result
        // Initialize store with state declarations (pristine-set semantics).
        store.initialize(defaults: result.stateDeclarations, persisted: [:])
        let evaluator = makeEvaluator(result: result)
        // Queries do NOT run during streaming; they read defaults.
        // (QueryManager.fetch is called explicitly by the app, not here.)
        root = evaluator.evaluateRoot(result)
        errors = result.meta.errors + evaluator.errors
        // Update query states from the manager.
        var states: [String: QueryState] = [:]
        for q in result.queryStatements {
            states[q.statementId] = queryManager.queryState(for: q.statementId)
                ?? QueryState(status: .idle, data: nil, error: nil)
        }
        queryStates = states
    }
}
