// OpenUILang — Form validation rules.
//
// Swift port of utils/validation.ts (spec §5.4): the 9 built-in rules
// (required, email, url, numeric, min, max, minLength, maxLength, pattern).
// Every rule except `required` skips empty values; the first failing rule wins.

import Foundation

/// A rule parameter: the numeric arg of min/max/minLength/maxLength,
/// or the pattern string of `pattern`.
public enum ValidationRuleParameter: Sendable, Equatable {
    case number(Double)
    case string(String)
}

/// A parsed validation rule. Mirrors `ParsedRule` from utils/validation.ts.
public struct ValidationRule: Sendable, Equatable {
    public var kind: String
    public var parameter: ValidationRuleParameter?
    public init(kind: String, parameter: ValidationRuleParameter? = nil) {
        self.kind = kind
        self.parameter = parameter
    }
}

/// Parse a structured rules object into `[ValidationRule]`.
/// Accepts e.g. `{ required: true, minLength: 5, email: true, max: 100 }`.
/// Keys with false/null values are skipped. Mirrors `parseStructuredRules`.
public func parseStructuredRules(_ json: JSONValue) -> [ValidationRule] {
    guard case .object(let fields) = json else { return [] }
    var result: [ValidationRule] = []
    for field in fields {
        switch field.value {
        case .boolean(false), .null:
            continue
        case .boolean(true):
            result.append(ValidationRule(kind: field.key))
        case .number(let n):
            result.append(ValidationRule(kind: field.key, parameter: .number(n)))
        case .string(let s):
            result.append(ValidationRule(kind: field.key, parameter: .string(s)))
        case .array, .object:
            // Upstream keeps these as args; no validator can use a
            // non-scalar arg, so the rule is recorded without a parameter.
            // (min/max with an object arg are skipped rather than failing.)
            result.append(ValidationRule(kind: field.key))
        }
    }
    return result
}

/// Run all rules against a value; return the first failing rule's message,
/// or nil when every rule passes. Mirrors `validate`.
public func validate(_ value: Value, rules: [ValidationRule]) -> String? {
    for rule in rules {
        // Unknown rule kinds are skipped (upstream logs a console warning;
        // this port stays silent to avoid noisy stdout from a library).
        if let message = runValidationRule(rule, value: value) { return message }
    }
    return nil
}

// MARK: - Private

private func isEmptyValue(_ value: Value) -> Bool {
    switch value {
    case .null: return true
    case .string(let s): return s.isEmpty
    case .array(let a): return a.isEmpty
    case .object(let fields): return fields.isEmpty
    default: return false
    }
}

private func numberParameter(_ p: ValidationRuleParameter?) -> Double? {
    switch p {
    case .number(let n): return n
    case .string(let s): return Double(s)
    case nil: return nil
    }
}

private func stringParameter(_ p: ValidationRuleParameter?) -> String? {
    if case .string(let s) = p { return s }
    return nil
}

/// JS parseFloat semantics: leading whitespace ignored, longest numeric
/// prefix parsed ("12abc" → 12), otherwise nil. Mirrors the `numeric` rule.
private func jsParseFloat(_ s: String) -> Double? {
    let pattern = #"^[\s]*[+-]?(?:Infinity|(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?)"#
    guard let re = try? NSRegularExpression(pattern: pattern),
          let match = re.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)),
          let range = Range(match.range, in: s)
    else { return nil }
    return Double(String(s[range]).trimmingCharacters(in: .whitespaces))
}

// Validator messages use the public `jsNumberString` from Signature.swift
// (JS String(number) formatting: "5", not "5.0").

private func runValidationRule(_ rule: ValidationRule, value: Value) -> String? {
    switch rule.kind {
    case "required":
        return validateRequired(value)
    case "email":
        if isEmptyValue(value) { return nil }
        guard case .string(let s) = value else { return "Please enter a valid email" }
        return matchesEmail(s) ? nil : "Please enter a valid email"
    case "url":
        if isEmptyValue(value) { return nil }
        guard case .string(let s) = value, isAbsoluteURL(s) else { return "Please enter a valid URL" }
        return nil
    case "numeric":
        if isEmptyValue(value) { return nil }
        switch value {
        case .number(let n):
            return n.isNaN ? "Must be a number" : nil
        case .string(let s):
            let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { return "Must be a number" }
            return jsParseFloat(s) == nil ? "Must be a number" : nil
        default:
            return "Must be a number"
        }
    case "min", "max":
        if isEmptyValue(value) { return nil }
        let n: Double?
        switch value {
        case .number(let d): n = d
        case .string(let s): n = jsParseFloat(s)
        default: n = nil // e.g. booleans: JS parseFloat("true") is NaN → skip
        }
        guard let n = n, !n.isNaN, let bound = numberParameter(rule.parameter) else { return nil }
        if rule.kind == "min" {
            return n >= bound ? nil : "Must be at least \(jsNumberString(bound))"
        } else {
            return n <= bound ? nil : "Must be no more than \(jsNumberString(bound))"
        }
    case "minLength", "maxLength":
        if isEmptyValue(value) { return nil }
        guard case .string(let s) = value, let bound = numberParameter(rule.parameter) else { return nil }
        let count = Double(s.count)
        if rule.kind == "minLength" {
            return count >= bound ? nil : "Must be at least \(jsNumberString(bound)) characters"
        } else {
            return count <= bound ? nil : "Must be no more than \(jsNumberString(bound)) characters"
        }
    case "pattern":
        if isEmptyValue(value) { return nil }
        guard case .string(let s) = value, let pattern = stringParameter(rule.parameter) else { return nil }
        // Invalid patterns fail open (upstream catches the RegExp throw).
        guard let re = try? NSRegularExpression(pattern: pattern) else { return nil }
        return re.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) != nil ? nil : "Invalid format"
    default:
        return nil
    }
}

private func validateRequired(_ value: Value) -> String? {
    if isEmptyValue(value) { return "This field is required" }
    if case .object(let fields) = value, !fields.isEmpty,
       fields.allSatisfy({ $0.value == .boolean(true) || $0.value == .boolean(false) }),
       !fields.contains(where: { $0.value == .boolean(true) }) {
        return "At least one option is required"
    }
    return nil
}

/// Absolute URL with scheme + host. Mirrors `new URL(value)` (which rejects
/// relative URLs) without relying on Foundation's lenient `URL(string:)`.
private func isAbsoluteURL(_ s: String) -> Bool {
    guard let url = URL(string: s),
          let scheme = url.scheme, !scheme.isEmpty,
          let host = url.host, !host.isEmpty
    else { return false }
    return true
}

private func matchesEmail(_ s: String) -> Bool {
    // A hardcoded pattern that always compiles; try? is a formality.
    guard let re = try? NSRegularExpression(pattern: #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#) else { return false }
    return re.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) != nil
}
