// OpenUILang — Built-in functions.
//
// Swift port of the `builtins` array in parser_builtins.ts. All 13 built-in
// functions with exact ECMA-262 semantics:
// - toNumber: never NaN (unparseable → 0)
// - Division/modulo by zero → 0 (not Infinity/NaN)
// - Sort uses locale-aware collation (localeCompare); numeric strings sort numerically
// - Round is half-up (JS Math.round: half towards +∞)
// - Filter supports ==, !=, >, <, >=, <=, contains with loose equality

import Foundation

/// JS ToNumber with the DSL tweak: unparseable → 0, never NaN.
public func ouiToNumber(_ value: Value) -> Double {
    switch value {
    case .number(let n): return n
    case .string(let s):
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return 0 }
        // JS Number(): hex, Infinity, exponents. Swift Double handles most.
        let lower = t.lowercased()
        if lower.hasPrefix("0x") {
            return Double(Int(t.dropFirst(2), radix: 16) ?? 0)
        }
        if lower == "infinity" || lower == "+infinity" { return .infinity }
        if lower == "-infinity" { return -.infinity }
        return Double(t) ?? 0
    case .boolean(let b): return b ? 1 : 0
    case .null: return 0
    default: return 0
    }
}

/// JS String(value) for primitives.
public func ouiToString(_ value: Value) -> String {
    switch value {
    case .string(let s): return s
    case .number(let n): return jsNumberString(n)
    case .boolean(let b): return b ? "true" : "false"
    case .null: return "null"
    default: return ""
    }
}

/// JS IsLooselyEqual (==). Mirrors the spec algorithm for the value kinds
/// OpenUI supports (primitives only; objects never appear here).
public func isLooselyEqual(_ a: Value, _ b: Value) -> Bool {
    // Same type → strict.
    switch (a, b) {
    case (.null, .null): return true
    case (.boolean(let x), .boolean(let y)): return x == y
    case (.string(let x), .string(let y)): return x == y
    case (.number(let x), .number(let y)): return x == y
    case (.null, _), (_, .null): return false
    case (.boolean, _): return isLooselyEqual(.number(ouiToNumber(a)), b)
    case (_, .boolean): return isLooselyEqual(a, .number(ouiToNumber(b)))
    case (.string, .number), (.number, .string):
        return ouiToNumber(a) == ouiToNumber(b)
    default: return false
    }
}

/// JS truthiness for &&, ||, !, ternary.
public func isTruthy(_ value: Value) -> Bool {
    switch value {
    case .null: return false
    case .boolean(let b): return b
    case .number(let n): return n != 0
    case .string(let s): return !s.isEmpty
    case .array(let a): return !a.isEmpty
    case .object(let o): return !o.isEmpty
    case .element, .actionPlan, .binding: return true
    }
}

/// Resolve a dotted field path on a value (for @Sort/@Filter).
func resolveField(_ value: Value, _ path: String) -> Value {
    var cur = value
    for part in path.split(separator: ".") {
        let key = String(part)
        switch cur {
        case .object(let fields):
            guard let f = fields.first(where: { $0.key == key }) else { return .null }
            cur = f.value
        case .array(let items):
            if key == "length" { return .number(Double(items.count)) }
            guard let i = Int(key), i >= 0, i < items.count else { return .null }
            cur = items[i]
        default:
            return .null
        }
    }
    return cur
}

// MARK: - Built-in function implementations

/// @Count(array) → array length, else 0.
func builtinCount(_ args: [String: Value]) -> Value {
    if case .array(let a) = args["array"] { return .number(Double(a.count)) }
    return .number(0)
}

/// @First(array) → first element or null.
func builtinFirst(_ args: [String: Value]) -> Value {
    if case .array(let a) = args["array"] { return a.first ?? .null }
    return .null
}

/// @Last(array) → last element or null.
func builtinLast(_ args: [String: Value]) -> Value {
    if case .array(let a) = args["array"] { return a.last ?? .null }
    return .null
}

/// @Sum(numbers) → sum via toNumber.
func builtinSum(_ args: [String: Value]) -> Value {
    guard case .array(let a) = args["numbers"] else { return .number(0) }
    return .number(a.reduce(0) { $0 + ouiToNumber($1) })
}

/// @Avg(numbers) → mean, else 0.
func builtinAvg(_ args: [String: Value]) -> Value {
    guard case .array(let a) = args["numbers"], !a.isEmpty else { return .number(0) }
    return .number(a.reduce(0) { $0 + ouiToNumber($1) } / Double(a.count))
}

/// @Min(numbers) → min via toNumber, else 0.
func builtinMin(_ args: [String: Value]) -> Value {
    guard case .array(let a) = args["numbers"], !a.isEmpty else { return .number(0) }
    return .number(a.map(ouiToNumber).reduce(ouiToNumber(a[0]), min))
}

/// @Max(numbers) → max via toNumber, else 0.
func builtinMax(_ args: [String: Value]) -> Value {
    guard case .array(let a) = args["numbers"], !a.isEmpty else { return .number(0) }
    return .number(a.map(ouiToNumber).reduce(ouiToNumber(a[0]), max))
}

private func isNumericValue(_ v: Value) -> Bool {
    switch v {
    case .number: return true
    case .string(let s):
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return !t.isEmpty && Double(t) != nil
    default: return false
    }
}

/// @Sort(array, field, direction?) — locale-aware collation; numeric values
/// (numbers or numeric strings) sort numerically. Non-arrays pass through.
func builtinSort(_ args: [String: Value]) -> Value {
    guard case .array(let arr) = args["array"] else {
        return args["array"] ?? .null
    }
    let field = ouiToString(args["field"] ?? .string(""))
    let desc = ouiToString(args["direction"] ?? .string("asc")) == "desc"
    let sorted = arr.sorted { a, b in
        let av = field.isEmpty ? a : resolveField(a, field)
        let bv = field.isEmpty ? b : resolveField(b, field)
        let cmp: ComparisonResult
        if isNumericValue(av) && isNumericValue(bv) {
            let diff = ouiToNumber(av) - ouiToNumber(bv)
            cmp = diff < 0 ? .orderedAscending : (diff > 0 ? .orderedDescending : .orderedSame)
        } else {
            // Locale-aware collation (like JS localeCompare). Null → "".
            let aStr: String
            let bStr: String
            if case .null = av { aStr = "" } else { aStr = ouiToString(av) }
            if case .null = bv { bStr = "" } else { bStr = ouiToString(bv) }
            cmp = aStr.localizedCompare(bStr)
        }
        if desc {
            return cmp == .orderedDescending
        }
        return cmp == .orderedAscending
    }
    return .array(sorted)
}

/// @Filter(array, field, operator, value).
func builtinFilter(_ args: [String: Value]) -> Value {
    guard case .array(let arr) = args["array"] else { return .array([]) }
    let field = ouiToString(args["field"] ?? .string(""))
    let op = ouiToString(args["operator"] ?? .string("=="))
    let target = args["value"] ?? .null
    let filtered = arr.filter { item in
        let v = field.isEmpty ? item : resolveField(item, field)
        switch op {
        case "==": return isLooselyEqual(v, target)
        case "!=": return !isLooselyEqual(v, target)
        case ">": return ouiToNumber(v) > ouiToNumber(target)
        case "<": return ouiToNumber(v) < ouiToNumber(target)
        case ">=": return ouiToNumber(v) >= ouiToNumber(target)
        case "<=": return ouiToNumber(v) <= ouiToNumber(target)
        case "contains": return ouiToString(v).contains(ouiToString(target))
        default: return false
        }
    }
    return .array(filtered)
}

/// @Round(number, decimals?) — JS Math.round (half towards +∞).
func builtinRound(_ args: [String: Value]) -> Value {
    let num = ouiToNumber(args["number"] ?? .null)
    let d = args["decimals"].map(ouiToNumber) ?? 0
    let factor = pow(10.0, d)
    // Math.round: floor(x + 0.5), half towards +∞.
    return .number(floor(num * factor + 0.5) / factor)
}

/// @Abs(number).
func builtinAbs(_ args: [String: Value]) -> Value {
    .number(abs(ouiToNumber(args["number"] ?? .null)))
}

/// @Floor(number).
func builtinFloor(_ args: [String: Value]) -> Value {
    .number(floor(ouiToNumber(args["number"] ?? .null)))
}

/// @Ceil(number).
func builtinCeil(_ args: [String: Value]) -> Value {
    .number(ceil(ouiToNumber(args["number"] ?? .null)))
}

/// Dispatch table: builtin name (no @) → implementation.
public let builtinImplementations: [String: ([String: Value]) -> Value] = [
    "Count": builtinCount,
    "First": builtinFirst,
    "Last": builtinLast,
    "Sum": builtinSum,
    "Avg": builtinAvg,
    "Min": builtinMin,
    "Max": builtinMax,
    "Sort": builtinSort,
    "Filter": builtinFilter,
    "Round": builtinRound,
    "Abs": builtinAbs,
    "Floor": builtinFloor,
    "Ceil": builtinCeil,
]

/// JS String(value) for string concat: null → "" (avoids "textnull").
func concatString(_ value: Value) -> String {
    if case .null = value { return "" }
    return ouiToString(value)
}
