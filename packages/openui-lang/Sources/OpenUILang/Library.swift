// OpenUILang — Library schema compilation and the Swift authoring DSL.
//
// Ports compileSchema (parser_parser.ts), the defineComponent /
// defineFunction / defineAction / createLibrary authoring surface
// (library.ts, functions.ts), library.extend (extend.ts, simplified for the
// schema-only DSL), and the LibrarySpec document (prompt.md §2).

import Foundation

// MARK: - compileLibrarySchema (port of compileSchema in parser_parser.ts)

/// Names of the action `$defs` every library carries (ActionExpression,
/// OpenUrl, ToAssistant — parser_builtins.ts ACTION_DEFS). They are data
/// shapes, never components.
private let builtinActionDefNames: Set<String> = ["ActionExpression", "OpenUrl", "ToAssistant"]

/// `{$ref: "#/$defs/ActionExpression"}` -> its body, so action slots validate
/// as inline unions. Mirrors inlineActionRefs in parser_parser.ts.
/// The shared schema's id is kept as `x-openui-ref` so signatures print the
/// name (prompt.md §5.1: `action?: ActionExpression`) instead of the inlined
/// union; validators ignore the annotation.
private let inlinedRefAnnotation = "x-openui-ref"

private func inlineActionRefs(_ node: JSONValue, defs: [String: JSONValue]) -> JSONValue {
    switch node {
    case .object(let fields):
        if let refField = fields.first(where: { $0.key == "$ref" }),
           case .string(let ref) = refField.value, let body = defs[ref] {
            let inlined = inlineActionRefs(body, defs: defs)
            if case .object(let bfields) = inlined {
                let name = ref.split(separator: "/").last.map(String.init) ?? ref
                return .object(bfields + [JSONField(key: inlinedRefAnnotation, value: .string(name))])
            }
            return inlined
        }
        var changed = false
        let mapped = fields.map { f -> JSONField in
            let v = inlineActionRefs(f.value, defs: defs)
            if !jsonValuesEqual(v, f.value) { changed = true }
            return JSONField(key: f.key, value: v)
        }
        return changed ? .object(mapped) : node
    case .array(let items):
        var changed = false
        let mapped = items.map { i -> JSONValue in
            let v = inlineActionRefs(i, defs: defs)
            if !jsonValuesEqual(v, i) { changed = true }
            return v
        }
        return changed ? .array(mapped) : node
    default:
        return node
    }
}


/// Compile one parameter object (`properties` + `required`) into ParamDefs,
/// preserving key order. Mirrors compileParams in parser_parser.ts.
private func compileParams(_ def: JSONValue, actionDefs: [String: JSONValue]) -> [ParamDef] {
    let properties = def.field("properties")?.objectFields ?? []
    let required = Set(def.field("required")?.arrayItems?.compactMap { $0.stringValue } ?? [])
    return properties.map { (key, prop) in
        let defaultJSON = prop.field("default")
        return ParamDef(
            name: key,
            required: required.contains(key),
            hasDefault: defaultJSON != nil,
            defaultValue: defaultJSON.map(jsonToValue) ?? .null,
            isBindable: false,
            schema: actionDefs.isEmpty ? prop : inlineActionRefs(prop, defs: actionDefs)
        )
    }
}

/// Compile a library JSON Schema document into the parser's LibrarySchema.
/// Faithful port of compileSchema in parser_parser.ts:
///
/// - Components are the `$defs` entries named by `properties` keys (ordered).
///   Non-component `$defs` (action defs like ActionExpression/OpenUrl/
///   ToAssistant/custom actions, or zod-hoisted helpers when `properties` is
///   absent) are skipped.
/// - `{$ref: "#/$defs/<action>"}` inside prop schemas is inlined to the
///   action's body.
/// - callDefs = builtinCallDefs + `functions` (kind .function) + `actions`
///   (kind .action), each with params in key order.
public func compileLibrarySchema(_ json: JSONValue) -> LibrarySchema {
    let propertyNames = json.field("properties")?.objectFields?.map { $0.0 } ?? []
    let componentNames = Set(propertyNames)
    let defEntries = json.field("$defs")?.objectFields ?? []
    let functionEntries = json.field("functions")?.objectFields ?? []
    let actionEntries = json.field("actions")?.objectFields ?? []

    // Action $defs (built-in ActionExpression/OpenUrl/ToAssistant plus custom
    // actions) are data shapes, never components.
    var actionDefs: [String: JSONValue] = [:]
    for name in builtinActionDefNames.union(actionEntries.map { $0.0 }) {
        if let body = defEntries.first(where: { $0.0 == name })?.1,
           !componentNames.contains(name) {
            actionDefs["#/$defs/\(name)"] = body
        }
    }

    var components: [String: [ParamDef]] = [:]
    for entry in defEntries {
        if !propertyNames.isEmpty {
            // properties present: only $defs named by a property key are components
            guard componentNames.contains(entry.0) else { continue }
        } else {
            // no properties: skip action defs (e.g. zod-hoisted shapes)
            if actionDefs["#/$defs/\(entry.0)"] != nil { continue }
        }
        components[entry.0] = compileParams(entry.1, actionDefs: actionDefs)
    }

    var callDefs = builtinCallDefs
    for entry in functionEntries {
        if let params = entry.1.field("params") {
            callDefs[entry.0] = CallDef(kind: .function, params: compileParams(params, actionDefs: actionDefs))
        }
    }
    for entry in actionEntries {
        if let params = entry.1.field("params") {
            callDefs[entry.0] = CallDef(kind: .action, params: compileParams(params, actionDefs: actionDefs))
        }
    }

    return LibrarySchema(
        components: components,
        callDefs: callDefs,
        rootComponent: json.field("root")?.stringValue
    )
}

// MARK: - Validation (prompt.md §3.1)

/// Library definition-time rule violations. `createLibrary` and `extend`
/// throw these; they are recoverable errors (not preconditions) so a host
/// can report them like any other definition failure.
public enum LibraryValidationError: Error, CustomStringConvertible, Sendable {
    case invalidComponentName(String)
    case invalidCallName(kind: String, name: String)
    case reservedName(kind: String, name: String)
    case nameCollision(kind: String, name: String)
    case requiredAfterOptional(component: String, param: String)
    case unknownRoot(String)
    case unknownComponentForOverride(String)
    case unknownComponentForRemove(String)
    case removeRoot(String)

    public var description: String {
        switch self {
        case .invalidComponentName(let n):
            return "[createLibrary] Component \"\(n)\" must start with an uppercase letter and match the identifier rule."
        case .invalidCallName(let kind, let n):
            return "[createLibrary] \(kind) \"\(n)\" must start with an uppercase letter."
        case .reservedName(let kind, let n):
            return "[createLibrary] \(kind) \"\(n)\" is reserved (Query/Mutation/Action/built-ins)."
        case .nameCollision(let kind, let n):
            return "[createLibrary] \(kind) \"\(n)\" collides with a built-in, component, function, or action of the same name. Rename it."
        case .requiredAfterOptional(let c, let p):
            return "[createLibrary] Component \"\(c)\": required param \"\(p)\" comes after an optional param. Required props must come first."
        case .unknownRoot(let n):
            return "[createLibrary] Root component \"\(n)\" was not found in components."
        case .unknownComponentForOverride(let n):
            return "[extend] Cannot override \"\(n)\": not in the library. Use add."
        case .unknownComponentForRemove(let n):
            return "[extend] Cannot remove \"\(n)\": not in the library."
        case .removeRoot(let n):
            return "[extend] Cannot remove \"\(n)\": it is the library root."
        }
    }
}

private func isValidComponentName(_ name: String) -> Bool {
    guard let first = name.unicodeScalars.first,
          CharacterSet.uppercaseLetters.contains(first) else { return false }
    return isBareName(name)
}

private func isReservedLibraryName(_ name: String) -> Bool {
    isReservedCall(name) || name == "Action" || builtinCallDefs[name] != nil
}

/// A required prop that has a `default` counts as optional for ordering
/// (prompt.md §3.1).
private func isEffectivelyOptional(_ param: ParamDef) -> Bool {
    !param.required || param.hasDefault
}

private func validateParamsOrder(componentName: String, params: [ParamDef]) throws {
    var sawOptional = false
    for param in params {
        if isEffectivelyOptional(param) { sawOptional = true }
        else if sawOptional { throw LibraryValidationError.requiredAfterOptional(component: componentName, param: param.name) }
    }
}

// MARK: - Swift authoring DSL

/// A component defined in Swift: name, description, and params whose order is
/// the positional order in programs.
public struct ComponentDefinition: Sendable {
    public var name: String
    public var description: String
    public var params: [ParamDef]
    public init(name: String, description: String, params: [ParamDef]) {
        self.name = name
        self.description = description
        self.params = params
    }
}

/// A custom function: called as `@Name(...)` with positional args in `params`
/// key order. `fn` receives args by name; a throw evaluates to null.
public struct FunctionDefinition: Sendable {
    public var name: String
    public var description: String
    public var params: [ParamDef]
    public var returns: JSONValue?
    public var fn: @Sendable ([String: Value]) throws -> Value
    public init(
        name: String,
        description: String,
        params: [ParamDef],
        returns: JSONValue? = nil,
        fn: @Sendable @escaping ([String: Value]) throws -> Value
    ) {
        self.name = name
        self.description = description
        self.params = params
        self.returns = returns
        self.fn = fn
    }
}

/// A custom action: used as `@Name(...)` steps in action props. The client
/// does not run it; the host receives it in `onAction`.
public struct ActionDefinition: Sendable {
    public var name: String
    public var description: String
    public var params: [ParamDef]
    public init(name: String, description: String, params: [ParamDef]) {
        self.name = name
        self.description = description
        self.params = params
    }
}

public func defineComponent(name: String, description: String, params: [ParamDef]) -> ComponentDefinition {
    ComponentDefinition(name: name, description: description, params: params)
}

public func defineFunction(
    name: String,
    description: String,
    params: [ParamDef],
    fn: @Sendable @escaping ([String: Value]) throws -> Value
) -> FunctionDefinition {
    FunctionDefinition(name: name, description: description, params: params, fn: fn)
}

public func defineAction(name: String, description: String, params: [ParamDef]) -> ActionDefinition {
    ActionDefinition(name: name, description: description, params: params)
}

// MARK: - Library

/// A component library authored in Swift. `createLibrary` validates the
/// prompt.md §3.1 rules and throws `LibraryValidationError` on violation.
public struct Library: Sendable {
    public var components: [ComponentDefinition]
    public var functions: [FunctionDefinition]
    public var actions: [ActionDefinition]
    public var root: String?
    public var id: String?

    public init(
        components: [ComponentDefinition] = [],
        functions: [FunctionDefinition] = [],
        actions: [ActionDefinition] = [],
        root: String? = nil,
        id: String? = nil
    ) {
        self.components = components
        self.functions = functions
        self.actions = actions
        self.root = root
        self.id = id
    }

    /// The compiled schema used by the parser/validator.
    public func toSchema() -> LibrarySchema {
        var components: [String: [ParamDef]] = [:]
        for c in self.components { components[c.name] = c.params }
        var callDefs = builtinCallDefs
        for f in functions {
            callDefs[f.name] = CallDef(kind: .function, params: f.params)
        }
        for a in actions {
            callDefs[a.name] = CallDef(kind: .action, params: a.params)
        }
        return LibrarySchema(components: components, callDefs: callDefs, rootComponent: root)
    }

    /// Custom functions keyed by name, ready for `EvaluationContext`.
    public func customFunctions() -> [String: CustomFunction] {
        var out: [String: CustomFunction] = [:]
        for f in functions { out[f.name] = CustomFunction(params: f.params, fn: f.fn) }
        return out
    }

    /// Derive a new library; the base stays untouched and the derived
    /// library drops the base's public id (prompt.md §2.8).
    public func extend(_ ext: LibraryExtension) throws -> Library {
        var components = self.components
        var byName: [String: Int] = [:]
        for (i, c) in components.enumerated() { byName[c.name] = i }

        for c in ext.addComponents {
            try validateComponentDefinition(c, claimed: Set(byName.keys))
            guard byName[c.name] == nil else {
                throw LibraryValidationError.nameCollision(kind: "Component", name: c.name)
            }
            byName[c.name] = components.count
            components.append(c)
        }
        for c in ext.overrideComponents {
            try validateComponentDefinition(c, claimed: [])
            guard let idx = byName[c.name] else {
                throw LibraryValidationError.unknownComponentForOverride(c.name)
            }
            components[idx] = c
        }
        for name in ext.removeComponents {
            guard let idx = byName[name] else {
                throw LibraryValidationError.unknownComponentForRemove(name)
            }
            if name == root { throw LibraryValidationError.removeRoot(name) }
            components.remove(at: idx)
            byName = [:]
            for (i, c) in components.enumerated() { byName[c.name] = i }
        }

        var functions = self.functions
        var actions = self.actions
        var claimedCalls = Set(byName.keys)
            .union(functions.map { $0.name })
            .union(actions.map { $0.name })
        for f in ext.addFunctions {
            try validateCallDefinition(kind: "Function", name: f.name, params: f.params, claimed: claimedCalls)
            functions.append(f)
            claimedCalls.insert(f.name)
        }
        for a in ext.addActions {
            try validateCallDefinition(kind: "Action", name: a.name, params: a.params, claimed: claimedCalls)
            actions.append(a)
            claimedCalls.insert(a.name)
        }

        return Library(components: components, functions: functions, actions: actions, root: root, id: nil)
    }

    /// The full spec document: signatures, descriptions, and the ordered
    /// JSON schema (prompt.md §2).
    public func toSpec() -> LibrarySpec {
        LibrarySpec(
            id: id,
            version: "1.0",
            root: root,
            schema: libraryJSONSchema(),
            components: components.map {
                LibrarySpecEntry(name: $0.name, signature: buildSignature(name: $0.name, params: $0.params), description: $0.description)
            },
            functions: functions.map {
                LibrarySpecEntry(name: $0.name, signature: buildSignature(name: $0.name, params: $0.params), description: $0.description)
            },
            actions: actions.map {
                LibrarySpecEntry(name: $0.name, signature: buildSignature(name: $0.name, params: $0.params), description: $0.description)
            }
        )
    }

    /// The `schema` part of the spec: `{$defs, properties, functions?,
    /// actions?, root?}` with key order preserved — the shape
    /// `compileLibrarySchema` reads back.
    public func libraryJSONSchema() -> JSONValue {
        var defFields: [JSONField] = []
        var propFields: [JSONField] = []
        for c in components {
            defFields.append(JSONField(key: c.name, value: componentJSONSchema(c)))
            propFields.append(JSONField(key: c.name, value: .object([JSONField(key: "$ref", value: .string("#/$defs/\(c.name)"))])))
        }
        var top: [JSONField] = [
            JSONField(key: "$defs", value: .object(defFields)),
            JSONField(key: "properties", value: .object(propFields)),
        ]
        if !functions.isEmpty {
            top.append(JSONField(key: "functions", value: .object(functions.map {
                JSONField(key: $0.name, value: callJSONSchema(description: $0.description, params: $0.params, returns: $0.returns))
            })))
        }
        if !actions.isEmpty {
            top.append(JSONField(key: "actions", value: .object(actions.map {
                JSONField(key: $0.name, value: callJSONSchema(description: $0.description, params: $0.params, returns: nil))
            })))
        }
        if let root = root {
            top.append(JSONField(key: "root", value: .string(root)))
        }
        return .object(top)
    }
}

private func componentJSONSchema(_ c: ComponentDefinition) -> JSONValue {
    var fields: [JSONField] = [
        JSONField(key: "type", value: .string("object")),
        JSONField(key: "properties", value: .object(c.params.map {
            JSONField(key: $0.name, value: $0.schema ?? .object([]))
        })),
    ]
    let required = c.params.filter { $0.required }.map { $0.name }
    if !required.isEmpty {
        fields.append(JSONField(key: "required", value: .array(required.map { .string($0) })))
    }
    if !c.description.isEmpty {
        fields.append(JSONField(key: "description", value: .string(c.description)))
    }
    return .object(fields)
}

private func callJSONSchema(description: String, params: [ParamDef], returns: JSONValue?) -> JSONValue {
    var fields: [JSONField] = []
    if !description.isEmpty {
        fields.append(JSONField(key: "description", value: .string(description)))
    }
    fields.append(JSONField(key: "params", value: .object([
        JSONField(key: "type", value: .string("object")),
        JSONField(key: "properties", value: .object(params.map {
            JSONField(key: $0.name, value: $0.schema ?? .object([]))
        })),
    ])))
    if let returns = returns {
        fields.append(JSONField(key: "returns", value: returns))
    }
    return .object(fields)
}

private func validateComponentDefinition(_ c: ComponentDefinition, claimed: Set<String>) throws {
    guard isValidComponentName(c.name) else {
        throw LibraryValidationError.invalidComponentName(c.name)
    }
    guard !isReservedLibraryName(c.name) else {
        throw LibraryValidationError.reservedName(kind: "Component", name: c.name)
    }
    if claimed.contains(c.name) {
        throw LibraryValidationError.nameCollision(kind: "Component", name: c.name)
    }
    try validateParamsOrder(componentName: c.name, params: c.params)
}

private func validateCallDefinition(kind: String, name: String, params: [ParamDef], claimed: Set<String>) throws {
    guard isValidComponentName(name) else {
        throw LibraryValidationError.invalidCallName(kind: kind, name: name)
    }
    guard !isReservedLibraryName(name) else {
        throw LibraryValidationError.reservedName(kind: kind, name: name)
    }
    if claimed.contains(name) {
        throw LibraryValidationError.nameCollision(kind: kind, name: name)
    }
    try validateParamsOrder(componentName: name, params: params)
}

public func createLibrary(
    components: [ComponentDefinition] = [],
    functions: [FunctionDefinition] = [],
    actions: [ActionDefinition] = [],
    root: String? = nil,
    id: String? = nil
) throws -> Library {
    var claimed: Set<String> = []
    for c in components {
        try validateComponentDefinition(c, claimed: claimed)
        claimed.insert(c.name)
    }
    for f in functions {
        try validateCallDefinition(kind: "Function", name: f.name, params: f.params, claimed: claimed)
        claimed.insert(f.name)
    }
    for a in actions {
        try validateCallDefinition(kind: "Action", name: a.name, params: a.params, claimed: claimed)
        claimed.insert(a.name)
    }
    if let root = root, !claimed.contains(root) {
        throw LibraryValidationError.unknownRoot(root)
    }
    return Library(components: components, functions: functions, actions: actions, root: root, id: id)
}

/// Verbs for `Library.extend`, mirroring LibraryExtension in library.ts.
/// (The Swift DSL is schema-only, so slot placement into `$ref` unions —
/// extend.ts's zod surgery — has no equivalent and is not modeled.)
public struct LibraryExtension: Sendable {
    public var addComponents: [ComponentDefinition]
    public var overrideComponents: [ComponentDefinition]
    public var removeComponents: [String]
    public var addFunctions: [FunctionDefinition]
    public var addActions: [ActionDefinition]
    public init(
        addComponents: [ComponentDefinition] = [],
        overrideComponents: [ComponentDefinition] = [],
        removeComponents: [String] = [],
        addFunctions: [FunctionDefinition] = [],
        addActions: [ActionDefinition] = []
    ) {
        self.addComponents = addComponents
        self.overrideComponents = overrideComponents
        self.removeComponents = removeComponents
        self.addFunctions = addFunctions
        self.addActions = addActions
    }
}

// MARK: - LibrarySpec (prompt.md §2)

public struct LibrarySpecEntry: Codable, Sendable {
    public var name: String
    public var signature: String
    public var description: String
    public init(name: String, signature: String, description: String) {
        self.name = name
        self.signature = signature
        self.description = description
    }
}

/// The full spec document: id, version, root, the ordered JSON schema, and
/// signatures + descriptions for components, functions, and actions.
public struct LibrarySpec: Codable, Sendable {
    public var id: String?
    public var version: String
    public var root: String?
    public var schema: JSONValue
    public var components: [LibrarySpecEntry]
    public var functions: [LibrarySpecEntry]
    public var actions: [LibrarySpecEntry]
    public init(
        id: String? = nil,
        version: String = "1.0",
        root: String? = nil,
        schema: JSONValue,
        components: [LibrarySpecEntry] = [],
        functions: [LibrarySpecEntry] = [],
        actions: [LibrarySpecEntry] = []
    ) {
        self.id = id
        self.version = version
        self.root = root
        self.schema = schema
        self.components = components
        self.functions = functions
        self.actions = actions
    }
}

// MARK: - Codable for JSONValue (order-preserving)

private struct AnyCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int? { nil }
    init(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { nil }
}

extension JSONValue: Codable {
    public init(from decoder: Decoder) throws {
        let single = try decoder.singleValueContainer()
        if (try? single.decodeNil()) == true { self = .null; return }
        if let b = try? single.decode(Bool.self) { self = .boolean(b); return }
        if let n = try? single.decode(Double.self) { self = .number(n); return }
        if let s = try? single.decode(String.self) { self = .string(s); return }
        if var arr = try? decoder.unkeyedContainer() {
            var items: [JSONValue] = []
            while !arr.isAtEnd { items.append(try arr.decode(JSONValue.self)) }
            self = .array(items)
            return
        }
        let obj = try decoder.container(keyedBy: AnyCodingKey.self)
        self = .object(try obj.allKeys.map { JSONField(key: $0.stringValue, value: try obj.decode(JSONValue.self, forKey: $0)) })
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .string(let s):
            var c = encoder.singleValueContainer(); try c.encode(s)
        case .number(let n):
            var c = encoder.singleValueContainer(); try c.encode(n)
        case .boolean(let b):
            var c = encoder.singleValueContainer(); try c.encode(b)
        case .null:
            var c = encoder.singleValueContainer(); try c.encodeNil()
        case .array(let items):
            var c = encoder.unkeyedContainer()
            for i in items { try c.encode(i) }
        case .object(let fields):
            // Encoded in field order; JSONEncoder preserves it (no .sortedKeys).
            var c = encoder.container(keyedBy: AnyCodingKey.self)
            for f in fields { try c.encode(f.value, forKey: AnyCodingKey(stringValue: f.key)) }
        }
    }
}
