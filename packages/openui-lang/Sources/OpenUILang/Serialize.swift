// OpenUILang — ElementNode → openui-lang source text serializer.
//
// Swift port of parser_serialize.ts (spec/language.md §9.2): the inverse of
// the parse + materialize pipeline. Output is compatible with
// mergeStatements() for patching existing programs.

import Foundation

// MARK: - Operator precedence (mirrors expressions.ts)

private let serializePrecedence: [String: Int] = [
    "||": 2, "&&": 3,
    "==": 4, "!=": 4,
    ">": 5, "<": 5, ">=": 5, "<=": 5,
    "+": 6, "-": 6,
    "*": 7, "/": 7, "%": 7,
]

// MARK: - Statement collector

private struct CollectedStatement {
    var id: String
    var text: String
}

private final class StatementCollector {
    private var statements: [CollectedStatement] = []
    private var registered = Set<String>()

    /// Register an ElementNode as a named statement.
    func register(id: String, text: String) {
        guard !registered.contains(id) else { return }
        registered.insert(id)
        statements.append(CollectedStatement(id: id, text: text))
    }

    func has(_ id: String) -> Bool { registered.contains(id) }
    func getStatements() -> [CollectedStatement] { statements }
}

// MARK: - AST node serializer

/// `calls` are the library's call names (built-ins, functions, actions),
/// written with `@`.
private func serializeASTNode(_ node: ASTNode, calls: [String: CallDef]) -> String {
    switch node {
    case .str(let s): return jsonStringLiteral(s)
    case .num(let n): return jsNumberString(n)
    case .bool(let b): return b ? "true" : "false"
    case .null: return "null"
    case .ph(let n): return n
    case .stateRef(let n): return n // already includes $ prefix
    case .runtimeRef(let n, _): return n
    case .ref(let n): return n
    case .arr(let els):
        return "[" + els.map { serializeASTNode($0, calls: calls) }.joined(separator: ", ") + "]"
    case .obj(let entries):
        // Spec §9.2: keys written unquoted; quote when not a valid name.
        return "{" + entries.map { (k, v) in
            "\(isBareName(k) ? k : jsonStringLiteral(k)): \(serializeASTNode(v, calls: calls))"
        }.joined(separator: ", ") + "}"
    case .binOp(let op, let left, let right):
        return "\(serializeBinOpOperand(left, parentOp: op, side: .left, calls: calls)) \(op) \(serializeBinOpOperand(right, parentOp: op, side: .right, calls: calls))"
    case .unaryOp(let op, let operand):
        // -(a + b): without parens the re-parse groups as (-a) + b.
        let inner = serializeASTNode(operand, calls: calls)
        switch operand {
        case .binOp, .ternary: return "\(op)(\(inner))"
        default: return "\(op)\(inner)"
        }
    case .ternary(let cond, let then, let els):
        return "\(serializeASTNode(cond, calls: calls)) ? \(serializeASTNode(then, calls: calls)) : \(serializeASTNode(els, calls: calls))"
    case .member(let obj, let field):
        return "\(serializeTightOperand(obj, calls: calls)).\(field)"
    case .index(let obj, let index):
        return "\(serializeTightOperand(obj, calls: calls))[\(serializeASTNode(index, calls: calls))]"
    case .assign(let target, let value):
        return "\(target) = \(serializeASTNode(value, calls: calls))"
    case .comp(let name, let args, _, _):
        let argText = args.map { serializeASTNode($0, calls: calls) }.joined(separator: ", ")
        // Built-ins, library functions and actions (not Action) → @-prefix.
        // Action, reserved calls (Query/Mutation), catalog components → no prefix.
        if calls[name] != nil && name != "Action" {
            return "@\(name)(\(argText))"
        }
        return "\(name)(\(argText))"
    }
}

private enum BinOpSide { case left, right }

/// Parenthesize a BinOp operand where re-parsing would change the grouping
/// (spec §9.2): a lower-precedence child, a ternary child, or — on the right
/// side — an equal-precedence child (`a - (b - c)` re-parses as `(a - b) - c`
/// without them; the left side is safe because BinOps are left-associative).
/// Upstream only handled the lower-precedence case.
private func serializeBinOpOperand(_ child: ASTNode, parentOp: String, side: BinOpSide, calls: [String: CallDef]) -> String {
    let inner = serializeASTNode(child, calls: calls)
    switch child {
    case .binOp(let childOp, _, _):
        let parentPrec = serializePrecedence[parentOp] ?? 0
        let childPrec = serializePrecedence[childOp] ?? 0
        if childPrec < parentPrec { return "(\(inner))" }
        if side == .right && childPrec <= parentPrec { return "(\(inner))" }
        return inner
    case .ternary:
        // (a ? b : c) + d re-parses as a ? b : (c + d) without parens.
        return "(\(inner))"
    default:
        return inner
    }
}

/// The object of `.` / `[...]`: BinOp, ternary, and unary children regroup on
/// re-parse (`(a + b).x` vs `a + b.x`), so they keep their parens.
private func serializeTightOperand(_ obj: ASTNode, calls: [String: CallDef]) -> String {
    let inner = serializeASTNode(obj, calls: calls)
    switch obj {
    case .binOp, .ternary, .unaryOp: return "(\(inner))"
    default: return inner
    }
}

// MARK: - Materialized value serializer

private func serializeValue(_ value: Materialized, params: [String: [ParamDef]], calls: [String: CallDef], collector: StatementCollector) -> String {
    switch value {
    case .null: return "null"
    case .value(let v): return serializeRuntimeValue(v, params: params, calls: calls, collector: collector)
    case .expr(let node): return serializeASTNode(node, calls: calls)
    case .element(let el): return serializeElementValue(el, params: params, calls: calls, collector: collector)
    case .array(let items):
        return "[" + items.map { serializeValue($0, params: params, calls: calls, collector: collector) }.joined(separator: ", ") + "]"
    case .object(let entries):
        return "{" + entries.map { (k, v) in
            "\(isBareName(k) ? k : jsonStringLiteral(k)): \(serializeValue(v, params: params, calls: calls, collector: collector))"
        }.joined(separator: ", ") + "}"
    }
}

private func serializeRuntimeValue(_ value: Value, params: [String: [ParamDef]], calls: [String: CallDef], collector: StatementCollector) -> String {
    switch value {
    case .string(let s): return jsonStringLiteral(s)
    case .number(let n): return jsNumberString(n)
    case .boolean(let b): return b ? "true" : "false"
    case .null: return "null"
    case .array(let a):
        return "[" + a.map { serializeRuntimeValue($0, params: params, calls: calls, collector: collector) }.joined(separator: ", ") + "]"
    case .object(let fields):
        return "{" + fields.map { f in
            "\(isBareName(f.key) ? f.key : jsonStringLiteral(f.key)): \(serializeRuntimeValue(f.value, params: params, calls: calls, collector: collector))"
        }.joined(separator: ", ") + "}"
    case .element(let el): return serializeEvaluatedElement(el, params: params, calls: calls, collector: collector)
    case .binding(let name): return "{\"$binding\": \(jsonStringLiteral(name))}"
    case .actionPlan(let plan): return serializeActionPlan(plan, calls: calls)
    }
}

private func serializeActionPlan(_ plan: ActionPlan, calls: [String: CallDef]) -> String {
    let steps = plan.steps.map { serializeActionStep($0, calls: calls) }
    if steps.count == 1 { return steps[0] }
    return "Action([\(steps.joined(separator: ", "))])"
}

private func serializeActionStep(_ step: ActionStep, calls: [String: CallDef]) -> String {
    switch step {
    case .run(let statementId, _): return "@Run(\(statementId))"
    case .continueConversation(let messageAST, let contextAST):
        let msg = serializeASTNode(messageAST, calls: calls)
        if let ctx = contextAST {
            return "@ToAssistant(" + msg + ", " + serializeASTNode(ctx, calls: calls) + ")"
        }
        return "@ToAssistant(" + msg + ")"
    case .openUrl(let urlAST):
        return "@OpenUrl(" + serializeASTNode(urlAST, calls: calls) + ")"
    case .set(let target, let valueAST):
        return "@Set(" + target + ", " + serializeASTNode(valueAST, calls: calls) + ")"
    case .reset(let targets):
        return "@Reset(\(targets.map(jsonStringLiteral).joined(separator: ", ")))"
    case .custom(let name, let args):
        let argText = args.map { serializeASTNode($0.1, calls: calls) }.joined(separator: ", ")
        return "@\(name)(\(argText))"
    }
}

/// Serialize an ElementNode — as a bare reference when it has a statementId
/// (registering its statement depth-first, so children come before parents),
/// or inline otherwise.
private func serializeElementValue(_ node: ElementNode, params: [String: [ParamDef]], calls: [String: CallDef], collector: StatementCollector) -> String {
    if let id = node.statementId {
        if !collector.has(id) {
            // Serialize the expression first (depth-first → children registered before parent)
            let expr = serializeElementExpr(node, params: params, calls: calls, collector: collector)
            collector.register(id: id, text: "\(id) = \(expr)")
        }
        return id
    }
    return serializeElementExpr(node, params: params, calls: calls, collector: collector)
}

/// Serialize an EvaluatedElement by converting Values back to Materialized.
private func serializeEvaluatedElement(_ node: EvaluatedElement, params: [String: [ParamDef]], calls: [String: CallDef], collector: StatementCollector) -> String {
    let props = node.props.map { PropEntry(key: $0.0, value: .value($0.1)) }
    let el = ElementNode(typeName: node.typeName, props: props, statementId: node.statementId, partial: node.partial)
    return serializeElementValue(el, params: params, calls: calls, collector: collector)
}

// MARK: - ElementNode → expression string

private func serializeElementExpr(_ node: ElementNode, params: [String: [ParamDef]], calls: [String: CallDef], collector: StatementCollector) -> String {
    if let def = params[node.typeName] {
        // Map named props back to positional args using schema order.
        let byName = Dictionary(uniqueKeysWithValues: node.props.map { ($0.key, $0.value) })
        var args: [String] = def.map { param in
            serializeValue(byName[param.name] ?? .null, params: params, calls: calls, collector: collector)
        }

        // Trim trailing nulls for optional props.
        while let last = args.last, last == "null" {
            let param = def[args.count - 1]
            if param.required { break }
            args.removeLast()
        }

        return "\(node.typeName)(\(args.joined(separator: ", ")))"
    }

    // Unknown component — fallback to prop order.
    let fallback = node.props.map { serializeValue($0.value, params: params, calls: calls, collector: collector) }
    return "\(node.typeName)(\(fallback.joined(separator: ", ")))"
}

// MARK: - State declarations

private func serializeStateDeclarations(_ decls: [(String, Materialized)], params: [String: [ParamDef]], calls: [String: CallDef], collector: StatementCollector) -> [String] {
    var lines: [String] = []
    for (name, value) in decls {
        // Auto-declared null defaults ($var = null) are omitted for cleaner output.
        switch value {
        case .null, .value(.null): continue
        default: break
        }
        lines.append("\(name) = \(serializeValue(value, params: params, calls: calls, collector: collector))")
    }
    return lines
}

// MARK: - Public API

public struct SerializeOptions: Sendable {
    /// $variable declarations to include (e.g. from ParseResult.stateDeclarations).
    public var stateDeclarations: [(String, Materialized)]
    public init(stateDeclarations: [(String, Materialized)] = []) {
        self.stateDeclarations = stateDeclarations
    }
}

/// Convert an ElementNode tree back to openui-lang source text.
/// Output is compatible with `mergeStatements()` for patching existing programs.
///
/// - The entry statement comes first; every other named component becomes its
///   own statement, children before parents.
/// - Props are written by position in schema order; `null` holds an unfilled
///   required position; trailing nulls for optional props are trimmed.
/// - State declarations come after the component statements.
/// - `calls` decides the `@` prefix for call names; it defaults to the
///   built-ins, so pass the library's full callDefs for custom
///   functions/actions to keep their `@`.
public func jsonToOpenUI(
    _ tree: ElementNode,
    params: [String: [ParamDef]],
    calls: [String: CallDef] = builtinCallDefs,
    options: SerializeOptions = SerializeOptions()
) -> String {
    let collector = StatementCollector()

    // Serialize root — this recursively registers all child statements.
    let rootExpr = serializeElementExpr(tree, params: params, calls: calls, collector: collector)
    let rootId = tree.statementId ?? "root"

    var lines: [String] = ["\(rootId) = \(rootExpr)"]

    // Child statements (already in depth-first post-order from the collector).
    for stmt in collector.getStatements() {
        if stmt.id == rootId { continue } // skip root if also registered
        lines.append(stmt.text)
    }

    // State declarations.
    lines.append(contentsOf: serializeStateDeclarations(options.stateDeclarations, params: params, calls: calls, collector: collector))

    return lines.joined(separator: "\n")
}
