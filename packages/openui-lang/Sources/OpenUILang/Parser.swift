// OpenUILang — Parser.
//
// Ports packages/lang-core/src/parser/expressions.ts (Pratt parser),
// the classification + result building from parser.ts.

import Foundation

// MARK: - Pratt expression parser

/// Parse a token array into an AST node (precedence climbing).
public func parseExpression(_ tokens: [Token]) -> ASTNode {
    var pos = 0

    func cur() -> Token { pos < tokens.count ? tokens[pos] : .eof }
    @discardableResult
    func adv() -> Token { let t = cur(); pos += 1; return t }
    func eat(_ kind: Token) {
        if cur() == kind { pos += 1 }
    }
    func peekIs(_ kind: Token) -> Bool {
        pos + 1 < tokens.count && tokens[pos + 1] == kind
    }

    // Precedence levels (spec §1.5).
    func infixPrec(_ tok: Token) -> Int {
        switch tok {
        case .question: return 1
        case .or: return 2
        case .and: return 3
        case .eqEq, .notEq: return 4
        case .greater, .less, .greaterEq, .lessEq: return 5
        case .plus, .minus: return 6
        case .star, .slash, .percent: return 7
        case .dot, .lBrack: return 9
        default: return 0
        }
    }

    func parseExpr(minPrec: Int = 0) -> ASTNode {
        var left = parsePrefix()
        while infixPrec(cur()) > minPrec {
            left = parseInfix(left)
        }
        return left
    }

    func parsePrefix() -> ASTNode {
        let tok = cur()
        switch tok {
        case .str(let s):
            adv(); return .str(s)
        case .num(let n):
            adv(); return .num(n)
        case .true:
            adv(); return .bool(true)
        case .false:
            adv(); return .bool(false)
        case .null:
            adv(); return .null
        case .lBrack:
            return parseArr()
        case .lBrace:
            return parseObj()
        case .stateVar(let name):
            adv()
            if cur() == .equals {
                adv()
                let value = parseExpr(minPrec: 0)
                return .assign(name, value)
            }
            return .stateRef(name)
        case .type(let name):
            // Builtins (Count, Each, Set, Run, etc.) require @-prefix — only Action is exempt.
            // `Count(x)` parses as the reference Count; the (x) is left unparsed.
            if peekIs(.lParen) && (!isBuiltinFunction(name) && !isBuiltinAction(name) || name == "Action") {
                return parseComp()
            }
            adv()
            return .ref(name)
        case .builtinCall(let name):
            if peekIs(.lParen) {
                let call = parseComp()
                if case .comp(let n, let args, let mapped, _) = call,
                   !isBuiltinFunction(n) && !isBuiltinAction(n) {
                    return .comp(name: n, args: args, mappedProps: mapped, fn: true)
                }
                return call
            }
            adv()
            return .ref(name)
        case .ident(let name):
            adv(); return .ref(name)
        case .not:
            adv(); return .unaryOp("!", parseExpr(minPrec: 8))
        case .minus:
            adv(); return .unaryOp("-", parseExpr(minPrec: 8))
        case .lParen:
            adv()
            let inner = parseExpr(minPrec: 0)
            eat(.rParen)
            return inner
        default:
            // Unknown token — skip and return Null. Parsing never fails.
            adv()
            return .null
        }
    }

    func parseInfix(_ left: ASTNode) -> ASTNode {
        let tok = cur()
        switch tok {
        case .plus: adv(); return .binOp("+", left, parseExpr(minPrec: 6))
        case .minus: adv(); return .binOp("-", left, parseExpr(minPrec: 6))
        case .star: adv(); return .binOp("*", left, parseExpr(minPrec: 7))
        case .slash: adv(); return .binOp("/", left, parseExpr(minPrec: 7))
        case .percent: adv(); return .binOp("%", left, parseExpr(minPrec: 7))
        case .eqEq: adv(); return .binOp("==", left, parseExpr(minPrec: 4))
        case .notEq: adv(); return .binOp("!=", left, parseExpr(minPrec: 4))
        case .greater: adv(); return .binOp(">", left, parseExpr(minPrec: 5))
        case .less: adv(); return .binOp("<", left, parseExpr(minPrec: 5))
        case .greaterEq: adv(); return .binOp(">=", left, parseExpr(minPrec: 5))
        case .lessEq: adv(); return .binOp("<=", left, parseExpr(minPrec: 5))
        case .and: adv(); return .binOp("&&", left, parseExpr(minPrec: 3))
        case .or: adv(); return .binOp("||", left, parseExpr(minPrec: 2))
        case .question:
            adv()
            let then = parseExpr(minPrec: 0)
            eat(.colon)
            let els = parseExpr(minPrec: 0) // right-associative
            return .ternary(left, then, els)
        case .dot:
            adv()
            let fieldTok = cur()
            let field: String
            switch fieldTok {
            case .ident(let s), .type(let s), .str(let s):
                adv(); field = s
            case .num(let n):
                adv(); field = stringFromNumber(n)
            case .stateVar(let s):
                adv(); field = s.hasPrefix("$") ? String(s.dropFirst()) : s
            default:
                adv(); field = "?"
            }
            return .member(left, field)
        case .lBrack:
            adv()
            let index = parseExpr(minPrec: 0)
            eat(.rBrack)
            return .index(left, index)
        default:
            return left
        }
    }

    /// Parse `Name(arg1, arg2, ...)`.
    func parseComp() -> ASTNode {
        let name: String
        switch cur() {
        case .type(let s), .builtinCall(let s), .ident(let s): name = s
        default: name = ""
        }
        adv()
        eat(.lParen)
        var args: [ASTNode] = []
        while cur() != .rParen && cur() != .eof {
            args.append(parseExpr(minPrec: 0))
            if cur() == .comma { adv() }
        }
        eat(.rParen)
        return .comp(name: name, args: args, mappedProps: nil, fn: false)
    }

    func parseArr() -> ASTNode {
        adv() // [
        var els: [ASTNode] = []
        while cur() != .rBrack && cur() != .eof {
            els.append(parseExpr(minPrec: 0))
            if cur() == .comma { adv() }
        }
        eat(.rBrack)
        return .arr(els)
    }

    func parseObj() -> ASTNode {
        adv() // {
        var entries: [(String, ASTNode)] = []
        while cur() != .rBrace && cur() != .eof {
            let kt = cur()
            let key: String
            switch kt {
            case .ident(let s), .str(let s), .type(let s):
                adv(); key = s
            case .num(let n):
                adv(); key = stringFromNumber(n)
            case .stateVar(let s):
                adv(); key = s.hasPrefix("$") ? String(s.dropFirst()) : s
            default:
                adv(); key = "?"
            }
            eat(.colon)
            entries.append((key, parseExpr(minPrec: 0)))
            if cur() == .comma { adv() }
        }
        eat(.rBrace)
        return .obj(entries)
    }

    return parseExpr(minPrec: 0)
}

/// Format a number token as a member-field string (spec: a number after `.` is a field name).
func stringFromNumber(_ n: Double) -> String {
    if n.truncatingRemainder(dividingBy: 1) == 0 && abs(n) < 1e21 {
        return String(Int64(n))
    }
    return String(n)
}

// MARK: - Statement classification

/// Collect all StateRef ($variable) names in a node.
public func collectQueryDeps(_ node: ASTNode) -> [String] {
    var refs = Set<String>()
    walkAST(node) { n in
        if case .stateRef(let name) = n { refs.insert(name) }
    }
    return Array(refs)
}

/// Classify a raw statement + parsed expression. Determined at parse time.
func classifyStatement(_ raw: RawStatement, _ expr: ASTNode) -> Statement {
    // Query(...) → query declaration — checked BEFORE $var.
    if case .comp(let name, let args, _, _) = expr, name == "Query" {
        var queryDeps: [String] = []
        if args.count > 1 { queryDeps = collectQueryDeps(args[1]) }
        return Statement(kind: .query, id: raw.id, expr: expr,
                         deps: queryDeps.isEmpty ? nil : queryDeps)
    }
    if case .comp(let name, _, _, _) = expr, name == "Mutation" {
        return Statement(kind: .mutation, id: raw.id, expr: expr)
    }
    if raw.isStateVar {
        return Statement(kind: .state, id: raw.id, expr: expr)
    }
    return Statement(kind: .value, id: raw.id, expr: expr)
}

// MARK: - Result building

func emptyParseResult(incomplete: Bool = true) -> ParseResult {
    ParseResult(
        root: nil,
        rootExpression: nil,
        meta: ParseMeta(incomplete: incomplete, unresolved: [], orphaned: [],
                        statementCount: 0, errors: []),
        stateDeclarations: [],
        queryStatements: [],
        mutationStatements: []
    )
}

/// A `$name` at the very end of streamed text, which may still be growing.
struct PartialRef {
    var name: String
    var stmts: Set<String> // statement ids
}

/// Extract typed statement info: state defaults, query/mutation infos.
func extractStatements(
    _ stmts: [Statement],
    ctx: MaterializeContext,
    partialRef: PartialRef?
) -> (stateDeclarations: [(String, Materialized)], queries: [QueryStatementInfo], mutations: [MutationStatementInfo]) {
    var stateDeclarations: [(String, Materialized)] = []
    var declared: Set<String> = []
    var queries: [QueryStatementInfo] = []
    var mutations: [MutationStatementInfo] = []

    for stmt in stmts {
        switch stmt.kind {
        case .state:
            let v = materializeValue(stmt.expr, ctx)
            stateDeclarations.append((stmt.id, v))
            declared.insert(stmt.id)
        case .query:
            if case .comp(_, let args, _, _) = stmt.expr {
                let annotated = nameRawCallArgs(args, ctx, stmt.id)
                queries.append(QueryStatementInfo(
                    statementId: stmt.id,
                    toolAST: annotated.count > 0 ? annotated[0] : nil,
                    argsAST: annotated.count > 1 ? annotated[1] : nil,
                    defaultsAST: annotated.count > 2 ? annotated[2] : nil,
                    refreshAST: annotated.count > 3 ? annotated[3] : nil,
                    deps: stmt.deps,
                    complete: true
                ))
            }
        case .mutation:
            if case .comp(_, let args, _, _) = stmt.expr {
                let annotated = nameRawCallArgs(args, ctx, stmt.id)
                mutations.append(MutationStatementInfo(
                    statementId: stmt.id,
                    toolAST: annotated.count > 0 ? annotated[0] : nil,
                    argsAST: annotated.count > 1 ? annotated[1] : nil
                ))
            }
        case .value:
            break
        }
    }

    // Auto-declare: any $var referenced but not declared → null default.
    for stmt in stmts {
        let nodes: [ASTNode]
        switch stmt.kind {
        case .state: nodes = [stmt.expr]
        case .value: nodes = [stmt.expr]
        case .query, .mutation:
            if case .comp(_, let args, _, _) = stmt.expr { nodes = args } else { nodes = [] }
        }
        for node in nodes {
            for dep in collectQueryDeps(node) {
                if dep == partialRef?.name && (partialRef?.stmts.contains(stmt.id) ?? false) { continue }
                if !declared.contains(dep) {
                    declared.insert(dep)
                    stateDeclarations.append((dep, .null))
                }
            }
        }
    }

    return (stateDeclarations, queries, mutations)
}

/// A call to a library component: not an @ function, built-in, Query or Mutation.
func isComponentCallNode(_ node: ASTNode?) -> Bool {
    guard case .comp(let name, _, _, let fn) = node, !fn else { return false }
    return !isBuiltinFunction(name) && !isBuiltinAction(name) && !isReservedCall(name)
}

/// Entry: `root`, else the first value statement calling the library root component.
func pickEntry(_ stmtMap: [(String, Statement)], rootName: String?) -> (id: String, fallback: Bool)? {
    if stmtMap.contains(where: { $0.0 == "root" }) {
        return (id: "root", fallback: false)
    }
    for (id, stmt) in stmtMap {
        if stmt.kind == .value,
           case .comp(let name, _, _, _) = stmt.expr, name == rootName {
            return (id: id, fallback: true)
        }
    }
    return nil
}

/// Follow refs to the entry's value; a dropped component call is not a component.
func resolvesToComponentCall(_ node: ASTNode?, syms: [String: ASTNode]) -> Bool {
    var seen = Set<String>()
    var current = node
    while true {
        guard case .ref(let n) = current, !seen.contains(n) else { break }
        seen.insert(n)
        current = syms[n]
    }
    return isComponentCallNode(current)
}

/// True when a runtime expression can produce a component, e.g. `$t ? A : B`.
func containsComponent(_ node: ASTNode) -> Bool {
    var found = false
    walkAST(node) { n in
        if isComponentCallNode(n) { found = true }
    }
    return found
}

func void(_: Any) {}

// MARK: - Result building

/// Ordered map set: replaces existing key (keeping position) or appends.
func setOrdered(_ pairs: inout [(String, Statement)], key: String, value: Statement) {
    if let idx = pairs.firstIndex(where: { $0.0 == key }) {
        pairs[idx] = (key, value)
    } else {
        pairs.append((key, value))
    }
}

func buildResult(
    stmtMap: [(String, Statement)],
    typedStmts: [Statement],
    wasIncomplete: Bool,
    stmtCount: Int,
    catalog: [String: [ParamDef]]?,
    callDefs: [String: CallDef],
    rootName: String?,
    partialRef: PartialRef? = nil
) -> ParseResult {
    let entry = pickEntry(stmtMap, rootName: rootName)

    var syms: [String: ASTNode] = [:]
    for (id, stmt) in stmtMap {
        syms[id] = stmt.expr
    }
    var unreached = Set<String>()
    for (id, stmt) in stmtMap {
        if id == entry?.id { continue }
        switch stmt.kind {
        case .state, .query, .mutation: continue
        case .value: unreached.insert(id)
        }
    }

    let ctx = MaterializeContext()
    ctx.syms = syms
    ctx.catalog = catalog
    ctx.callDefs = callDefs
    ctx.partial = wasIncomplete
    ctx.currentStatementId = entry?.id
    ctx.unreached = unreached

    var root: ElementNode? = nil
    var rootExpression: ASTNode? = nil
    if let entry = entry, let expr = syms[entry.id] {
        let materialized = materializeValue(expr, ctx)
        switch materialized {
        case .element(var el):
            el.statementId = entry.id
            root = el
        case .expr(let node):
            if containsComponent(node) { rootExpression = node }
        default:
            break
        }
    }

    let (stateDeclarations, queries, mutations) = extractStatements(typedStmts, ctx: ctx, partialRef: partialRef)

    // Stream-end checks: no-root and enum validation wait for the stream to end.
    ctx.currentStatementId = entry?.id
    let component = rootName ?? ""
    if entry == nil {
        pushValidationIssue(ctx, component: component, path: "", issue: .noRoot(reason: .missing))
    } else if root == nil && rootExpression == nil
                && !resolvesToComponentCall(syms[entry!.id], syms: syms) {
        pushValidationIssue(ctx, component: component, path: "", issue: .noRoot(reason: .notComponent))
    } else if let entry = entry, entry.fallback {
        pushValidationIssue(ctx, component: component, path: "",
                            issue: .noRoot(reason: root != nil ? .fallback : .missing))
    }

    // With no entry nothing is reachable; no-root alone describes the problem.
    let orphaned = entry != nil ? Array(ctx.unreached ?? []) : []

    return ParseResult(
        root: root,
        rootExpression: rootExpression,
        meta: ParseMeta(
            incomplete: wasIncomplete,
            unresolved: ctx.unresolved,
            orphaned: orphaned,
            statementCount: stmtCount,
            errors: ctx.errors
        ),
        stateDeclarations: stateDeclarations,
        queryStatements: queries,
        mutationStatements: mutations
    )
}

/// Parse a complete program in one pass. Mirrors parser.ts parse().
func parseProgram(
    _ input: String,
    catalog: [String: [ParamDef]]?,
    callDefs: [String: CallDef],
    rootName: String?
) -> ParseResult {
    let cleaned = preprocess(stripMessageMarkers(input))
    if cleaned.isEmpty { return emptyParseResult() }
    let (text, wasIncomplete) = autoClose(cleaned)
    let rawStmts = splitStatements(tokenize(text))
    if rawStmts.isEmpty { return emptyParseResult(incomplete: wasIncomplete) }

    var stmtMap: [(String, Statement)] = []
    for s in rawStmts {
        let expr = parseExpression(s.tokens)
        let stmt = classifyStatement(s, expr)
        setOrdered(&stmtMap, key: s.id, value: stmt)
    }
    let typedStmts = stmtMap.map { $0.1 }
    return buildResult(stmtMap: stmtMap, typedStmts: typedStmts,
                       wasIncomplete: wasIncomplete, stmtCount: stmtMap.count,
                       catalog: catalog, callDefs: callDefs, rootName: rootName)
}

/// Minimal ]]>openui: marker handling: last content section wins (spec §7.3).
/// Full message protocol lives in Message.swift.
func stripMessageMarkers(_ text: String) -> String {
    guard text.contains("]]>openui:") else { return text }
    let lines = text.components(separatedBy: "\n")
    var sections: [(kind: String, body: [String])] = []
    var currentKind: String? = nil
    var currentBody: [String] = []
    for line in lines {
        if line.hasPrefix("]]>openui:") {
            if let k = currentKind { sections.append((k, currentBody)) }
            let rest = String(line.dropFirst("]]>openui:".count))
            let kind = rest.split(separator: "?", maxSplits: 1).first.map(String.init) ?? ""
            currentKind = kind
            currentBody = []
        } else {
            currentBody.append(line)
        }
    }
    if let k = currentKind { sections.append((k, currentBody)) }
    // Last content section wins; text before the first marker is content
    // only when there is no content marker.
    if let last = sections.last(where: { $0.kind == "content" }) {
        return last.body.joined(separator: "\n")
    }
    if sections.isEmpty { return text }
    return ""
}
