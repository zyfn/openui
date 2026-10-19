// OpenUILang — Prompt signatures.
//
// Swift port of signature.ts's schemaSignature/buildSignature plus
// prompt.md §5.1–5.3, driven by compiled ParamDef schemas (JSON Schema
// fragments) instead of Zod introspection.

import Foundation

// MARK: - Type annotations from JSON Schema (prompt.md §5.1)

/// Human-readable type annotation for a param's JSON Schema fragment.
/// Mirrors resolveTypeAnnotation/resolveBaseType in signature.ts:
/// primitives print as `string`/`number`/`boolean`/`any`, enums as quoted
/// alternatives joined by `|`, arrays as `T[]`, inline objects as
/// `{field: type}`, unions joined by `|`, and `$ref: "#/$defs/Name"` resolves
/// to the shared schema's id (`Name`).
private func schemaTypeAnnotation(_ schema: JSONValue) -> String? {
    // An inlined action $ref keeps its shared schema id (prompt.md §5.1).
    if let name = schema.field("x-openui-ref")?.stringValue {
        return name
    }
    // $ref -> the shared schema id (e.g. "#/$defs/Card" -> "Card")
    if let ref = schema.field("$ref")?.stringValue {
        let name = ref.split(separator: "/").last.map(String.init) ?? ref
        return name
    }

    // enum / const -> quoted alternatives joined by |
    if let items = schema.field("enum")?.arrayItems {
        return items.map { jsonScalarLiteral($0) }.joined(separator: " | ")
    }
    if let c = schema.field("const") {
        return jsonScalarLiteral(c)
    }

    // anyOf / oneOf -> union joined by |
    if let anyOf = schema.field("anyOf")?.arrayItems ?? schema.field("oneOf")?.arrayItems {
        let parts = anyOf.compactMap { schemaTypeAnnotation($0) }.filter { $0 != "null" }
        if !parts.isEmpty { return parts.joined(separator: " | ") }
    }

    let typeName = schema.field("type")?.stringValue

    if typeName == "array" {
        guard let items = schema.field("items") else { return "any[]" }
        guard let inner = schemaTypeAnnotation(items) else { return nil }
        let itemsIsUnion = items.field("anyOf") != nil || items.field("oneOf") != nil
        return itemsIsUnion ? "(\(inner))[]" : "\(inner)[]"
    }

    if typeName == "string" { return "string" }
    if typeName == "number" || typeName == "integer" { return "number" }
    if typeName == "boolean" { return "boolean" }

    if typeName == "object" {
        if let props = schema.field("properties")?.objectFields {
            let required = Set(schema.field("required")?.arrayItems?.compactMap { $0.stringValue } ?? [])
            let fields = props.map { (key, sub) -> String in
                let opt = required.contains(key) ? "" : "?"
                if let t = schemaTypeAnnotation(sub) { return "\(key)\(opt): \(t)" }
                return "\(key)\(opt)"
            }
            return "{\(fields.joined(separator: ", "))}"
        }
        // Record<K, V>
        let valueType = schema.field("additionalProperties").flatMap { schemaTypeAnnotation($0) } ?? "any"
        return "Record<string, \(valueType)>"
    }

    // Fallback: "any" is safer than nothing — the LLM sees `param: any`.
    return "any"
}

/// JSON scalar rendered like JSON.stringify: strings quoted, numbers plain.
private func jsonScalarLiteral(_ value: JSONValue) -> String {
    switch value {
    case .string(let s): return jsonStringLiteral(s)
    case .number(let n): return jsNumberString(n)
    case .boolean(let b): return b ? "true" : "false"
    case .null: return "null"
    default: return "any"
    }
}

// MARK: - Public signature builders

/// Full prompt signature: `Button(label: string, action?: ActionExpression,
/// variant?: "primary" | "secondary")`.
///
/// - Primitives print as `string`/`number`/`boolean`/`any`.
/// - Enums print as quoted alternatives joined by `|`.
/// - Arrays print as `T[]`.
/// - A prop with `isBindable` prints as `$binding<type>`.
/// - An optional prop has `?` before the colon: `variant?: "primary"`.
public func buildSignature(name: String, params: [ParamDef]) -> String {
    let rendered = params.map { param -> String in
        let opt = param.required ? "" : "?"
        if let schema = param.schema, var type = schemaTypeAnnotation(schema) {
            if param.isBindable { type = "$binding<\(type)>" }
            return "\(param.name)\(opt): \(type)"
        }
        return "\(param.name)\(opt)"
    }
    return "\(name)(\(rendered.joined(separator: ", ")))"
}

/// Short error-hint signature (prompt.md §5.3): prop names only, required
/// props starred: `Signature: BarChart(labels*, series*, variant)`.
public func buildHintSignature(name: String, params: [ParamDef]) -> String {
    let rendered = params.map { $0.required ? "\($0.name)*" : $0.name }
    return "Signature: \(name)(\(rendered.joined(separator: ", ")))"
}

// MARK: - Shared literal helpers (also used by Serialize.swift)

/// A string as a JSON string literal, like JSON.stringify.
public func jsonStringLiteral(_ s: String) -> String {
    var out = "\""
    for scalar in s.unicodeScalars {
        switch scalar.value {
        case 0x22: out += "\\\""
        case 0x5C: out += "\\\\"
        case 0x08: out += "\\b"
        case 0x0C: out += "\\f"
        case 0x0A: out += "\\n"
        case 0x0D: out += "\\r"
        case 0x09: out += "\\t"
        default:
            if scalar.value < 0x20 {
                out += String(format: "\\u%04x", scalar.value)
            } else {
                out += String(scalar)
            }
        }
    }
    out += "\""
    return out
}

/// A number rendered like JavaScript's String(n): no trailing ".0".
public func jsNumberString(_ d: Double) -> String {
    if d.isNaN { return "NaN" }
    if d.isInfinite { return d > 0 ? "Infinity" : "-Infinity" }
    if d.truncatingRemainder(dividingBy: 1) == 0 && abs(d) < 1e21 {
        return String(Int64(d))
    }
    return String(d)
}

/// Whether a name can be written bare in openui-lang (spec §9.2: object keys
/// are written unquoted, so they must be valid names to round-trip).
public func isBareName(_ s: String) -> Bool {
    guard let first = s.unicodeScalars.first else { return false }
    let isStart: (Unicode.Scalar) -> Bool = {
        $0 == "_" || $0 == "$" || CharacterSet.letters.contains($0)
    }
    let isPart: (Unicode.Scalar) -> Bool = {
        isStart($0) || CharacterSet.decimalDigits.contains($0)
    }
    guard isStart(first) else { return false }
    return s.unicodeScalars.dropFirst().allSatisfy(isPart)
}
