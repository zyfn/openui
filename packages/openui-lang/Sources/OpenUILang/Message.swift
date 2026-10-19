// OpenUILang — The message protocol (spec/prompt.md §7).
//
// Swift port of message.ts: marker lines around a stored response, e.g.
// `]]>openui:content?library=x`, `]]>openui:context`, `]]>openui:end`.

import Foundation

private let messagePrefix = "]]>openui:"

public struct ParsedMessage: Sendable {
    /// Body of the last `content` section, or the whole text when there is none.
    public var content: String
    /// Body of the `context` section (raw text; the host defines its shape).
    /// nil when absent, or when it belongs to an earlier attempt than the
    /// winning content.
    public var context: String?
    /// The `library` attribute of the winning `content` marker, if any.
    public var library: String?
    /// An `end` line follows the winning `content` section.
    public var complete: Bool
    public init(content: String, context: String? = nil, library: String? = nil, complete: Bool = false) {
        self.content = content
        self.context = context
        self.library = library
        self.complete = complete
    }
}

private struct MessageSection {
    var kind: String?
    var attributes: [String: String]
    var lines: [String]
}

// MARK: - Attribute encoding (same bytes as URLSearchParams)

/// Percent-encode like `encodeURIComponent`, then (as in message.ts) keep the
/// URLSearchParams-compatible form: `!'()~` are escaped, space becomes `+`.
private func messageEncode(_ s: String) -> String {
    var out = ""
    // encodeURIComponent leaves A-Za-z0-9 - _ . ! ~ * ' ( ) unescaped;
    // message.ts then escapes ! ' ( ) ~, leaving - _ . * bare.
    var allowed = CharacterSet.alphanumerics
    allowed.insert(charactersIn: "-_.*")
    for scalar in s.unicodeScalars {
        if scalar == " " { out += "+"; continue }
        if allowed.contains(scalar) { out += String(scalar); continue }
        for byte in String(scalar).utf8 {
            out += String(format: "%%%02X", byte)
        }
    }
    return out
}

private func messageDecode(_ s: String) -> String {
    let plus = s.replacingOccurrences(of: "+", with: " ")
    return plus.removingPercentEncoding ?? s
}

private func readAttributes(_ query: String) -> [String: String] {
    var out: [String: String] = [:]
    for pair in query.split(separator: "&", omittingEmptySubsequences: false) {
        let p = String(pair)
        if let eq = p.firstIndex(of: "=") {
            let key = messageDecode(String(p[..<eq]))
            if !key.isEmpty { out[key] = messageDecode(String(p[p.index(after: eq)...])) }
        } else {
            let key = messageDecode(p)
            if !key.isEmpty { out[key] = "" }
        }
    }
    return out
}

// MARK: - Parsing

private func markerMatch(_ line: String) -> (kind: String, query: String?)? {
    // MARKER = /^\]\]>openui:([a-z]+)(?:\?(.*))?$/ — applied after stripping \r.
    let stripped = line.hasSuffix("\r") ? String(line.dropLast()) : line
    guard stripped.hasPrefix(messagePrefix) else { return nil }
    let rest = stripped.dropFirst(messagePrefix.count)
    let kind: String
    let query: String?
    if let q = rest.firstIndex(of: "?") {
        kind = String(rest[..<q])
        query = String(rest[rest.index(after: q)...])
    } else {
        kind = String(rest)
        query = nil
    }
    guard !kind.isEmpty && kind.allSatisfy({ $0.isLowercase && $0.isLetter }) else { return nil }
    return (kind, query)
}

/// Splits a stored message into its content, context, library, and
/// completeness flag.
///
/// - Last `content` wins; text before the first marker is content only when
///   there is no content marker.
/// - Unknown kinds are stripped with their bodies.
/// - `]]>openui:` mid-line is ordinary text, except a `content` marker
///   (followed by `?`, a line end, or the end of the message), which starts a
///   new line there — a regenerated response is written right after the
///   cut-off text of the failed one, keeping the last content winning.
/// - When `streaming` is true, a trailing line that may be a marker cut
///   mid-stream is held back (not parsed yet).
public func parseMessage(_ text: String, streaming: Bool = true) -> ParsedMessage {
    // RETRY: a regenerated response writes its content line right after the
    // cut-off text, with no newline before it. Start it on its own line so
    // the last content wins.
    var working = insertNewlineBeforeMidlineContentMarker(text)

    // RETRY_CUT: while streaming, hold back a mid-line `]]>openui:con` that
    // may become a content line.
    if streaming, let cutAt = retryCutIndex(working) {
        working = String(working.prefix(cutAt))
    }

    var lines = splitMessageLines(working)
    let last = lines.last ?? ""
    // Hold back a trailing line that may still become a marker with more
    // chunks. A *complete* marker line (e.g. `]]>openui:end`) is parsed
    // normally so `complete` is reported; upstream's looser condition also
    // held those back, which could never report the end of the stream.
    let held = streaming && isPartialMarkerLine(last)
    if held { lines.removeLast() }

    var sections: [MessageSection] = [MessageSection(kind: nil, attributes: [:], lines: [])]
    // The newline (and its `\r`) before a marker is not part of the body.
    func close() {
        if var body = sections.last?.lines, !body.isEmpty {
            body[body.count - 1] = body[body.count - 1].replacingOccurrences(of: "\r$", with: "", options: .regularExpression)
            sections[sections.count - 1].lines = body
        }
    }
    var endAt = -1
    for (i, line) in lines.enumerated() {
        guard let match = markerMatch(line) else {
            sections[sections.count - 1].lines.append(line)
            continue
        }
        close()
        if match.kind == "end" {
            endAt = sections.count - 1
            if i == lines.count - 2 && lines[i + 1].isEmpty { break }
            continue
        }
        sections.append(MessageSection(kind: match.kind, attributes: readAttributes(match.query ?? ""), lines: []))
    }
    if held { close() }

    // Last content wins; text before the first marker is content only when
    // there is none.
    let kinds = sections.map { $0.kind }
    let win = max(0, kinds.lastIndex(of: "content") ?? -1)
    let ctx = kinds.lastIndex(of: "context") ?? -1
    let context: String? = ctx > win ? sections[ctx].lines.joined(separator: "\n") : nil
    let winner = sections[win]
    // Like context, an `end` before the winning content belongs to an earlier attempt.
    let complete = endAt >= win
    return ParsedMessage(
        content: winner.lines.joined(separator: "\n"),
        context: context,
        library: winner.attributes["library"],
        complete: complete
    )
}

/// `([^\n])(?=\]\]>openui:content(?:\?|\r?\n|$))` → `$1\n`.
private func insertNewlineBeforeMidlineContentMarker(_ text: String) -> String {
    guard let regex = try? NSRegularExpression(pattern: #"([^\n])(?=\]\]>openui:content(?:\?|\r?\n|$))"#) else {
        return text
    }
    let range = NSRange(text.startIndex..., in: text)
    return regex.stringByReplacingMatches(in: text, range: range, withTemplate: "$1\n")
}

/// The marker kinds of the protocol.
private let messageKinds = ["content", "context", "end"]

/// True when a trailing line may still become a marker with more chunks: a
/// strict prefix of `]]>openui:`, or `]]>openui:` followed by a partial kind
/// (no `?` yet, and not a complete known kind). A complete marker line —
/// including an unknown kind — is not partial.
private func isPartialMarkerLine(_ line: String) -> Bool {
    if line.isEmpty { return false }
    if line == messagePrefix { return true }
    if messagePrefix.hasPrefix(line) { return true }
    guard line.hasPrefix(messagePrefix) else { return false }
    let rest = line.dropFirst(messagePrefix.count)
    if rest.contains("?") { return false }
    if messageKinds.contains(String(rest)) { return false }
    return rest.allSatisfy { $0.isLowercase && ($0.isLetter || $0 == ":") }
}

/// Split text into lines on LF by substring search. `"\r\n"` is a single
/// grapheme cluster in Swift, so Character-based splitting (and
/// `components(separatedBy:)`) misses the LF inside it; substring search
/// finds it. Lines keep a trailing `\r`, which marker/close handling strips.
private func splitMessageLines(_ text: String) -> [String] {
    var lines: [String] = []
    var rest = text[...]
    while let r = rest.range(of: "\n") {
        lines.append(String(rest[..<r.lowerBound]))
        rest = rest[r.upperBound...]
    }
    lines.append(String(rest))
    return lines
}

/// `[^\n](\]\]>[a-z:]*)$`: index just after the char before a trailing
/// partial marker, when it could still become `]]>openui:content`.
private func retryCutIndex(_ text: String) -> Int? {
    guard let regex = try? NSRegularExpression(pattern: #"[^\n](\]\]>[a-z:]*)$"#) else { return nil }
    let range = NSRange(text.startIndex..., in: text)
    guard let match = regex.firstMatch(in: text, range: range),
          match.numberOfRanges > 1 else { return nil }
    let capture = match.range(at: 1)
    guard capture.location != NSNotFound,
          let swiftRange = Range(capture, in: text) else { return nil }
    let partial = String(text[swiftRange])
    guard messagePrefix.appending("content").hasPrefix(partial) else { return nil }
    // Upstream: text.slice(0, cut.index + 1) — keep through the char before `]]>`.
    let utf16Cut = match.range.location + 1
    guard let cutIndex = text.utf16.index(text.utf16.startIndex, offsetBy: utf16Cut, limitedBy: text.utf16.endIndex),
          let cut = String.Index(cutIndex, within: text) else { return nil }
    return text.distance(from: text.startIndex, to: cut)
}

/// Writes a stored message with its marker lines.
public func buildMessage(content: String, context: String?, library: String?, complete: Bool) -> String {
    var query = ""
    if let library = library {
        query = "?\(messageEncode("library"))=\(messageEncode(library))"
    }
    var out = "\(messagePrefix)content\(query)\n\(content)"
    if let context = context {
        out += "\n\(messagePrefix)context\n\(context)"
    }
    return complete ? "\(out)\n\(messagePrefix)end" : out
}
