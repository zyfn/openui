// OpenUILang — Materialize.
//
// Ports packages/lang-core/src/parser/materialize.ts:
// schema-aware lowering of AST → Materialized values (ElementNode tree),
// reference resolution, call arg mapping, and inline validation.

import Foundation

// MARK: - Context

/// Materialization context. Reference type: shared and mutated during lowering.
/// Mirrors parser/types.ts MaterializeCtx.
public final class MaterializeContext {
    /// Statement id → AST (value statements: expr; state: init).
    public var syms: [String: ASTNode] = [:]
    /// Component name → positional params. Nil = no catalog (all components unknown).
    public var catalog: [String: [ParamDef]]?
    /// Function/action call defs (built-ins + custom).
    public var callDefs: [String: CallDef] = builtinCallDefs
    public var errors: [OpenUIError] = []
    /// Names referenced but not defined.
    public var unresolved: [String] = []
    public var visited: Set<String> = []
    /// True while streaming (defers some checks).
    public var partial: Bool = false
    public var currentStatementId: String? = nil
    /// Statement ids not yet reached; remainder = orphaned.
    public var unreached: Set<String>? = nil

    public init() {}

    /// All component names known to the catalog.
    public var componentNames: Set<String> {
        guard let catalog = catalog else { return [] }
        return Set(catalog.keys)
    }
}

// MARK: - Dynamic check

/// True when a materialized value contains runtime AST nodes.
public func containsDynamicValue(_ v: Materialized) -> Bool {
    switch v {
    case .expr: return true
    case .array(let items): return items.contains(where: containsDynamicValue)
    case .object(let entries): return entries.contains(where: { containsDynamicValue($0.1) })
    case .element(let el): return el.props.contains(where: { containsDynamicValue($0.value) })
    case .value, .null: return false
    }
}

// MARK: - Reference resolution

enum RefMode {
    case value
    case expr
}

/// Resolve a Ref node: inline from the symbol table, detect cycles,
/// emit RuntimeRef for Query/Mutation declarations.
func resolveRef(_ name: String, ctx: MaterializeContext, mode: RefMode) -> Materialized {
    if ctx.visited.contains(name) {
        ctx.unresolved.append(name)
        return mode == .expr ? .expr(.ph(name)) : .null
    }
    guard let target = ctx.syms[name] else {
        ctx.unresolved.append(name)
        return mode == .expr ? .expr(.ph(name)) : .null
    }
    ctx.unreached?.remove(name)
    // Query/Mutation declarations → RuntimeRef (resolved at runtime by evaluator).
    if case .comp(let targetName, _, _, _) = target, isReservedCall(targetName) {
        let refType: QueryRefType = targetName == "Mutation" ? .mutation : .query
        return .expr(.runtimeRef(name, refType: refType))
    }
    ctx.visited.insert(name)
    let prevStatementId = ctx.currentStatementId
    ctx.currentStatementId = name
    let result: Materialized
    switch mode {
    case .value: result = materializeValue(target, ctx)
    case .expr: result = .expr(materializeExpr(target, ctx))
    }
    ctx.currentStatementId = prevStatementId
    ctx.visited.remove(name)
    // Tag ElementNode with its source statement name.
    if mode == .value, case .element(var el) = result {
        el.statementId = name
        return .element(el)
    }
    return result
}

/// Registry calls (functions and steps) and reserved calls stay AST for the runtime.
func isRuntimeCall(_ name: String, ctx: MaterializeContext) -> Bool {
    ctx.callDefs[name] != nil || isReservedCall(name)
}

// MARK: - Argument mapping

/// [Num 1, Ref x] with params [a, b] -> [(a, Num 1), (b, Ref x)]; extra args dropped.
public func nameArgs(_ args: [ASTNode], _ params: [ParamDef]) -> [(String, ASTNode)] {
    var named: [(String, ASTNode)] = []
    for i in 0..<min(params.count, args.count) {
        named.append((params[i].name, args[i]))
    }
    return named
}

/// Map + validate call args for library functions/actions.
/// Returns nil when the call is invalid (becomes null / no-op).
/// Mirrors mapCallArgs.
func mapCallArgs(
    _ name: String,
    _ args: [ASTNode],
    _ def: CallDef,
    _ ctx: MaterializeContext
) -> [(String, ASTNode)]? {
    let params = def.params
    if args.count > params.count {
        pushValidationIssue(ctx, component: name, path: "",
                            issue: .excessArgs(declared: params.count, got: args.count))
    }
    var mapped = nameArgs(args, params)
    var invalid = false
    let errorsBefore = ctx.errors.count
    for p in params {
        guard let idx = mapped.firstIndex(where: { $0.0 == p.name }) else {
            // Missing arg.
            if p.required && !p.hasDefault {
                pushValidationIssue(ctx, component: name, path: "/\(p.name)",
                                    issue: .missingRequired(signature: buildParamsSignature(name, params)))
                invalid = true
            }
            continue
        }
        let arg = mapped[idx].1
        guard let lit = literalValue(arg) else { continue } // dynamic: checked at runtime
        if isNullValue(lit) {
            if !p.required || p.hasDefault { continue }
            pushValidationIssue(ctx, component: name, path: "/\(p.name)",
                                issue: .nullRequired(signature: buildParamsSignature(name, params)))
            invalid = true
            continue
        }
        let outcome = validateMaterialized(.value(lit), schema: p.schema, component: name,
                                           path: "/\(p.name)", ctx: ctx)
        switch outcome {
        case .kept(let m):
            if case .value(let v) = m, v != lit {
                mapped[idx] = (p.name, toLiteralAST(v))
            }
        case .invalid:
            let resolved = resolveInvalidValue(required: p.required, hasDefault: p.hasDefault,
                                              defaultValue: p.defaultValue)
            switch resolved {
            case .useDefault(let v):
                mapped[idx] = (p.name, toLiteralAST(v))
            case .dropProp:
                mapped.remove(at: idx)
            case .invalid:
                invalid = true
            }
        }
    }
    // An action never runs with a value the model did not write.
    if def.kind == .action && ctx.errors.count > errorsBefore { invalid = true }
    return invalid ? nil : mapped
}

func isNullValue(_ v: Value) -> Bool {
    if case .null = v { return true }
    return false
}

// @Percent("x", 4) -> type-mismatch at parse time, call becomes null.
func materializeCall(
    _ name: String,
    _ args: [ASTNode],
    _ ctx: MaterializeContext,
    materializeArg: (ASTNode) -> ASTNode
) -> ASTNode {
    let marg = args.map(materializeArg)
    guard let def = ctx.callDefs[name] else {
        return .comp(name: name, args: marg, mappedProps: nil, fn: true)
    }
    if def.isLazy {
        return .comp(name: name, args: marg, mappedProps: nil, fn: false)
    }
    // Built-ins coerce their args, so only library calls are checked.
    let mappedProps: [(String, ASTNode)]?
    if def.isBuiltin {
        mappedProps = nameArgs(marg, def.params)
    } else {
        mappedProps = mapCallArgs(name, marg, def, ctx)
    }
    if let mapped = mappedProps {
        return .comp(name: name, args: marg, mappedProps: mapped, fn: false)
    }
    // An invalid action step is an empty plan, a no-op.
    if def.kind == .action {
        return .comp(name: "Action", args: [.arr([])], mappedProps: nil, fn: false)
    }
    return .null
}

/// Query("s", {n: @Count(rows)}): name nested call args in place.
/// Returns the (possibly annotated) args.
func nameRawCallArgs(_ args: [ASTNode], _ ctx: MaterializeContext, _ statementId: String) -> [ASTNode] {
    let prev = ctx.currentStatementId
    ctx.currentStatementId = statementId
    var seen = Set<ObjectIdentifier>()
    func annotate(_ node: ASTNode) -> ASTNode {
        switch node {
        case .comp(let name, let cargs, let mapped, let fn):
            // Walk children first (walkAST visits nested calls through args and mappedProps).
            let newArgs = cargs.map(annotate)
            let newMapped = mapped?.map { (k, v) in (k, annotate(v)) }
            var result = ASTNode.comp(name: name, args: newArgs, mappedProps: newMapped, fn: fn)
            if let def = ctx.callDefs[name], !def.isLazy, !def.isBuiltin {
                if let checked = mapCallArgs(name, newArgs, def, ctx) {
                    result = .comp(name: name, args: newArgs, mappedProps: checked, fn: fn)
                } else {
                    result = .comp(name: name, args: newArgs, mappedProps: nameArgs(newArgs, def.params), fn: fn)
                }
            }
            return result
        case .arr(let els):
            return .arr(els.map(annotate))
        case .obj(let entries):
            return .obj(entries.map { ($0.0, annotate($0.1)) })
        case .binOp(let op, let l, let r):
            return .binOp(op, annotate(l), annotate(r))
        case .unaryOp(let op, let o):
            return .unaryOp(op, annotate(o))
        case .ternary(let c, let t, let e):
            return .ternary(annotate(c), annotate(t), annotate(e))
        case .member(let o, let f):
            return .member(annotate(o), f)
        case .index(let o, let i):
            return .index(annotate(o), annotate(i))
        case .assign(let t, let v):
            return .assign(t, annotate(v))
        default:
            return node
        }
    }
    _ = seen
    let out = args.map(annotate)
    ctx.currentStatementId = prev
    return out
}

/// Lazy builtins (@Each, Action, @Run, @Set, @Reset) keep raw args.
/// For @Each, scope the iterator variable during materialization.
func materializeLazyBuiltin(
    _ name: String,
    _ args: [ASTNode],
    _ ctx: MaterializeContext,
    _ scopedRefs: Set<String>
) -> ASTNode? {
    guard let def = ctx.callDefs[name], def.isLazy else { return nil }
    // @Each(array, varName, template): scope varName in the template.
    if name == "Each", args.count >= 3 {
        let varArg = args[1]
        let varName: String?
        switch varArg {
        case .ref(let n): varName = n
        case .str(let s): varName = s
        default: varName = nil
        }
        guard let vn = varName else { return nil }
        var nextScoped = scopedRefs
        nextScoped.insert(vn)
        let recursed = args.enumerated().map { i, a in
            i == 1 ? a : materializeExprInternal(a, ctx, nextScoped)
        }
        return .comp(name: name, args: recursed, mappedProps: nil, fn: false)
    }
    return nil
}

// MARK: - Expression materialization

func materializeExprInternal(
    _ node: ASTNode,
    _ ctx: MaterializeContext,
    _ scopedRefs: Set<String>
) -> ASTNode {
    switch node {
    case .ref(let n):
        if scopedRefs.contains(n) { return node }
        if case .expr(let e) = resolveRef(n, ctx: ctx, mode: .expr) { return e }
        return .ph(n)

    case .ph:
        return node

    case .comp(let name, let args, _, let fn):
        if fn && !isRuntimeCall(name, ctx: ctx) {
            pushValidationIssue(ctx, component: name, path: "", issue: .unknownFunction)
            return .null
        }
        if let lazy = materializeLazyBuiltin(name, args, ctx, scopedRefs) { return lazy }
        if isRuntimeCall(name, ctx: ctx) {
            return materializeCall(name, args, ctx) { materializeExprInternal($0, ctx, scopedRefs) }
        }
        let recursed = args.map { materializeExprInternal($0, ctx, scopedRefs) }
        if let params = ctx.catalog?[name] {
            let mapped = nameArgs(recursed, params)
            return .comp(name: name, args: recursed, mappedProps: mapped, fn: false)
        }
        // Unknown component in expression: error, but stays in the tree.
        let available = ctx.catalog.map { Array($0.keys) }
        pushValidationIssue(ctx, component: name, path: "",
                            issue: .unknownComponent(available: available))
        return .comp(name: name, args: recursed, mappedProps: nil, fn: false)

    case .arr(let els):
        return .arr(els.map { materializeExprInternal($0, ctx, scopedRefs) })
    case .obj(let entries):
        return .obj(entries.map { ($0.0, materializeExprInternal($0.1, ctx, scopedRefs)) })
    case .binOp(let op, let l, let r):
        return .binOp(op, materializeExprInternal(l, ctx, scopedRefs),
                      materializeExprInternal(r, ctx, scopedRefs))
    case .unaryOp(let op, let o):
        return .unaryOp(op, materializeExprInternal(o, ctx, scopedRefs))
    case .ternary(let c, let t, let e):
        return .ternary(materializeExprInternal(c, ctx, scopedRefs),
                        materializeExprInternal(t, ctx, scopedRefs),
                        materializeExprInternal(e, ctx, scopedRefs))
    case .member(let o, let f):
        return .member(materializeExprInternal(o, ctx, scopedRefs), f)
    case .index(let o, let i):
        return .index(materializeExprInternal(o, ctx, scopedRefs),
                      materializeExprInternal(i, ctx, scopedRefs))
    case .assign(let t, let v):
        return .assign(t, materializeExprInternal(v, ctx, scopedRefs))
    default:
        // Literals, StateRef, RuntimeRef pass through unchanged.
        return node
    }
}

/// Normalize an AST node for use inside runtime expressions.
public func materializeExpr(_ node: ASTNode, _ ctx: MaterializeContext) -> ASTNode {
    materializeExprInternal(node, ctx, Set())
}

// MARK: - Value materialization

/// Schema-aware materialization: the single recursive traversal.
/// Returns ElementNode for components, ASTNode (.expr) for runtime calls,
/// plain values for literals, .null for placeholders/dropped nodes.
public func materializeValue(_ node: ASTNode, _ ctx: MaterializeContext) -> Materialized {
    switch node {
    case .ref(let n):
        return resolveRef(n, ctx: ctx, mode: .value)

    case .str(let s): return .value(.string(s))
    case .num(let n): return .value(.number(n))
    case .bool(let b): return .value(.boolean(b))
    case .null: return .null
    case .ph: return .null

    case .arr(let els):
        var items: [Materialized] = []
        for e in els {
            if case .ph = e { continue } // drop unresolved placeholders
            let v = materializeValue(e, ctx)
            // Drop nulls from component/ref resolution; keep explicit nulls.
            if case .null = v, isCompOrRef(e) { continue }
            items.append(v)
        }
        return .array(items)

    case .obj(let entries):
        return .object(entries.map { ($0.0, materializeValue($0.1, ctx)) })

    case .comp(let name, let args, _, let fn):
        if fn && !isRuntimeCall(name, ctx: ctx) {
            pushValidationIssue(ctx, component: name, path: "", issue: .unknownFunction)
            return .null
        }
        // Inline Query/Mutation (not a statement-level declaration).
        if isReservedCall(name) {
            pushValidationIssue(ctx, component: name, path: "", issue: .inlineReserved)
            return .null
        }
        // Built-ins, library functions and action steps → AST for runtime.
        if isRuntimeCall(name, ctx: ctx) {
            if let lazy = materializeLazyBuiltin(name, args, ctx, Set()) {
                return .expr(lazy)
            }
            return .expr(materializeCall(name, args, ctx) { materializeExpr($0, ctx) })
        }

        guard let params = ctx.catalog?[name] else {
            let available = ctx.catalog.map { Array($0.keys) }
            pushValidationIssue(ctx, component: name, path: "",
                                issue: .unknownComponent(available: available))
            return .null
        }

        var props: [PropEntry] = []
        var dropComponent = false
        for i in 0..<min(params.count, args.count) {
            let param = params[i]
            let value = materializeValue(args[i], ctx)
            var stored = value
            if let schema = param.schema {
                let outcome = validateMaterialized(value, schema: schema, component: name,
                                                   path: "/\(param.name)", ctx: ctx)
                switch outcome {
                case .kept(let m):
                    stored = m
                case .invalid:
                    switch resolveInvalidValue(required: param.required,
                                               hasDefault: param.hasDefault,
                                               defaultValue: param.defaultValue) {
                    case .useDefault(let v): stored = .value(v)
                    case .dropProp: continue
                    case .invalid: dropComponent = true; continue
                    }
                }
            }
            props.append(PropEntry(key: param.name, value: stored))
        }

        if args.count > params.count {
            pushValidationIssue(ctx, component: name, path: "",
                                issue: .excessArgs(declared: params.count, got: args.count))
        }

        // Required props: fill from default, else report and drop.
        let missing = params.filter { p in
            p.required && !props.contains(where: { $0.key == p.name && !isNullMaterialized($0.value) })
        }
        if !missing.isEmpty {
            let stillInvalid = missing.filter { p in
                if p.hasDefault {
                    if let idx = props.firstIndex(where: { $0.key == p.name }) {
                        props[idx] = PropEntry(key: p.name, value: .value(p.defaultValue))
                    } else {
                        props.append(PropEntry(key: p.name, value: .value(p.defaultValue)))
                    }
                    return false
                }
                return true
            }
            if !stillInvalid.isEmpty {
                for p in stillInvalid {
                    let hasKey = props.contains(where: { $0.key == p.name })
                    pushValidationIssue(
                        ctx, component: name, path: "/\(p.name)",
                        issue: hasKey
                            ? .nullRequired(signature: buildParamsSignature(name, params))
                            : .missingRequired(signature: buildParamsSignature(name, params)))
                }
                return .null
            }
        }

        if dropComponent { return .null }

        return .element(ElementNode(typeName: name, props: props, partial: ctx.partial))

    default:
        // Runtime expression nodes → preserve as AST.
        if isRuntimeExpr(node) {
            return .expr(materializeExpr(node, ctx))
        }
        return .expr(node)
    }
}

func isCompOrRef(_ node: ASTNode) -> Bool {
    switch node {
    case .comp, .ref: return true
    default: return false
    }
}

func isNullMaterialized(_ m: Materialized) -> Bool {
    if case .null = m { return true }
    if case .value(let v) = m, case .null = v { return true }
    return false
}
