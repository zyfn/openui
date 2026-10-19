// OpenUILang — Edit/merge for openui-lang.
//
// Swift port of parser_merge.ts: merge an existing program with a patch
// (partial update). Patch statements override existing ones by name;
// `name = null` in a patch deletes the statement; new names are appended;
// statements unreachable from the root are garbage-collected.

import Foundation

// MARK: - Statement parsing

private struct ParsedStatement {
    var id: String
    var ast: ASTNode
    var raw: String
}

private func parseStatements(_ input: String) -> [ParsedStatement] {
    let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return [] }
    var result: [ParsedStatement] = []
    for raw in splitStatementTexts(trimmed) {
        guard let stmt = splitStatements(tokenize(raw)).first else { continue }
        result.append(ParsedStatement(id: stmt.id, ast: parseExpression(stmt.tokens), raw: raw))
    }
    return result
}

// MARK: - Reference collection & GC

/// Recursively collect all Ref / RuntimeRef names from an AST node.
private func collectRefs(_ node: ASTNode, out: inout Set<String>) {
    walkAST(node) { current in
        switch current {
        case .ref(let n): out.insert(n)
        case .runtimeRef(let n, _): out.insert(n)
        default: break
        }
    }
}

/// Remove statements unreachable from `rootId` (garbage collection).
/// Walks the AST graph from the root, collecting all referenced statement
/// IDs. `$state` variables are always kept (bound at runtime, not via Ref).
private func gcUnreachable(
    order: inout [String],
    merged: inout [String: String],
    asts: inout [String: ASTNode],
    rootId: String
) {
    guard asts[rootId] != nil else { return } // no root → can't GC

    // BFS from root to find all reachable statements.
    var reachable: Set<String> = [rootId]
    var queue: [String] = [rootId]
    while !queue.isEmpty {
        let id = queue.removeLast()
        guard let ast = asts[id] else { continue }
        var refs = Set<String>()
        collectRefs(ast, out: &refs)
        for ref in refs where !reachable.contains(ref) && asts[ref] != nil {
            reachable.insert(ref)
            queue.append(ref)
        }
    }

    // Keep $state variables — they're bound at runtime, not via Ref nodes.
    for id in order where id.hasPrefix("$") {
        reachable.insert(id)
    }

    // Remove unreachable statements.
    for i in stride(from: order.count - 1, through: 0, by: -1) {
        if !reachable.contains(order[i]) {
            merged.removeValue(forKey: order[i])
            order.remove(at: i)
        }
    }
}

// MARK: - Public API

/// Merge an existing program with a patch (partial update).
/// Patch statements override existing ones by name. `name = null` in a patch
/// deletes the statement. Unreachable statements are garbage-collected from
/// `rootId`. Returns the merged program as a string.
public func mergeStatements(_ existing: String, _ patch: String, rootId: String = "root") -> String {
    // Normalize CRLF: the lexer and statement splitter match the LF
    // grapheme, but Swift merges CRLF into one grapheme (JS UTF-16 units
    // don't), so CRLF input would not split into statements.
    let existingText = existing.replacingOccurrences(of: "\r\n", with: "\n")
    let patchText = stripFences(patch.replacingOccurrences(of: "\r\n", with: "\n"))
    let existingStmts = parseStatements(existingText)
    let patchStmts = parseStatements(patchText)

    if existingStmts.isEmpty {
        return patchStmts.map { $0.raw }.joined(separator: "\n")
    }
    if patchStmts.isEmpty { return existing }

    // Merge: patch statements override existing by name.
    var merged: [String: String] = [:]
    var asts: [String: ASTNode] = [:]
    var order: [String] = []

    for stmt in existingStmts {
        merged[stmt.id] = stmt.raw
        asts[stmt.id] = stmt.ast
        order.append(stmt.id)
    }

    for stmt in patchStmts {
        if case .null = stmt.ast {
            // `name = null` in a patch means "delete this statement".
            merged.removeValue(forKey: stmt.id)
            asts.removeValue(forKey: stmt.id)
            if let idx = order.firstIndex(of: stmt.id) { order.remove(at: idx) }
            continue
        }
        if merged[stmt.id] == nil {
            order.append(stmt.id)
        }
        merged[stmt.id] = stmt.raw
        asts[stmt.id] = stmt.ast
    }

    // GC: remove statements unreachable from root.
    gcUnreachable(order: &order, merged: &merged, asts: &asts, rootId: rootId)

    return order.compactMap { merged[$0] }.joined(separator: "\n")
}
