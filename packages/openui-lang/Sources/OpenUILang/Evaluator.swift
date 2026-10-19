// OpenUILang — AST evaluator.
//
// Swift port of runtime/evaluator.ts `evaluate()`, runtime/evaluate-tree.ts
// `evaluateRoot`/`evaluateElementProps`, and runtime/evaluate-prop.ts
// `evaluatePropCore`. Framework-agnostic; no Apple imports.
//
// ECMA-262 semantics live in Builtins.swift (ouiToNumber, isLooselyEqual,
// isTruthy). This file handles AST dispatch, component materialization,
// action-plan building, @Each loop scoping, and reactive bindings.

import Foundation

/// The AST evaluator. One instance per evaluation pass.
public final class Evaluator {
    public let context: EvaluationContext
    public let store: StateStore
    public let schema: LibrarySchema
    public private(set) var errors: [OpenUIError] = []

    public init(context: EvaluationContext, store: StateStore, schema: LibrarySchema) {
        self.context = context
        self.store = store
        self.schema = schema
    }

    // MARK: - Main dispatch

    /// Evaluate an AST node to a runtime value.
    public func evaluate(_ node: ASTNode) -> Value {
        switch node {
        case .str(let s): return .string(s)
        case .num(let n): return .number(n)
        case .bool(let b): return .boolean(b)
        case .null: return .null
        case .ph: return .null

        case .stateRef(let n):
            if let extra = context.extraScope, let v = extra[n] { return v }
            return context.getState(n)

        case .ref(let n), .runtimeRef(let n, _):
            return context.resolveRef(n)

        case .arr(let els):
            return .array(els.map(evaluate))

        case .obj(let entries):
            return .object(entries.map { ObjectField(key: $0.0, value: evaluate($0.1)) })

        case .comp(let name, let args, let mappedProps, _):
            return evaluateComp(name: name, args: args, mappedProps: mappedProps)

        case .binOp(let op, let left, let right):
            return evaluateBinOp(op, left, right)

        case .unaryOp(let op, let operand):
            return evaluateUnaryOp(op, operand)

        case .ternary(let cond, let then, let els):
            return isTruthy(evaluate(cond)) ? evaluate(then) : evaluate(els)

        case .member(let obj, let field):
            return evaluateMember(obj, field)

        case .index(let obj, let idx):
            return evaluateIndex(obj, idx)

        case .assign(let target, _):
            // Reactive assign marker — resolved by the SwiftUI layer.
            return .binding(target)
        }
    }

    /// Evaluate a materialized value (for state defaults, element props).
    public func evaluateMaterialized(_ m: Materialized) -> Value {
        switch m {
        case .value(let v): return v
        case .expr(let e): return evaluate(e)
        case .element(let el): return .element(evaluateElementNode(el))
        case .array(let items): return .array(items.map(evaluateMaterialized))
        case .object(let fields):
            return .object(fields.map { ObjectField(key: $0.0, value: evaluateMaterialized($0.1)) })
        case .null: return .null
        }
    }

    // MARK: - Component calls

    private func evaluateComp(name: String, args: [ASTNode], mappedProps: [(String, ASTNode)]?) -> Value {
        // Built-in functions.
        if let impl = builtinImplementations[name] {
            if name == "Each" {
                return evaluateEach(args)
            }
            let named = namedArgs(name: name, args: args, mappedProps: mappedProps)
            let evaluated = named.mapValues { evaluate($0) }
            return impl(evaluated)
        }
        // Built-in action steps and Action([...]) → ActionPlan.
        if isBuiltinAction(name) || name == "Action" {
            return .actionPlan(evaluateActionCall(name: name, args: args))
        }
        // Custom library functions.
        if let fn = context.functions[name] {
            return callCustomFunction(name: name, fn: fn, args: args, mappedProps: mappedProps)
        }
        // Custom actions → one-step plan.
        if let actionDef = context.actions[name] {
            return .actionPlan(evaluateCustomAction(name: name, def: actionDef, args: args, mappedProps: mappedProps))
        }
        // Component with mapped props → EvaluatedElement.
        if let mappedProps = mappedProps {
            return .element(evaluateComponentElement(name: name, mappedProps: mappedProps))
        }
        return .null
    }

    private func namedArgs(name: String, args: [ASTNode], mappedProps: [(String, ASTNode)]?) -> [String: ASTNode] {
        if let mappedProps = mappedProps {
            return Dictionary(uniqueKeysWithValues: mappedProps)
        }
        let params = builtinCallDefs[name]?.params ?? []
        var out: [String: ASTNode] = [:]
        for (i, arg) in args.enumerated() where i < params.count {
            out[params[i].name] = arg
        }
        return out
    }

    private func evaluateComponentElement(name: String, mappedProps: [(String, ASTNode)]) -> EvaluatedElement {
        let paramDefs = schema.components[name] ?? []
        let bindable = Set(paramDefs.filter { $0.isBindable }.map { $0.name })
        var props: [(String, Value)] = []
        for (key, val) in mappedProps {
            let evaluated: Value
            if case .stateRef(let target) = val, bindable.contains(key) {
                evaluated = .binding(target)
            } else {
                evaluated = evaluatePropTree(evaluate(val))
            }
            props.append((key, evaluated))
        }
        return EvaluatedElement(typeName: name, props: props)
    }

    /// Evaluate an ElementNode (from materialize) to an EvaluatedElement.
    public func evaluateElementNode(_ el: ElementNode) -> EvaluatedElement {
        let paramDefs = schema.components[el.typeName] ?? []
        let bindable = Set(paramDefs.filter { $0.isBindable }.map { $0.name })
        var props: [(String, Value)] = []
        for entry in el.props {
            let evaluated: Value
            // Bindable prop + StateRef → reactive binding marker.
            if bindable.contains(entry.key),
               case .expr(.stateRef(let target)) = entry.value {
                evaluated = .binding(target)
            } else {
                evaluated = evaluatePropTree(evaluateMaterialized(entry.value))
            }
            props.append((entry.key, evaluated))
        }
        return EvaluatedElement(typeName: el.typeName, props: props,
                                statementId: el.statementId, partial: el.partial)
    }

    private func evaluatePropTree(_ value: Value) -> Value {
        switch value {
        case .array(let items):
            return .array(items.map(evaluatePropTree))
        case .element(let el):
            // Already evaluated.
            return .element(el)
        case .actionPlan(let plan):
            return .actionPlan(plan)
        default:
            return value
        }
    }

    // MARK: - Operators

    private func evaluateBinOp(_ op: String, _ left: ASTNode, _ right: ASTNode) -> Value {
        if op == "&&" {
            let l = evaluate(left)
            return isTruthy(l) ? evaluate(right) : l
        }
        if op == "||" {
            let l = evaluate(left)
            return isTruthy(l) ? l : evaluate(right)
        }
        let l = evaluate(left)
        let r = evaluate(right)
        switch op {
        case "+":
            if case .string = l { return .string(concatString(l) + concatString(r)) }
            if case .string = r { return .string(concatString(l) + concatString(r)) }
            return .number(ouiToNumber(l) + ouiToNumber(r))
        case "-": return .number(ouiToNumber(l) - ouiToNumber(r))
        case "*": return .number(ouiToNumber(l) * ouiToNumber(r))
        case "/":
            let d = ouiToNumber(r)
            return .number(d == 0 ? 0 : ouiToNumber(l) / d)
        case "%":
            let d = ouiToNumber(r)
            return .number(d == 0 ? 0 : ouiToNumber(l).truncatingRemainder(dividingBy: d))
        case "==": return .boolean(isLooselyEqual(l, r))
        case "!=": return .boolean(!isLooselyEqual(l, r))
        case ">": return .boolean(ouiToNumber(l) > ouiToNumber(r))
        case "<": return .boolean(ouiToNumber(l) < ouiToNumber(r))
        case ">=": return .boolean(ouiToNumber(l) >= ouiToNumber(r))
        case "<=": return .boolean(ouiToNumber(l) <= ouiToNumber(r))
        default: return .null
        }
    }

    private func evaluateUnaryOp(_ op: String, _ operand: ASTNode) -> Value {
        let v = evaluate(operand)
        if op == "!" { return .boolean(!isTruthy(v)) }
        if op == "-" { return .number(-ouiToNumber(v)) }
        return .null
    }

    private func evaluateMember(_ obj: ASTNode, _ field: String) -> Value {
        let o = evaluate(obj)
        if case .null = o { return .null }
        switch o {
        case .array(let items):
            if field == "length" { return .number(Double(items.count)) }
            return .array(items.map { item in
                switch item {
                case .object(let fields):
                    return fields.first(where: { $0.key == field })?.value ?? .null
                case .array(let arr):
                    if let i = Int(field), i >= 0, i < arr.count {
                        return arr[i]
                    }
                    return .null
                default:
                    return .null
                }
            })
        case .object(let fields):
            return fields.first(where: { $0.key == field })?.value ?? .null
        default:
            return .null
        }
    }

    private func evaluateIndex(_ obj: ASTNode, _ idx: ASTNode) -> Value {
        let o = evaluate(obj)
        let i = evaluate(idx)
        if case .null = o { return .null }
        if case .null = i { return .null }
        switch o {
        case .array(let items):
            let n = Int(ouiToNumber(i))
            guard n >= 0, n < items.count else { return .null }
            return items[n]
        case .object(let fields):
            return fields.first(where: { $0.key == ouiToString(i) })?.value ?? .null
        default:
            return .null
        }
    }

    // MARK: - @Each

    private func evaluateEach(_ args: [ASTNode]) -> Value {
        guard args.count >= 3 else { return .array([]) }
        let arr = evaluate(args[0])
        guard case .array(let items) = arr else { return .array([]) }
        let varName: String?
        switch args[1] {
        case .ref(let n): varName = n
        case .str(let s): varName = s
        default: varName = nil
        }
        guard let varName = varName else { return .array([]) }
        let template = args[2]
        return .array(items.map { item in
            let substituted = substituteRef(template, varName: varName, value: item)
            let child = Evaluator(
                context: EvaluationContext(
                    getState: context.getState,
                    resolveRef: { [resolveRef = context.resolveRef] name in
                        name == varName ? item : resolveRef(name)
                    },
                    functions: context.functions,
                    actions: context.actions,
                    reportError: context.reportError,
                    extraScope: context.extraScope
                ),
                store: store,
                schema: schema
            )
            let result = child.evaluate(substituted)
            if case .element(let el) = result {
                // Re-evaluate nested props with the child context.
                return .element(el)
            }
            return result
        })
    }

    /// Substitute all Ref(varName) nodes with a literal value.
    func substituteRef(_ node: ASTNode, varName: String, value: Value) -> ASTNode {
        switch node {
        case .ref(let n):
            return n == varName ? toLiteralAST(value) : node
        case .member(let obj, let field):
            let subObj = substituteRef(obj, varName: varName, value: value)
            if case .obj(let entries) = subObj,
               let entry = entries.first(where: { $0.0 == field }) {
                return entry.1
            }
            return .member(subObj, field)
        case .index(let obj, let idx):
            return .index(substituteRef(obj, varName: varName, value: value),
                          substituteRef(idx, varName: varName, value: value))
        case .binOp(let op, let l, let r):
            return .binOp(op, substituteRef(l, varName: varName, value: value),
                           substituteRef(r, varName: varName, value: value))
        case .unaryOp(let op, let o):
            return .unaryOp(op, substituteRef(o, varName: varName, value: value))
        case .ternary(let c, let t, let e):
            return .ternary(substituteRef(c, varName: varName, value: value),
                            substituteRef(t, varName: varName, value: value),
                            substituteRef(e, varName: varName, value: value))
        case .arr(let els):
            return .arr(els.map { substituteRef($0, varName: varName, value: value) })
        case .obj(let entries):
            return .obj(entries.map { ($0.0, substituteRef($0.1, varName: varName, value: value)) })
        case .comp(let name, let args, let mapped, let fn):
            let sub = { self.substituteRef($0, varName: varName, value: value) }
            let newMapped = mapped.map { $0.map { ($0.0, sub($0.1)) } }
            return .comp(name: name, args: args.map(sub), mappedProps: newMapped, fn: fn)
        case .assign(let target, let v):
            return .assign(target, substituteRef(v, varName: varName, value: value))
        default:
            return node
        }
    }

    // MARK: - Action plans

    private func evaluateActionCall(name: String, args: [ASTNode]) -> ActionPlan {
        if name == "Action" {
            guard !args.isEmpty else { return ActionPlan() }
            let list = evaluate(args[0])
            if case .array(let items) = list {
                var steps: [ActionStep] = []
                for item in items {
                    if case .actionPlan(let plan) = item {
                        steps.append(contentsOf: plan.steps)
                    }
                }
                return ActionPlan(steps: steps)
            }
            return ActionPlan()
        }
        switch name {
        case "Run":
            guard let first = args.first, case .runtimeRef(let n, let refType) = first else {
                return ActionPlan()
            }
            return ActionPlan(steps: [.run(statementId: n, refType: refType)])
        case "Set":
            guard args.count >= 2, case .stateRef(let target) = args[0] else {
                return ActionPlan()
            }
            return ActionPlan(steps: [.set(target: target, valueAST: args[1])])
        case "Reset":
            let targets = args.compactMap { arg -> String? in
                if case .stateRef(let n) = arg { return n }
                return nil
            }
            guard !targets.isEmpty else { return ActionPlan() }
            return ActionPlan(steps: [.reset(targets: targets)])
        case "ToAssistant":
            let msg = args.first ?? .null
            let ctx = args.count > 1 ? args[1] : nil
            return ActionPlan(steps: [.continueConversation(messageAST: msg, contextAST: ctx)])
        case "OpenUrl":
            let url = args.first ?? .null
            return ActionPlan(steps: [.openUrl(urlAST: url)])
        default:
            return ActionPlan()
        }
    }

    private func evaluateCustomAction(name: String, def: CallDef, args: [ASTNode], mappedProps: [(String, ASTNode)]?) -> ActionPlan {
        let named = namedArgs(name: name, args: args, mappedProps: mappedProps)
        for param in def.params where param.required {
            guard let arg = named[param.name], !isNullValue(evaluate(arg)) else {
                return ActionPlan()
            }
        }
        let evaluated = named.mapValues { evaluate($0) }
        let astArgs = named.map { ($0.key, $0.value) }
        // Store both AST (for summary) and evaluated values.
        return ActionPlan(steps: [.custom(name: name, args: astArgs)])
    }

    private func isNullValue(_ v: Value) -> Bool {
        if case .null = v { return true }
        return false
    }

    // MARK: - Custom functions

    private func callCustomFunction(name: String, fn: CustomFunction, args: [ASTNode], mappedProps: [(String, ASTNode)]?) -> Value {
        let named = namedArgs(name: name, args: args, mappedProps: mappedProps)
        for param in fn.params where param.required {
            if named[param.name] == nil { return .null }
        }
        let evaluated = named.mapValues { evaluate($0) }
        do {
            return try fn.fn(evaluated)
        } catch {
            let msg = "@\(name) threw: \(error.localizedDescription)"
            context.reportError?(msg)
            errors.append(OpenUIError(source: .runtime, code: .runtimeError, message: msg))
            return .null
        }
    }

    // MARK: - Root

    /// Evaluate the root element (or rootExpression).
    public func evaluateRoot(_ result: ParseResult) -> EvaluatedElement? {
        if let root = result.root {
            return evaluateElementNode(root)
        }
        if let expr = result.rootExpression {
            let value = evaluate(expr)
            if case .element(let el) = value {
                return el
            }
            errors.append(OpenUIError(source: .runtime, code: .noRoot,
                                      message: "root does not evaluate to a component",
                                      statementId: "root"))
            return nil
        }
        return nil
    }
}
