// OpenUILang — Validation.
//
// Ports packages/lang-core/src/parser/validation.ts:
// JSON-Schema-subset checking with the 14 error codes and drop-and-render
// recovery (spec §8).

import Foundation

// MARK: - Validation issues

/// A structured validation issue. Mirrors validation.ts ValidationIssue.
public enum ValidationIssue {
    case typeMismatch(expected: String, actual: String)
    case missingRequired(signature: String?)
    case nullRequired(signature: String?)
    case unknownComponent(available: [String]?)
    case inlineReserved
    case excessArgs(declared: Int, got: Int)
    case unknownFunction
    case noRoot(reason: NoRootReason)
}

public enum NoRootReason {
    case missing
    case notComponent
    case fallback
}

func validationMessage(component: String, path: String, issue: ValidationIssue) -> String {
    switch issue {
    case .typeMismatch(let expected, let actual):
        return "field \"\(path)\" expects \(expected) but got \(actual)"
    case .missingRequired(let sig):
        return "missing required field \"\(path)\"" + (sig.map { " — signature: \($0)" } ?? "")
    case .nullRequired(let sig):
        return "required field \"\(path)\" cannot be null" + (sig.map { " — signature: \($0)" } ?? "")
    case .unknownComponent(let available):
        var m = "Unknown component \"\(component)\" — not found in catalog or builtins"
        if let a = available, !a.isEmpty { m += ". Available components: \(a.joined(separator: ", "))" }
        return m
    case .inlineReserved:
        return "\(component)() must be declared as a top-level statement, not used inline as a value"
    case .excessArgs(let declared, let got):
        return "\(component) takes \(declared) arg(s), got \(got) (\(got - declared) excess dropped)"
    case .unknownFunction:
        return "Unknown function \"@\(component)\": not a built-in or action step. The call evaluates to null"
    case .noRoot(let reason):
        switch reason {
        case .notComponent: return "root does not evaluate to a component"
        case .fallback: return "No root statement. Rendering the first statement that calls the root component \(component)"
        case .missing:
            return component.isEmpty ? "No root statement" : "No root statement, and no statement calls the root component \(component)"
        }
    }
}

/// Append a validation error, deriving message from the structured issue.
public func pushValidationIssue(
    _ ctx: MaterializeContext,
    component: String,
    path: String,
    issue: ValidationIssue
) {
    let code: OpenUIErrorCode
    var severity: String? = nil
    switch issue {
    case .typeMismatch: code = .typeMismatch
    case .missingRequired: code = .missingRequired
    case .nullRequired: code = .nullRequired
    case .unknownComponent: code = .unknownComponent
    case .inlineReserved: code = .inlineReserved
    case .excessArgs: code = .excessArgs
    case .unknownFunction: code = .unknownFunction
    case .noRoot(let reason):
        code = .noRoot
        if reason == .fallback { severity = "warning" }
    }
    ctx.errors.append(OpenUIError(
        source: .parser,
        code: code,
        message: validationMessage(component: component, path: path, issue: issue),
        statementId: ctx.currentStatementId,
        component: component,
        path: path,
        severity: severity
    ))
}

// MARK: - Schema introspection

/// `{ $ref: "#/$defs/Name" }` → `"Name"`.
func refName(_ s: JSONValue) -> String? {
    guard let r = s.field("$ref")?.stringValue else { return nil }
    return r.split(separator: "/").last.map(String.init)
}

/// Composite shapes can't be reliably matched to a single plain value.
func isCompositeSchema(_ s: JSONValue) -> Bool {
    guard case .object(let fields) = s else { return false }
    let keys = Set(fields.map { $0.key })
    return keys.contains("$ref") || keys.contains("anyOf") || keys.contains("oneOf") || keys.contains("allOf")
}

struct ScalarTypeInfo {
    var expectedType: String? // "string" | "number" | "boolean"
    var enumValues: [JSONValue]?
}

/// Extract scalar leaf type/enum from a JSON Schema fragment.
func getScalarTypeInfo(_ s: JSONValue) -> ScalarTypeInfo {
    if let e = s.field("enum")?.arrayItems { return ScalarTypeInfo(enumValues: e) }
    if let c = s.field("const") { return ScalarTypeInfo(enumValues: [c]) }
    switch s.field("type")?.stringValue {
    case "string": return ScalarTypeInfo(expectedType: "string")
    case "number", "integer": return ScalarTypeInfo(expectedType: "number")
    case "boolean": return ScalarTypeInfo(expectedType: "boolean")
    default: return ScalarTypeInfo()
    }
}

/// Read a schema fragment's `default`, if it carries one.
func getSchemaDefaultValue(_ property: JSONValue?) -> Value? {
    guard let d = property?.field("default") else { return nil }
    return jsonToValue(d)
}

/// Convert an ordered JSONValue to a runtime Value.
public func jsonToValue(_ j: JSONValue) -> Value {
    switch j {
    case .string(let s): return .string(s)
    case .number(let n): return .number(n)
    case .boolean(let b): return .boolean(b)
    case .null: return .null
    case .array(let items): return .array(items.map(jsonToValue))
    case .object(let fields):
        return .object(fields.map { ObjectField(key: $0.key, value: jsonToValue($0.value)) })
    }
}

/// Expected type string for hints/signatures.
func getTypeFromSchema(_ property: JSONValue?) -> String? {
    guard let p = property else { return nil }
    if let ref = refName(p) { return ref }
    let leaf = getScalarTypeInfo(p)
    if let ev = leaf.enumValues {
        return ev.map(jsonValueToString).joined(separator: "|")
    }
    if let t = leaf.expectedType { return t }
    return p.field("type")?.stringValue
}

func jsonValueToString(_ j: JSONValue) -> String {
    switch j {
    case .string(let s): return "\"\(s)\""
    case .number(let n): return stringFromNumber(n)
    case .boolean(let b): return b ? "true" : "false"
    case .null: return "null"
    default: return "?"
    }
}

/// Build `Header(title*: string, variant: "a"|"b")` — * marks required.
public func buildParamsSignature(_ component: String, _ params: [ParamDef]) -> String {
    let rendered = params.map { p -> String in
        let marked = p.required ? "\(p.name)*" : p.name
        if let t = getTypeFromSchema(p.schema) { return "\(marked): \(t)" }
        return marked
    }.joined(separator: ", ")
    return "\(component)(\(rendered))"
}

// MARK: - Invalid-value resolution (the edge rule)

public enum ValidationOutcome {
    case kept(Materialized)
    case invalid
}

public enum InvalidResolution {
    case useDefault(Value)
    case dropProp
    case invalid
}

/// Schema default → substitute; REQUIRED edge → invalid (caller repeats one
/// level up); OPTIONAL edge → prune.
public func resolveInvalidValue(required: Bool, hasDefault: Bool, defaultValue: Value) -> InvalidResolution {
    if hasDefault { return .useDefault(defaultValue) }
    return required ? .invalid : .dropProp
}

// MARK: - Type checking

/// JS typeof for a Value (arrays → "array", null → "object").
func jsType(_ v: Value) -> String {
    switch v {
    case .string: return "string"
    case .number: return "number"
    case .boolean: return "boolean"
    case .array: return "array"
    default: return "object" // null, object, element, actionPlan
    }
}

func jsonValuesEqual(_ a: JSONValue, _ b: JSONValue) -> Bool {
    switch (a, b) {
    case (.string(let x), .string(let y)): return x == y
    case (.number(let x), .number(let y)): return x == y
    case (.boolean(let x), .boolean(let y)): return x == y
    case (.null, .null): return true
    case (.array(let x), .array(let y)):
        return x.count == y.count && zip(x, y).allSatisfy(jsonValuesEqual)
    case (.object(let x), .object(let y)):
        return x.count == y.count && zip(x, y).allSatisfy { $0.key == $1.key && jsonValuesEqual($0.value, $1.value) }
    default: return false
    }
}

func valueMatchesJSON(_ v: Value, _ j: JSONValue) -> Bool {
    switch (v, j) {
    case (.string(let a), .string(let b)): return a == b
    case (.number(let a), .number(let b)): return a == b
    case (.boolean(let a), .boolean(let b)): return a == b
    case (.null, .null): return true
    default: return false
    }
}

/// Check a scalar/enum leaf. Returns (expected, actual) on mismatch.
func checkTypeMismatch(_ value: Value, _ info: ScalarTypeInfo) -> (expected: String, actual: String)? {
    let actual = jsType(value)
    if let enumValues = info.enumValues {
        // Enum only constrains scalar values.
        guard actual == "string" || actual == "number" || actual == "boolean" else { return nil }
        if enumValues.contains(where: { valueMatchesJSON(value, $0) }) { return nil }
        let list = enumValues.map(jsonValueToString).joined(separator: ", ")
        return ("one of [\(list)]", jsonValueForMessage(value))
    }
    if let expected = info.expectedType, expected != actual {
        return (expected, actual)
    }
    return nil
}

func jsonValueForMessage(_ v: Value) -> String {
    switch v {
    case .string(let s): return "\"\(s)\""
    case .number(let n): return stringFromNumber(n)
    case .boolean(let b): return b ? "true" : "false"
    case .null: return "null"
    case .array: return "array"
    default: return jsType(v)
    }
}

// MARK: - Recursive validation

/// Validate a materialized value against a JSON Schema fragment.
/// Never crashes: returns the value itself when nothing changes, a cleaned
/// copy when something does, or .invalid.
public func validateMaterialized(
    _ value: Materialized,
    schema: JSONValue?,
    component: String,
    path: String,
    ctx: MaterializeContext
) -> ValidationOutcome {
    guard let s = schema, case .object = s else { return .kept(value) }
    // Absence is handled by required checks on the parent; skip null.
    if case .null = value { return .kept(value) }
    // Dynamic runtime expressions resolve later — don't flag.
    if case .expr = value { return .kept(value) }
    // Child components: only their position is checked here.
    if case .element(let el) = value {
        return validateElementPosition(el, s, component: component, path: path, ctx: ctx)
            ? .invalid : .kept(value)
    }
    if isCompositeSchema(s) {
        // Data in a component-only slot is invalid.
        guard isOnlyComponentSlot(s, ctx: ctx) else { return .kept(value) }
        let names = slotRefNames(s).compactMap { $0 }.joined(separator: " | ")
        let actual: String
        switch value {
        case .value(let v): actual = jsType(v) == "object" && !isNullValue(v) ? "plain object" : jsType(v)
        case .array: actual = "array"
        default: actual = "value"
        }
        pushValidationIssue(ctx, component: component, path: path,
                            issue: .typeMismatch(expected: names, actual: actual))
        return .invalid
    }

    switch s.field("type")?.stringValue {
    case "object":
        return validateObjectValue(value, s, component: component, path: path, ctx: ctx)
    case "array":
        return validateArrayValue(value, s, component: component, path: path, ctx: ctx)
    default:
        return validateLeafValue(value, s, component: component, path: path, ctx: ctx)
    }
}

/// Position check for a component element in a data slot.
func validateElementPosition(
    _ element: ElementNode,
    _ s: JSONValue,
    component: String,
    path: String,
    ctx: MaterializeContext
) -> Bool {
    if isCompositeSchema(s) { return false }
    let hasType = s.field("type")?.stringValue != nil
    let hasEnum = s.field("enum")?.arrayItems != nil
    let hasConst = s.field("const") != nil
    if hasType || hasEnum || hasConst {
        let expected: String
        if let t = s.field("type")?.stringValue { expected = t } else { expected = "a literal value" }
        pushValidationIssue(ctx, component: component, path: path,
                            issue: .typeMismatch(expected: expected,
                                                 actual: "component \"\(element.typeName)\""))
        return true
    }
    return false
}

/// The `$ref` names a slot allows.
func slotRefNames(_ s: JSONValue) -> [String?] {
    let options: [JSONValue]
    if let a = s.field("anyOf")?.arrayItems { options = a }
    else if let o = s.field("oneOf")?.arrayItems { options = o }
    else { options = [s] }
    return options.map(refName)
}

/// True when every option of the slot is a `$ref` to a component.
func isOnlyComponentSlot(_ s: JSONValue, ctx: MaterializeContext) -> Bool {
    let names = slotRefNames(s)
    guard !names.isEmpty else { return false }
    let components = ctx.componentNames
    return names.allSatisfy { $0 != nil && components.contains($0!) }
}

func validateObjectValue(
    _ value: Materialized,
    _ s: JSONValue,
    component: String,
    path: String,
    ctx: MaterializeContext
) -> ValidationOutcome {
    // Unwrap to plain object fields.
    let fields: [(String, Materialized)]
    switch value {
    case .value(.object(let f)): fields = f.map { ($0.key, Materialized.value($0.value)) }
    case .object(let entries): fields = entries
    default:
        pushValidationIssue(ctx, component: component, path: path,
                            issue: .typeMismatch(expected: "object", actual: materializedJsType(value)))
        return .invalid
    }

    var fieldMap: [String: Materialized] = [:]
    for (k, v) in fields { fieldMap[k] = v }

    let props = s.field("properties")?.objectFields ?? []
    let propMap: [String: JSONValue] = Dictionary(uniqueKeysWithValues: props)
    let required: [String] = s.field("required")?.arrayItems?.compactMap { $0.stringValue } ?? []

    var invalid = false
    var out: [(String, Materialized)]? = nil

    // Structural checks are streaming-sensitive — only run on complete input.
    if !ctx.partial {
        for key in required {
            let present = fieldMap[key] != nil
            let isNull = present && isNullMaterialized(fieldMap[key]!)
            if !present || isNull {
                if let fallback = getSchemaDefaultValue(propMap[key]) {
                    var entries = out ?? fields
                    if let idx = entries.firstIndex(where: { $0.0 == key }) {
                        entries[idx] = (key, .value(fallback))
                    } else {
                        entries.append((key, .value(fallback)))
                    }
                    out = entries
                    continue
                }
                pushValidationIssue(ctx, component: component, path: "\(path)/\(key)",
                                    issue: present ? .nullRequired(signature: nil) : .missingRequired(signature: nil))
                invalid = true
            }
        }
    }

    for (key, sub) in props {
        guard let current = fieldMap[key] else { continue }
        let outcome = validateMaterialized(current, schema: sub, component: component,
                                           path: "\(path)/\(key)", ctx: ctx)
        switch outcome {
        case .kept(let m):
            if !materializedEqual(m, current) {
                var entries = out ?? fields
                if let idx = entries.firstIndex(where: { $0.0 == key }) {
                    entries[idx] = (key, m)
                    out = entries
                }
            }
        case .invalid:
            let resolved = resolveInvalidValue(required: required.contains(key),
                                               hasDefault: getSchemaDefaultValue(sub) != nil,
                                               defaultValue: getSchemaDefaultValue(sub) ?? .null)
            var entries = out ?? fields
            switch resolved {
            case .useDefault(let v):
                if let idx = entries.firstIndex(where: { $0.0 == key }) {
                    entries[idx] = (key, .value(v))
                } else {
                    entries.append((key, .value(v)))
                }
                out = entries
            case .dropProp:
                entries.removeAll(where: { $0.0 == key })
                out = entries
            case .invalid:
                invalid = true
            }
        }
    }

    if invalid { return .invalid }
    guard let result = out else { return .kept(value) }
    // Rebuild in the original representation.
    switch value {
    case .value: return .kept(.value(.object(result.map { ObjectField(key: $0.0, value: materializedToPlain($0.1) ?? .null) })))
    case .object: return .kept(.object(result))
    default: return .kept(value)
    }
}

/// Convert Materialized to plain Value when possible (for object rebuild).
func materializedToPlain(_ m: Materialized) -> Value? {
    switch m {
    case .value(let v): return v
    case .null: return .null
    case .element: return nil // Unevaluated element has no plain Value form.
    case .array(let items):
        var out: [Value] = []
        for i in items { guard let v = materializedToPlain(i) else { return nil }; out.append(v) }
        return .array(out)
    case .object(let entries):
        var out: [ObjectField] = []
        for (k, v) in entries { guard let pv = materializedToPlain(v) else { return nil }; out.append(ObjectField(key: k, value: pv)) }
        return .object(out)
    case .expr: return nil
    }
}

func validateArrayValue(
    _ value: Materialized,
    _ s: JSONValue,
    component: String,
    path: String,
    ctx: MaterializeContext
) -> ValidationOutcome {
    let items: [Materialized]
    let wasPlain: Bool
    switch value {
    case .value(.array(let a)):
        items = a.map { .value($0) }; wasPlain = true
    case .array(let m):
        items = m; wasPlain = false
    default:
        pushValidationIssue(ctx, component: component, path: path,
                            issue: .typeMismatch(expected: "array", actual: materializedJsType(value)))
        return .invalid
    }
    guard let itemSchema = s.field("items") else {
        return .kept(value)
    }
    var out: [Materialized]? = nil
    for i in 0..<items.count {
        let outcome = validateMaterialized(items[i], schema: itemSchema, component: component,
                                           path: "\(path)/\(i)", ctx: ctx)
        switch outcome {
        case .kept(let m):
            if out == nil {
                if !materializedEqual(m, items[i]) {
                    out = Array(items[0..<i]) + [m]
                }
            } else {
                out!.append(m)
            }
        case .invalid:
            // Invalid items are pruned; paths keep original indices.
            if out == nil { out = Array(items[0..<i]) }
        }
    }
    guard let result = out else { return .kept(value) }
    if wasPlain {
        var plain: [Value] = []
        for m in result { guard let v = materializedToPlain(m) else { return .kept(value) }; plain.append(v) }
        return .kept(.value(.array(plain)))
    }
    return .kept(.array(result))
}

/// Validate a scalar/enum leaf. Enum membership defers while streaming.
func validateLeafValue(
    _ value: Materialized,
    _ s: JSONValue,
    component: String,
    path: String,
    ctx: MaterializeContext
) -> ValidationOutcome {
    let leaf = getScalarTypeInfo(s)
    guard leaf.expectedType != nil || leaf.enumValues != nil else { return .kept(value) }
    if leaf.enumValues != nil && ctx.partial { return .kept(value) }
    guard case .value(let v) = value else { return .kept(value) }
    if let mismatch = checkTypeMismatch(v, leaf) {
        pushValidationIssue(ctx, component: component, path: path,
                            issue: .typeMismatch(expected: mismatch.expected, actual: mismatch.actual))
        return .invalid
    }
    return .kept(value)
}

func materializedJsType(_ m: Materialized) -> String {
    switch m {
    case .value(let v): return jsType(v)
    case .array: return "array"
    case .object: return "object"
    case .element: return "object"
    case .expr: return "object"
    case .null: return "object"
    }
}

func materializedEqual(_ a: Materialized, _ b: Materialized) -> Bool {
    a == b
}
