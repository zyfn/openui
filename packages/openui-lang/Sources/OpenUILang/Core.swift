// OpenUILang — Core types.
//
// The single source of truth for the Swift port of OpenUI Lang 1.0
// (thesysdev/openui, spec/language.md + spec/prompt.md).
// All other files in this target build against the types declared here.

// MARK: - Values

/// An object field. Struct (not tuple) so Value can be Equatable.
public struct ObjectField: Equatable, Sendable {
    public var key: String
    public var value: Value
    public init(key: String, value: Value) {
        self.key = key
        self.value = value
    }
}

/// A runtime value in OpenUI Lang: the output of evaluation.
public indirect enum Value: Sendable {
    case string(String)
    case number(Double)
    case boolean(Bool)
    case null
    case array([Value])
    case object([ObjectField])
    case element(EvaluatedElement)
    case actionPlan(ActionPlan)
    /// A `$variable` passed to a `$binding<type>` prop: two-way binding marker.
    /// Summarizes as `{ "$binding": "$name" }`.
    case binding(String)
}

extension Value: Equatable {
    public static func == (lhs: Value, rhs: Value) -> Bool {
        switch (lhs, rhs) {
        case (.string(let a), .string(let b)): return a == b
        case (.number(let a), .number(let b)): return a == b
        case (.boolean(let a), .boolean(let b)): return a == b
        case (.null, .null): return true
        case (.array(let a), .array(let b)): return a == b
        case (.object(let a), .object(let b)): return a == b
        case (.element(let a), .element(let b)): return a == b
        case (.actionPlan(let a), .actionPlan(let b)): return a == b
        case (.binding(let a), .binding(let b)): return a == b
        default: return false
        }
    }
}

// MARK: - Materialized values (parser output)

/// The output of materialization: plain values, runtime expressions kept as
/// AST, component nodes, or null. Mirrors the `unknown` values in
/// parser/materialize.ts.
public indirect enum Materialized: Sendable {
    case value(Value)
    case expr(ASTNode)
    case element(ElementNode)
    case null
    case array([Materialized])
    case object([(String, Materialized)])
}

extension Materialized: Equatable {
    public static func == (lhs: Materialized, rhs: Materialized) -> Bool {
        switch (lhs, rhs) {
        case (.value(let a), .value(let b)): return a == b
        case (.expr, .expr): return false
        case (.element(let a), .element(let b)): return a == b
        case (.null, .null): return true
        case (.array(let a), .array(let b)): return a == b
        case (.object(let a), .object(let b)):
            guard a.count == b.count else { return false }
            return zip(a, b).allSatisfy { $0.0 == $1.0 && $0.1 == $1.1 }
        default: return false
        }
    }
}

/// A component prop entry.
public struct PropEntry: Equatable, Sendable {
    public var key: String
    public var value: Materialized
    public init(key: String, value: Materialized) {
        self.key = key
        self.value = value
    }
}

// MARK: - AST

/// Every value that can appear in an openui-lang expression.
/// Mirrors parser/ast.ts ASTNode.
public indirect enum ASTNode: Sendable {
    case comp(name: String, args: [ASTNode], mappedProps: [(String, ASTNode)]?, fn: Bool)
    case str(String)
    case num(Double)
    case bool(Bool)
    case null
    case arr([ASTNode])
    case obj([(String, ASTNode)])
    case ref(String)
    case ph(String) // placeholder for an unresolvable reference
    case stateRef(String) // $name
    case runtimeRef(String, refType: QueryRefType) // query/mutation result, resolved at runtime
    case binOp(String, ASTNode, ASTNode)
    case unaryOp(String, ASTNode)
    case ternary(ASTNode, ASTNode, ASTNode)
    case member(ASTNode, String)
    case index(ASTNode, ASTNode)
    case assign(String, ASTNode) // $name = expr inside an expression
}

public enum QueryRefType: String, Sendable {
    case query
    case mutation
}

/// Nodes that survive parser lowering and are resolved by the evaluator.
public func isRuntimeExpr(_ node: ASTNode) -> Bool {
    switch node {
    case .stateRef, .runtimeRef, .binOp, .unaryOp, .ternary, .member, .index, .assign:
        return true
    default:
        return false
    }
}

/// Walk every node of an AST.
public func walkAST(_ node: ASTNode, visit: (ASTNode) -> Void) {
    visit(node)
    switch node {
    case .comp(_, let args, let mapped, _):
        args.forEach { walkAST($0, visit: visit) }
        mapped?.forEach { walkAST($0.1, visit: visit) }
    case .arr(let els):
        els.forEach { walkAST($0, visit: visit) }
    case .obj(let entries):
        entries.forEach { walkAST($0.1, visit: visit) }
    case .binOp(_, let l, let r):
        walkAST(l, visit: visit); walkAST(r, visit: visit)
    case .unaryOp(_, let o):
        walkAST(o, visit: visit)
    case .ternary(let c, let t, let e):
        walkAST(c, visit: visit); walkAST(t, visit: visit); walkAST(e, visit: visit)
    case .member(let o, _):
        walkAST(o, visit: visit)
    case .index(let o, let i):
        walkAST(o, visit: visit); walkAST(i, visit: visit)
    case .assign(_, let v):
        walkAST(v, visit: visit)
    default:
        break
    }
}

/// Convert a plain value to a literal AST. Mirrors toLiteralAST.
public func toLiteralAST(_ value: Value) -> ASTNode {
    switch value {
    case .string(let s): return .str(s)
    case .number(let n): return .num(n)
    case .boolean(let b): return .bool(b)
    case .null: return .null
    case .array(let a): return .arr(a.map(toLiteralAST))
    case .object(let fields): return .obj(fields.map { ($0.key, toLiteralAST($0.value)) })
    case .element, .actionPlan, .binding: return .null
    }
}

/// Extract a literal value from an AST node, or nil if not fully literal.
/// Mirrors literalValue.
public func literalValue(_ node: ASTNode) -> Value? {
    switch node {
    case .str(let s): return .string(s)
    case .num(let n): return .number(n)
    case .bool(let b): return .boolean(b)
    case .null: return .null
    case .arr(let els):
        var out: [Value] = []
        for e in els { guard let v = literalValue(e) else { return nil }; out.append(v) }
        return .array(out)
    case .obj(let entries):
        var out: [ObjectField] = []
        for (k, e) in entries { guard let v = literalValue(e) else { return nil }; out.append(ObjectField(key: k, value: v)) }
        return .object(out)
    default:
        return nil
    }
}

// MARK: - Statements

public enum StatementKind: Sendable {
    case value
    case state
    case query
    case mutation
}

/// A classified statement. Mirrors parser/ast.ts Statement.
public struct Statement: Sendable {
    public var kind: StatementKind
    public var id: String
    /// For value/state: the expression. For query/mutation: the Comp call node.
    public var expr: ASTNode
    /// Pre-computed $variable deps for query statements.
    public var deps: [String]?
    public init(kind: StatementKind, id: String, expr: ASTNode, deps: [String]? = nil) {
        self.kind = kind
        self.id = id
        self.expr = expr
        self.deps = deps
    }
}

// MARK: - Element nodes

/// A fully resolved component node. Mirrors parser/types.ts ElementNode.
public struct ElementNode: Sendable {
    public var typeName: String
    public var props: [PropEntry]
    public var statementId: String?
    public var partial: Bool
    public var hasDynamicProps: Bool
    public init(typeName: String, props: [PropEntry] = [], statementId: String? = nil, partial: Bool = false, hasDynamicProps: Bool = true) {
        self.typeName = typeName
        self.props = props
        self.statementId = statementId
        self.partial = partial
        self.hasDynamicProps = hasDynamicProps
    }
}

/// An evaluated element tree: all props resolved to runtime Values.
/// Produced by Evaluator.evaluateRoot / evaluateElementProps.
public struct EvaluatedElement: Sendable, Equatable {
    public var typeName: String
    public var props: [(String, Value)]
    public var statementId: String?
    public var partial: Bool

    public init(typeName: String, props: [(String, Value)] = [], statementId: String? = nil, partial: Bool = false) {
        self.typeName = typeName
        self.props = props
        self.statementId = statementId
        self.partial = partial
    }

    public static func == (lhs: EvaluatedElement, rhs: EvaluatedElement) -> Bool {
        lhs.typeName == rhs.typeName && lhs.statementId == rhs.statementId &&
        lhs.partial == rhs.partial && lhs.props.count == rhs.props.count &&
        zip(lhs.props, rhs.props).allSatisfy { $0.0 == $1.0 && $0.1 == $1.1 }
    }
}

extension ElementNode: Equatable {
    public static func == (lhs: ElementNode, rhs: ElementNode) -> Bool {
        lhs.typeName == rhs.typeName && lhs.props == rhs.props
    }
}

// MARK: - Errors

public enum OpenUIErrorSource: String, Sendable {
    case parser
    case runtime
    case query
    case mutation
}

public enum OpenUIErrorCode: String, Sendable {
    case unknownComponent = "unknown-component"
    case missingRequired = "missing-required"
    case nullRequired = "null-required"
    case inlineReserved = "inline-reserved"
    case excessArgs = "excess-args"
    case typeMismatch = "type-mismatch"
    case unknownFunction = "unknown-function"
    case noRoot = "no-root"
    case parseFailed = "parse-failed"
    case parseException = "parse-exception"
    case runtimeError = "runtime-error"
    case renderError = "render-error"
    case toolNotFound = "tool-not-found"
    case toolError = "tool-error"
    case mcpError = "mcp-error"
}

/// Structured, LLM-friendly error. Mirrors parser/types.ts OpenUIError.
public struct OpenUIError: Sendable {
    public var source: OpenUIErrorSource
    public var code: OpenUIErrorCode
    public var message: String
    public var statementId: String?
    public var component: String?
    public var path: String?
    public var toolName: String?
    public var hint: String?
    public var severity: String? // "warning" when the page still renders
    public init(
        source: OpenUIErrorSource,
        code: OpenUIErrorCode,
        message: String,
        statementId: String? = nil,
        component: String? = nil,
        path: String? = nil,
        toolName: String? = nil,
        hint: String? = nil,
        severity: String? = nil
    ) {
        self.source = source
        self.code = code
        self.message = message
        self.statementId = statementId
        self.component = component
        self.path = path
        self.toolName = toolName
        self.hint = hint
        self.severity = severity
    }
}

// MARK: - Parse result

public struct ParseMeta: Sendable {
    public var incomplete: Bool
    public var unresolved: [String]
    public var orphaned: [String]
    public var statementCount: Int
    public var errors: [OpenUIError]
}

public struct QueryStatementInfo: Sendable {
    public var statementId: String
    public var toolAST: ASTNode?
    public var argsAST: ASTNode?
    public var defaultsAST: ASTNode?
    public var refreshAST: ASTNode?
    public var deps: [String]?
    public var complete: Bool
}

public struct MutationStatementInfo: Sendable {
    public var statementId: String
    public var toolAST: ASTNode?
    public var argsAST: ASTNode?
}

public struct ParseResult: Sendable {
    public var root: ElementNode?
    public var rootExpression: ASTNode?
    public var meta: ParseMeta
    /// $name → materialized default value.
    public var stateDeclarations: [(String, Materialized)]
    public var queryStatements: [QueryStatementInfo]
    public var mutationStatements: [MutationStatementInfo]
}

// MARK: - Actions

public enum ActionStep: Sendable {
    case run(statementId: String, refType: QueryRefType)
    case continueConversation(messageAST: ASTNode, contextAST: ASTNode?)
    case openUrl(urlAST: ASTNode)
    case set(target: String, valueAST: ASTNode)
    case reset(targets: [String])
    case custom(name: String, args: [(String, ASTNode)])
}

extension ActionStep: Equatable {
    public static func == (lhs: ActionStep, rhs: ActionStep) -> Bool {
        switch (lhs, rhs) {
        case (.run(let a, let b), .run(let c, let d)): return a == c && b == d
        case (.reset(let a), .reset(let b)): return a == b
        default: return false
        }
    }
}

public struct ActionPlan: Sendable {
    public var steps: [ActionStep]
    public init(steps: [ActionStep] = []) {
        self.steps = steps
    }
}

extension ActionPlan: Equatable {
    public static func == (lhs: ActionPlan, rhs: ActionPlan) -> Bool {
        lhs.steps == rhs.steps
    }
}

/// Host action event. Mirrors parser/types.ts ActionEvent.
public struct ActionEvent: Sendable {
    public var type: String
    public var params: [(String, Value)]
    public var humanFriendlyMessage: String
    public var formState: [(String, Value)]?
    public var formName: String?
}

// MARK: - JSON Schema (order-preserving)

/// Ordered JSON value. Object key order is preserved because the schema's
/// property order IS the positional argument order (spec/prompt.md §2.3).
public indirect enum JSONValue: Sendable {
    case string(String)
    case number(Double)
    case boolean(Bool)
    case null
    case array([JSONValue])
    case object([JSONField])
}

public struct JSONField: Sendable {
    public var key: String
    public var value: JSONValue
    public init(key: String, value: JSONValue) {
        self.key = key
        self.value = value
    }
}

/// Minimal JSON parser that preserves object key order.
/// Only what the schema reader needs; throws on malformed input.
public enum JSONParseError: Error {
    case unexpectedEnd
    case invalidToken(String)
}

public func parseJSONPreservingOrder(_ text: String) throws -> JSONValue {
    let chars = Array(text)
    var pos = 0

    func skipWS() {
        while pos < chars.count && (chars[pos] == " " || chars[pos] == "\t" || chars[pos] == "\n" || chars[pos] == "\r") {
            pos += 1
        }
    }
    func parseValue() throws -> JSONValue {
        skipWS()
        guard pos < chars.count else { throw JSONParseError.unexpectedEnd }
        let c = chars[pos]
        switch c {
        case "{": return try parseObject()
        case "[": return try parseArray()
        case "\"": return .string(try parseString())
        case "t": try expect("true"); return .boolean(true)
        case "f": try expect("false"); return .boolean(false)
        case "n": try expect("null"); return .null
        default: return try parseNumber()
        }
    }
    func expect(_ s: String) throws {
        for ch in s {
            guard pos < chars.count && chars[pos] == ch else { throw JSONParseError.invalidToken(s) }
            pos += 1
        }
    }
    func parseString() throws -> String {
        pos += 1 // opening quote
        var out = ""
        while pos < chars.count {
            let c = chars[pos]
            if c == "\"" { pos += 1; return out }
            if c == "\\" {
                pos += 1
                guard pos < chars.count else { throw JSONParseError.unexpectedEnd }
                let e = chars[pos]
                switch e {
                case "\"": out.append("\"")
                case "\\": out.append("\\")
                case "/": out.append("/")
                case "n": out.append("\n")
                case "t": out.append("\t")
                case "r": out.append("\r")
                case "b": out.append("\u{08}")
                case "f": out.append("\u{0C}")
                case "u":
                    guard pos + 4 < chars.count else { throw JSONParseError.unexpectedEnd }
                    let hex = String(chars[(pos + 1)...(pos + 4)])
                    guard let code = UInt32(hex, radix: 16), let scalar = Unicode.Scalar(code) else {
                        throw JSONParseError.invalidToken("\\u" + hex)
                    }
                    out.append(Character(scalar))
                    pos += 4
                default: out.append(e)
                }
                pos += 1
            } else {
                out.append(c)
                pos += 1
            }
        }
        throw JSONParseError.unexpectedEnd
    }
    func parseObject() throws -> JSONValue {
        pos += 1 // {
        var fields: [JSONField] = []
        skipWS()
        if pos < chars.count && chars[pos] == "}" { pos += 1; return .object(fields) }
        while true {
            skipWS()
            guard pos < chars.count && chars[pos] == "\"" else { throw JSONParseError.invalidToken("object key") }
            let key = try parseString()
            skipWS()
            guard pos < chars.count && chars[pos] == ":" else { throw JSONParseError.invalidToken(":") }
            pos += 1
            let value = try parseValue()
            fields.append(JSONField(key: key, value: value))
            skipWS()
            guard pos < chars.count else { throw JSONParseError.unexpectedEnd }
            if chars[pos] == "," { pos += 1; continue }
            if chars[pos] == "}" { pos += 1; return .object(fields) }
            throw JSONParseError.invalidToken(String(chars[pos]))
        }
    }
    func parseArray() throws -> JSONValue {
        pos += 1 // [
        var items: [JSONValue] = []
        skipWS()
        if pos < chars.count && chars[pos] == "]" { pos += 1; return .array(items) }
        while true {
            items.append(try parseValue())
            skipWS()
            guard pos < chars.count else { throw JSONParseError.unexpectedEnd }
            if chars[pos] == "," { pos += 1; continue }
            if chars[pos] == "]" { pos += 1; return .array(items) }
            throw JSONParseError.invalidToken(String(chars[pos]))
        }
    }
    func parseNumber() throws -> JSONValue {
        let start = pos
        if pos < chars.count && chars[pos] == "-" { pos += 1 }
        while pos < chars.count && chars[pos].isNumber { pos += 1 }
        if pos < chars.count && chars[pos] == "." {
            pos += 1
            while pos < chars.count && chars[pos].isNumber { pos += 1 }
        }
        if pos < chars.count && (chars[pos] == "e" || chars[pos] == "E") {
            pos += 1
            if pos < chars.count && (chars[pos] == "+" || chars[pos] == "-") { pos += 1 }
            while pos < chars.count && chars[pos].isNumber { pos += 1 }
        }
        let text = String(chars[start..<pos])
        guard let n = Double(text) else { throw JSONParseError.invalidToken(text) }
        return .number(n)
    }

    let v = try parseValue()
    skipWS()
    return v
}

extension JSONValue {
    /// Object field lookup.
    public func field(_ key: String) -> JSONValue? {
        guard case .object(let fields) = self else { return nil }
        return fields.first(where: { $0.key == key })?.value
    }
    public var objectFields: [(String, JSONValue)]? {
        guard case .object(let fields) = self else { return nil }
        return fields.map { ($0.key, $0.value) }
    }
    public var arrayItems: [JSONValue]? {
        guard case .array(let items) = self else { return nil }
        return items
    }
    public var stringValue: String? {
        guard case .string(let s) = self else { return nil }
        return s
    }
}

// MARK: - Library schema

/// A component parameter. Positional order = order in `params`.
public struct ParamDef: Sendable {
    public var name: String
    public var required: Bool
    public var hasDefault: Bool
    public var defaultValue: Value
    /// True when the signature prints this prop as `$binding<type>`.
    public var isBindable: Bool
    public var schema: JSONValue?
    public init(name: String, required: Bool, hasDefault: Bool = false, defaultValue: Value = .null, isBindable: Bool = false, schema: JSONValue? = nil) {
        self.name = name
        self.required = required
        self.hasDefault = hasDefault
        self.defaultValue = defaultValue
        self.isBindable = isBindable
        self.schema = schema
    }
}

public struct CallDef: Sendable {
    public enum Kind: Sendable { case function, action }
    public var kind: Kind
    public var params: [ParamDef]
    public var isBuiltin: Bool
    public var isLazy: Bool
    public init(kind: Kind, params: [ParamDef], isBuiltin: Bool = false, isLazy: Bool = false) {
        self.kind = kind
        self.params = params
        self.isBuiltin = isBuiltin
        self.isLazy = isLazy
    }
}

public struct FunctionSchema: Sendable {
    public var description: String?
    public var params: [ParamDef]
    public var returns: JSONValue?
}

/// The compiled library schema used by the parser/validator.
/// Mirrors the ParamMap produced by compileSchema.
public struct LibrarySchema: Sendable {
    /// Component name → params (positional order).
    public var components: [String: [ParamDef]]
    /// Built-in + custom function/action call defs.
    public var callDefs: [String: CallDef]
    public var rootComponent: String?
    public init(components: [String: [ParamDef]] = [:], callDefs: [String: CallDef] = [:], rootComponent: String? = nil) {
        self.components = components
        self.callDefs = callDefs
        self.rootComponent = rootComponent
    }
}

// MARK: - Built-in registry (mirrors parser/builtins.ts BUILTIN_CALLS)

private func builtinFn(_ name: String, params: [String], lazy: Bool = false) -> (String, CallDef) {
    (name, CallDef(kind: .function, params: params.map { ParamDef(name: $0, required: false) }, isBuiltin: true, isLazy: lazy))
}

private func builtinAction(_ name: String, params: [String], lazy: Bool = false) -> (String, CallDef) {
    (name, CallDef(kind: .action, params: params.map { ParamDef(name: $0, required: false) }, isBuiltin: true, isLazy: lazy))
}

/// The 14 built-in functions + 5 built-in actions + Action. Single source of truth.
public let builtinCallDefs: [String: CallDef] = {
    var defs: [String: CallDef] = [:]
    let fns: [(String, CallDef)] = [
        builtinFn("Count", params: ["array"]),
        builtinFn("First", params: ["array"]),
        builtinFn("Last", params: ["array"]),
        builtinFn("Sum", params: ["numbers"]),
        builtinFn("Avg", params: ["numbers"]),
        builtinFn("Min", params: ["numbers"]),
        builtinFn("Max", params: ["numbers"]),
        builtinFn("Sort", params: ["array", "field", "direction"]),
        builtinFn("Filter", params: ["array", "field", "operator", "value"]),
        builtinFn("Round", params: ["number", "decimals"]),
        builtinFn("Abs", params: ["number"]),
        builtinFn("Floor", params: ["number"]),
        builtinFn("Ceil", params: ["number"]),
        builtinFn("Each", params: ["array", "varName", "template"], lazy: true),
    ]
    let actions: [(String, CallDef)] = [
        builtinAction("Run", params: ["ref"], lazy: true),
        builtinAction("ToAssistant", params: ["message", "context"]),
        builtinAction("OpenUrl", params: ["url"]),
        builtinAction("Set", params: ["variable", "value"], lazy: true),
        builtinAction("Reset", params: ["variable"], lazy: true),
        builtinAction("Action", params: ["steps"], lazy: true),
    ]
    for (name, def) in fns + actions { defs[name] = def }
    return defs
}()

public func isBuiltinFunction(_ name: String) -> Bool {
    builtinCallDefs[name]?.kind == .function
}

public func isBuiltinAction(_ name: String) -> Bool {
    builtinCallDefs[name]?.kind == .action
}

/// Reserved statement-level call names — not builtins, not components.
public func isReservedCall(_ name: String) -> Bool {
    name == "Query" || name == "Mutation"
}

// MARK: - State store protocol (implemented in Store.swift)

public protocol StateStore: AnyObject {
    func get(_ name: String) -> Value?
    func set(_ name: String, value: Value, pristine: Bool)
    func initialize(defaults: [(String, Materialized)], persisted: [String: Value])
    func snapshot() -> [String: Value]
}

// MARK: - Evaluation context (implemented in Evaluator.swift)

/// Custom (library) function implementation. May throw; a throw is
/// reported as `runtime-error` and the call evaluates to null.
public struct CustomFunction: Sendable {
    public var params: [ParamDef]
    public var fn: @Sendable ([String: Value]) throws -> Value
    public init(params: [ParamDef], fn: @Sendable @escaping ([String: Value]) throws -> Value) {
        self.params = params
        self.fn = fn
    }
}

public struct EvaluationContext: Sendable {
    public var getState: @Sendable (String) -> Value
    public var resolveRef: @Sendable (String) -> Value
    public var functions: [String: CustomFunction]
    public var actions: [String: CallDef]
    public var reportError: (@Sendable (String) -> Void)?
    public var extraScope: [String: Value]?
    public init(
        getState: @Sendable @escaping (String) -> Value,
        resolveRef: @Sendable @escaping (String) -> Value,
        functions: [String: CustomFunction] = [:],
        actions: [String: CallDef] = [:],
        reportError: (@Sendable (String) -> Void)? = nil,
        extraScope: [String: Value]? = nil
    ) {
        self.getState = getState
        self.resolveRef = resolveRef
        self.functions = functions
        self.actions = actions
        self.reportError = reportError
        self.extraScope = extraScope
    }
}

// MARK: - Public API contracts
//
// Implemented in API.swift / StreamingParser.swift. Declared here so the
// fixture harness and other modules can rely on exact signatures.

public protocol OUIParserProtocol: AnyObject {
    func parse(_ input: String) -> ParseResult
}

public protocol OUIStreamingParserProtocol: AnyObject {
    @discardableResult func push(_ chunk: String, complete: Bool) -> ParseResult
    @discardableResult func set(_ fullText: String, complete: Bool) -> ParseResult
    func getResult(complete: Bool) -> ParseResult
}

public extension OUIStreamingParserProtocol {
    @discardableResult func push(_ chunk: String) -> ParseResult {
        push(chunk, complete: false)
    }
    @discardableResult func set(_ fullText: String) -> ParseResult {
        set(fullText, complete: false)
    }
    func getResult() -> ParseResult {
        getResult(complete: false)
    }
}
