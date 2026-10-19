// OpenUILang — Streaming parser.
//
// Ports createStreamParser from parser.ts: incremental parsing with a
// completed-statement cache, implicit closing of the pending tail, and
// reconciliation on prefix change (spec §4).

import Foundation

/// Streaming parser. Mirrors the StreamParser interface from parser.ts.
public final class OUIStreamingParser: OUIStreamingParserProtocol {
    private let catalog: [String: [ParamDef]]?
    private let callDefs: [String: CallDef]
    private let rootName: String?

    /// Raw accumulated input (kept for set() diffing).
    private var buf: String = ""
    /// Preprocessed view of buf. The completed-statement scan runs over this.
    private var cleaned: [Character] = []
    /// Watermark: character offset into `cleaned` that is already completed.
    private var completedEnd: Int = 0
    private var completedStmts: [(String, Statement)] = []
    private var completedCount: Int = 0

    public init(catalog: [String: [ParamDef]]?, callDefs: [String: CallDef], rootName: String?) {
        self.catalog = catalog
        self.callDefs = callDefs
        self.rootName = rootName
    }

    @discardableResult
    public func push(_ chunk: String, complete: Bool = false) -> ParseResult {
        buf += chunk
        return currentResult(complete: complete)
    }

    @discardableResult
    public func set(_ fullText: String, complete: Bool = false) -> ParseResult {
        if fullText.count < buf.count || !fullText.hasPrefix(buf) {
            reset()
        }
        let delta = String(fullText.dropFirst(buf.count))
        if !delta.isEmpty { buf += delta }
        return currentResult(complete: complete)
    }

    public func getResult(complete: Bool = false) -> ParseResult {
        currentResult(complete: complete)
    }

    private func reset() {
        buf = ""
        cleaned = []
        completedEnd = 0
        completedStmts = []
        completedCount = 0
    }

    private func addStmt(_ text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return }
        for s in splitStatements(tokenize(t)) {
            let expr = parseExpression(s.tokens)
            let stmt = classifyStatement(s, expr)
            setOrdered(&completedStmts, key: s.id, value: stmt)
            completedCount += 1
        }
    }

    /// Recompute `cleaned` from `buf`. If the completed prefix is no longer a
    /// prefix of the new cleaned text (e.g. a fence opener arrived), the
    /// watermark + cache are stale: reset and re-scan (spec §4 rule 4).
    private func refreshCleaned() {
        let next = Array(preprocess(stripMessageMarkers(buf)))
        let completedPrefix = Array(cleaned[0..<min(completedEnd, cleaned.count)])
        var isPrefix = true
        if completedPrefix.count > next.count {
            isPrefix = false
        } else {
            for (a, b) in zip(completedPrefix, next) {
                if a != b { isPrefix = false; break }
            }
        }
        if !isPrefix {
            completedEnd = 0
            completedStmts = []
            completedCount = 0
        }
        cleaned = next
        completedEnd = min(completedEnd, cleaned.count)
    }

    /// Scan for newly completed statements. Returns the offset of the pending tail.
    private func scanNewCompleted() -> Int {
        var depth = 0
        var ternaryDepth = 0
        var inStr: Character? = nil
        var esc = false
        var stmtStart = completedEnd
        var i = completedEnd

        while i < cleaned.count {
            let c = cleaned[i]
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
            else if c == "?" && depth == 0 { ternaryDepth += 1 }
            else if c == ":" && depth == 0 && ternaryDepth > 0 { ternaryDepth -= 1 }
            else if c == "\n" && depth <= 0 && ternaryDepth <= 0 {
                // Look ahead past whitespace: ternary continuation?
                var peek = i + 1
                while peek < cleaned.count &&
                        (cleaned[peek] == " " || cleaned[peek] == "\t" ||
                         cleaned[peek] == "\r" || cleaned[peek] == "\n") {
                    peek += 1
                }
                if peek < cleaned.count &&
                    (cleaned[peek] == "?" || (cleaned[peek] == ":" && ternaryDepth > 0)) {
                    i += 1
                    continue
                }
                let t = String(cleaned[stmtStart..<i]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !t.isEmpty { addStmt(t) }
                stmtStart = i + 1
                completedEnd = stmtStart
            }
            i += 1
        }
        return stmtStart
    }

    private func currentResult(complete: Bool) -> ParseResult {
        refreshCleaned()
        let pendingStart = scanNewCompleted()
        let pendingText = String(cleaned[pendingStart...]).trimmingCharacters(in: .whitespacesAndNewlines)

        if pendingText.isEmpty {
            if completedCount == 0 { return emptyParseResult() }
            return buildResult(stmtMap: completedStmts, typedStmts: completedStmts.map { $0.1 },
                               wasIncomplete: false, stmtCount: completedCount,
                               catalog: catalog, callDefs: callDefs, rootName: rootName)
        }

        let (closed, wasIncomplete) = autoClose(pendingText)
        let stmts = splitStatements(tokenize(closed))

        if stmts.isEmpty {
            if completedCount == 0 { return emptyParseResult(incomplete: wasIncomplete) }
            return buildResult(stmtMap: completedStmts, typedStmts: completedStmts.map { $0.1 },
                               wasIncomplete: wasIncomplete, stmtCount: completedCount,
                               catalog: catalog, callDefs: callDefs, rootName: rootName)
        }

        // Overlay pending statements. New IDs render progressively; existing IDs
        // are replaced only when the pending text no longer needs auto-closing
        // (spec §4 rule 3).
        var allStmts = completedStmts
        var pendingIds = Set<String>()
        for s in stmts {
            if completedStmts.contains(where: { $0.0 == s.id }) && wasIncomplete { continue }
            let expr = parseExpression(s.tokens)
            let stmt = classifyStatement(s, expr)
            setOrdered(&allStmts, key: s.id, value: stmt)
            pendingIds.insert(s.id)
        }

        // A `$name` ending the raw text may still be growing: skip it unless the
        // stream is complete or the name already appears in full in pending text.
        var partialRef: PartialRef? = nil
        if !complete {
            if let range = buf.range(of: #"\$\w+$"#, options: .regularExpression),
               pendingText.hasSuffix(String(buf[range])) {
                let tail = String(buf[range])
                let before = String(pendingText.dropLast(tail.count))
                let escaped = NSRegularExpression.escapedPattern(for: tail)
                let foundFull = (try? NSRegularExpression(pattern: escaped + "(?!\\w)"))
                    .flatMap { $0.firstMatch(in: before, range: NSRange(before.startIndex..., in: before)) } != nil
                if !foundFull {
                    partialRef = PartialRef(name: tail, stmts: pendingIds)
                }
            }
        }

        let allTyped = allStmts.map { $0.1 }
        return buildResult(stmtMap: allStmts, typedStmts: allTyped,
                           wasIncomplete: wasIncomplete,
                           stmtCount: completedCount + stmts.count,
                           catalog: catalog, callDefs: callDefs, rootName: rootName,
                           partialRef: partialRef)
    }
}
