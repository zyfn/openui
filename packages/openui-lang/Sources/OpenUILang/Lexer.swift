// OpenUILang — Lexer.
//
// Ports packages/lang-core/src/parser/lexer.ts, tokens.ts, statements.ts,
// and the preprocess helpers from parser.ts:
// tokenize, stripFences, stripComments, autoClose, split.

import Foundation

// MARK: - Tokens

public enum Token: Equatable {
    case newline
    case lParen, rParen
    case lBrack, rBrack
    case lBrace, rBrace
    case comma, colon
    case equals, eqEq
    case not, notEq
    case greater, greaterEq
    case less, lessEq
    case and, or
    case dot, question
    case plus, star, slash, percent
    case minus
    case str(String)
    case num(Double)
    case ident(String) // lowercase reference
    case type(String) // PascalCase component name
    case stateVar(String) // $name, $ included
    case builtinCall(String) // @name, @ excluded
    case `true`, `false`, `null`
    case eof
}

// MARK: - JSON string unescaping (for double-quoted literals)

/// Unescape a JSON string body (without surrounding quotes).
/// Mirrors JSON.parse on the raw literal, with a lenient fallback.
func unescapeJSONString(_ body: String) -> String {
    var out = ""
    var i = body.startIndex
    while i < body.endIndex {
        let c = body[i]
        if c == "\\" {
            let n = body.index(after: i)
            guard n < body.endIndex else { out.append("\\"); break }
            let e = body[n]
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
                let h1 = body.index(n, offsetBy: 1, limitedBy: body.endIndex) ?? body.endIndex
                let h2 = body.index(h1, offsetBy: 4, limitedBy: body.endIndex) ?? body.endIndex
                if h1 < body.endIndex {
                    let hex = String(body[h1..<min(h2, body.endIndex)])
                    if hex.count == 4, let code = UInt32(hex, radix: 16), let s = Unicode.Scalar(code) {
                        out.append(Character(s))
                        i = h2
                        continue
                    }
                }
                // Malformed escape: keep raw (lenient fallback).
                out.append("\\u")
                i = body.index(after: n)
                continue
            default:
                // JSON.parse would throw; upstream falls back to raw text.
                // Keep the backslash and the char.
                out.append("\\")
                out.append(e)
            }
            i = body.index(after: n)
        } else {
            out.append(c)
            i = body.index(after: i)
        }
    }
    return out
}

// MARK: - Tokenizer

/// Tokenize an openui-lang source string. Lexing never fails:
/// characters matching no rule are skipped.
public func tokenize(_ src: String) -> [Token] {
    var tokens: [Token] = []
    let chars = Array(src)
    let n = chars.count
    var i = 0

    func isAlpha(_ c: Character) -> Bool {
        (c >= "a" && c <= "z") || (c >= "A" && c <= "Z") || c == "_"
    }
    func isAlphaNum(_ c: Character) -> Bool {
        isAlpha(c) || (c >= "0" && c <= "9")
    }

    while i < n {
        // Skip horizontal whitespace (newlines are significant).
        while i < n && (chars[i] == " " || chars[i] == "\t" || chars[i] == "\r") { i += 1 }
        if i >= n { break }
        let c = chars[i]

        func twoChar(_ a: Character, _ b: Character) -> Bool {
            i + 1 < n && chars[i + 1] == b && c == a
        }

        switch c {
        case "\n": tokens.append(.newline); i += 1; continue
        case "(": tokens.append(.lParen); i += 1; continue
        case ")": tokens.append(.rParen); i += 1; continue
        case "[": tokens.append(.lBrack); i += 1; continue
        case "]": tokens.append(.rBrack); i += 1; continue
        case "{": tokens.append(.lBrace); i += 1; continue
        case "}": tokens.append(.rBrace); i += 1; continue
        case ",": tokens.append(.comma); i += 1; continue
        case ":": tokens.append(.colon); i += 1; continue
        case "=":
            if twoChar("=", "=") { tokens.append(.eqEq); i += 2 } else { tokens.append(.equals); i += 1 }
            continue
        case "!":
            if twoChar("!", "=") { tokens.append(.notEq); i += 2 } else { tokens.append(.not); i += 1 }
            continue
        case ">":
            if twoChar(">", "=") { tokens.append(.greaterEq); i += 2 } else { tokens.append(.greater); i += 1 }
            continue
        case "<":
            if twoChar("<", "=") { tokens.append(.lessEq); i += 2 } else { tokens.append(.less); i += 1 }
            continue
        case "&":
            tokens.append(.and); i += (twoChar("&", "&") ? 2 : 1); continue
        case "|":
            tokens.append(.or); i += (twoChar("|", "|") ? 2 : 1); continue
        case ".": tokens.append(.dot); i += 1; continue
        case "?": tokens.append(.question); i += 1; continue
        case "+": tokens.append(.plus); i += 1; continue
        case "*": tokens.append(.star); i += 1; continue
        case "/": tokens.append(.slash); i += 1; continue
        case "%": tokens.append(.percent); i += 1; continue
        default: break
        }

        // Double-quoted string.
        if c == "\"" {
            let start = i
            i += 1
            var isClosed = false
            while i < n {
                if chars[i] == "\\" { i += 2 }
                else if chars[i] == "\"" { i += 1; isClosed = true; break }
                else { i += 1 }
            }
            let raw = String(chars[start..<min(i, n)])
            // Strip the quotes; if unterminated the lexer still yields a token
            // (implicit closing handles the rest).
            var body = raw
            if body.hasPrefix("\"") { body.removeFirst() }
            if isClosed && body.hasSuffix("\"") { body.removeLast() }
            tokens.append(.str(unescapeJSONString(body)))
            continue
        }

        // Single-quoted string: only \' \\ \n \t; others pass the char through.
        if c == "'" {
            i += 1
            var result = ""
            while i < n {
                if chars[i] == "\\" {
                    i += 1
                    if i < n {
                        let e = chars[i]
                        switch e {
                        case "'": result.append("'")
                        case "\\": result.append("\\")
                        case "n": result.append("\n")
                        case "t": result.append("\t")
                        default: result.append(e)
                        }
                        i += 1
                    }
                } else if chars[i] == "'" {
                    i += 1
                    break
                } else {
                    result.append(chars[i])
                    i += 1
                }
            }
            tokens.append(.str(result))
            continue
        }

        // Minus: negative number literal or operator.
        if c == "-" {
            let prev = tokens.last
            let afterValue: Bool = {
                guard let p = prev else { return false }
                switch p {
                case .num, .str, .ident, .type, .rParen, .rBrack, .true, .false, .null, .stateVar, .builtinCall:
                    return true
                default:
                    return false
                }
            }()
            if !afterValue && i + 1 < n && chars[i + 1] >= "0" && chars[i + 1] <= "9" {
                // Fall through to number parsing.
            } else {
                tokens.append(.minus); i += 1; continue
            }
        }

        // Number literal.
        let isDigit = c >= "0" && c <= "9"
        let isNegDigit = c == "-" && i + 1 < n && chars[i + 1] >= "0" && chars[i + 1] <= "9"
        if isDigit || isNegDigit {
            let start = i
            if chars[i] == "-" { i += 1 }
            while i < n && chars[i] >= "0" && chars[i] <= "9" { i += 1 }
            if i < n && chars[i] == "." && i + 1 < n && chars[i + 1] >= "0" && chars[i + 1] <= "9" {
                i += 1
                while i < n && chars[i] >= "0" && chars[i] <= "9" { i += 1 }
            }
            if i < n && (chars[i] == "e" || chars[i] == "E") {
                i += 1
                if i < n && (chars[i] == "+" || chars[i] == "-") { i += 1 }
                while i < n && chars[i] >= "0" && chars[i] <= "9" { i += 1 }
            }
            let text = String(chars[start..<i])
            tokens.append(.num(Double(text) ?? 0))
            continue
        }

        // State variable: $identifier
        if c == "$" && i + 1 < n && isAlpha(chars[i + 1]) {
            let start = i
            i += 1
            while i < n && isAlphaNum(chars[i]) { i += 1 }
            tokens.append(.stateVar(String(chars[start..<i])))
            continue
        }

        // Keyword or identifier.
        if isAlpha(c) {
            let start = i
            while i < n && isAlphaNum(chars[i]) { i += 1 }
            let word = String(chars[start..<i])
            switch word {
            case "true": tokens.append(.true)
            case "false": tokens.append(.false)
            case "null": tokens.append(.null)
            default:
                tokens.append((c >= "A" && c <= "Z") ? .type(word) : .ident(word))
            }
            continue
        }

        // Builtin call: @identifier
        if c == "@" && i + 1 < n && isAlpha(chars[i + 1]) {
            i += 1
            let start = i
            while i < n && isAlphaNum(chars[i]) { i += 1 }
            tokens.append(.builtinCall(String(chars[start..<i])))
            continue
        }

        // Any other character is skipped. Lexing never fails.
        i += 1
    }

    tokens.append(.eof)
    return tokens
}

// MARK: - Preprocessing (spec §1.2)

func skipStringChars(_ chars: [Character], _ i: Int) -> Int {
    if chars[i] != "\"" { return i }
    var j = i + 1
    while j < chars.count {
        let c = chars[j]
        if c == "\\" { j += 2 }
        else if c == "\"" { return j + 1 }
        else { j += 1 }
    }
    return j
}

/// Extract code from markdown fences; without fences return input as-is.
/// String-context-aware: ``` inside double-quoted strings does not open/close.
public func stripFences(_ input: String) -> String {
    let chars = Array(input)
    let n = chars.count
    var blocks: [String] = []
    var i = 0

    func isFence(at k: Int) -> Bool {
        k + 2 < n && chars[k] == "`" && chars[k + 1] == "`" && chars[k + 2] == "`"
    }

    while i < n {
        var fenceStart = -1
        while i < n {
            let next = skipStringChars(chars, i)
            if next > i { i = next; continue }
            if isFence(at: i) { fenceStart = i; break }
            i += 1
        }
        if fenceStart == -1 { break }

        // Skip language tag until newline.
        var j = fenceStart + 3
        while j < n && chars[j] != "\n" { j += 1 }
        if j >= n {
            // No newline after opening fence (streaming).
            var rest = String(chars[(fenceStart + 3)...])
            if let nl = rest.firstIndex(of: "\n") {
                rest = String(rest[rest.index(after: nl)...])
            } else {
                rest = ""
            }
            blocks.append(rest)
            i = n
            break
        }
        j += 1

        var closePos = -1
        var k = j
        while k < n {
            let next = skipStringChars(chars, k)
            if next > k { k = next; continue }
            if isFence(at: k) { closePos = k; break }
            k += 1
        }
        if closePos != -1 {
            blocks.append(String(chars[j..<closePos]))
            i = closePos + 3
        } else {
            blocks.append(String(chars[j...]))
            i = n
        }
    }

    if !blocks.isEmpty { return blocks.joined(separator: "\n") }

    // Fallback: input starts with ``` but wasn't matched.
    if input.hasPrefix("```") {
        var j = input.startIndex
        var count = 0
        while j < input.endIndex && count < 3 && input[j] == "`" { j = input.index(after: j); count += 1 }
        while j < input.endIndex && input[j] != "\n" { j = input.index(after: j) }
        let start = j < input.endIndex ? input.index(after: j) : j
        let body = String(input[start...])
        if let r = body.range(of: "```", options: .backwards) {
            return String(body[..<r.lowerBound])
        }
        return body
    }

    return input
}

/// Strip // and # line comments outside of strings.
func stripComments(_ input: String) -> String {
    var inStr: Character? = nil
    let lines = input.components(separatedBy: "\n")
    let out = lines.map { line -> String in
        let cs = Array(line)
        var k = 0
        while k < cs.count {
            let c = cs[k]
            if let q = inStr {
                if c == "\\" && k + 1 < cs.count { k += 2; continue }
                if c == q { inStr = nil }
                k += 1
                continue
            }
            if c == "\"" || c == "'" { inStr = c; k += 1; continue }
            if c == "/" && k + 1 < cs.count && cs[k + 1] == "/" {
                return String(cs[..<k]).trimmingCharacters(in: .init(charactersIn: " \t"))
            }
            if c == "#" {
                return String(cs[..<k]).trimmingCharacters(in: .init(charactersIn: " \t"))
            }
            k += 1
        }
        return line
    }
    return out.joined(separator: "\n")
}

/// Clean LLM response: strip fences, comments, whitespace.
public func preprocess(_ input: String) -> String {
    stripComments(stripFences(input.trimmingCharacters(in: .whitespacesAndNewlines)))
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

// MARK: - autoClose (spec §4 rule 2)

/// Close unclosed strings and brackets so partial/streaming input parses.
/// Returns the closed text and whether it was incomplete.
public func autoClose(_ input: String) -> (text: String, wasIncomplete: Bool) {
    var stack: [Character] = []
    var inStr: Character? = nil
    var esc = false
    let chars = Array(input)

    for c in chars {
        if esc { esc = false; continue }
        if c == "\\" && inStr != nil { esc = true; continue }
        if let q = inStr {
            if c == q { inStr = nil }
            continue
        }
        if c == "\"" || c == "'" { inStr = c; continue }
        if c == "(" || c == "[" || c == "{" { stack.append(c) }
        else if c == ")" && stack.last == "(" { stack.removeLast() }
        else if c == "]" && stack.last == "[" { stack.removeLast() }
        else if c == "}" && stack.last == "{" { stack.removeLast() }
        // A closing bracket that does not match is skipped, stack untouched.
    }

    let wasIncomplete = inStr != nil || !stack.isEmpty
    if !wasIncomplete { return (input, false) }

    var out = input
    if let q = inStr {
        if esc { out += "\\" }
        out.append(q)
    }
    for open in stack.reversed() {
        out.append(open == "(" ? ")" : open == "[" ? "]" : "}")
    }
    return (out, true)
}

// MARK: - Statement splitting (spec §1.4)

public struct RawStatement {
    public var id: String
    public var isStateVar: Bool
    public var tokens: [Token]
}

/// Split a flat token stream into `identifier = expression` statements.
/// Newlines end a statement only at bracket depth 0, with ternary continuation.
public func splitStatements(_ tokens: [Token]) -> [RawStatement] {
    var stmts: [RawStatement] = []
    var pos = 0

    func isNewlineOrEOF(_ t: Token) -> Bool {
        t == .newline || t == .eof
    }

    while pos < tokens.count {
        while pos < tokens.count && tokens[pos] == .newline { pos += 1 }
        if pos >= tokens.count || tokens[pos] == .eof { break }

        let tok = tokens[pos]
        let id: String
        let isState: Bool
        switch tok {
        case .ident(let s), .type(let s): id = s; isState = false
        case .stateVar(let s): id = s; isState = true
        default:
            // Invalid line: skip to end of line.
            while pos < tokens.count && !isNewlineOrEOF(tokens[pos]) { pos += 1 }
            continue
        }
        pos += 1

        guard pos < tokens.count && tokens[pos] == .equals else {
            while pos < tokens.count && !isNewlineOrEOF(tokens[pos]) { pos += 1 }
            continue
        }
        pos += 1

        var expr: [Token] = []
        var depth = 0
        var ternaryDepth = 0
        while pos < tokens.count && tokens[pos] != .eof {
            let tt = tokens[pos]
            if tt == .newline && depth <= 0 && ternaryDepth <= 0 {
                var peek = pos + 1
                while peek < tokens.count && tokens[peek] == .newline { peek += 1 }
                let nextT: Token = peek < tokens.count ? tokens[peek] : .eof
                if nextT == .question || (nextT == .colon && ternaryDepth > 0) {
                    pos += 1
                    continue
                }
                break
            }
            if tt == .newline { pos += 1; continue }
            switch tt {
            case .lParen, .lBrack, .lBrace: depth += 1
            case .rParen, .rBrack, .rBrace: if depth > 0 { depth -= 1 }
            case .question: if depth == 0 { ternaryDepth += 1 }
            case .colon: if depth == 0 && ternaryDepth > 0 { ternaryDepth -= 1 }
            default: break
            }
            expr.append(tokens[pos])
            pos += 1
        }

        if !expr.isEmpty {
            stmts.append(RawStatement(id: id, isStateVar: isState, tokens: expr))
        }
    }

    return stmts
}

// MARK: - Statement source splitting (for mergeStatements)

/// Split source text into raw statement strings, tracking bracket depth and
/// strings. Mirrors splitStatementSource in merge.ts (no ternary continuation).
public func splitStatementTexts(_ input: String) -> [String] {
    var stmts: [String] = []
    var depth = 0
    var inStr: Character? = nil
    var esc = false
    let chars = Array(input)
    var start = 0

    var i = 0
    while i < chars.count {
        let c = chars[i]
        if esc { esc = false; i += 1; continue }
        if c == "\\" && inStr != nil { esc = true; i += 1; continue }
        if let q = inStr {
            if c == q { inStr = nil }
            i += 1
            continue
        }
        if c == "\"" || c == "'" { inStr = c; i += 1; continue }
        if c == "(" || c == "[" || c == "{" { depth += 1 }
        else if c == ")" || c == "]" || c == "}" { depth = max(0, depth - 1) }
        else if c == "\n" && depth <= 0 {
            let s = String(chars[start..<i]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !s.isEmpty { stmts.append(s) }
            start = i + 1
        }
        i += 1
    }
    let tail = String(chars[start...]).trimmingCharacters(in: .whitespacesAndNewlines)
    if !tail.isEmpty { stmts.append(tail) }
    return stmts
}
