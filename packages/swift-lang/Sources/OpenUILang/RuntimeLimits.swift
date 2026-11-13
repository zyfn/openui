// Bounded recursive work: model output must not exhaust the native call stack.
import Foundation
import JavaScriptCore

/// Native safety budget, not a new language parameter or an upstream parser.
public enum OpenUIRuntimeBudget {
    public static let maximumSourceUTF16 = 1_048_576
    public static func acceptsSource(_ source: String) -> Bool {
        var count = 0
        for _ in source.utf16 {
            count += 1
            if count > maximumSourceUTF16 { return false }
        }
        return true
    }
}

/// Raw counts are conservative upper bounds: quoted/comment punctuation can
/// cause an extra guard pass, never bypass a real expression limit.
struct NativeSourceEnvelope {
    private(set) var units = 0
    private var openings = 0
    private var operators = 0
    var triviallySafe: Bool { units <= 100_000 && openings <= 128 && operators <= 256 }
    mutating func append(_ source: String) -> Bool {
        for unit in source.utf16 {
            units += 1
            if units > OpenUIRuntimeBudget.maximumSourceUTF16 { return false }
            switch unit {
            case 40, 91, 123: openings += 1
            case 46, 43, 45, 42, 47, 37, 33, 38, 124, 61, 62, 60, 63: operators += 1
            default: break
            }
        }
        return true
    }
}

/// Keep token inspection inside the same realm as the shared lexer. Previously
/// every string token was decoded to Swift merely to count its discriminant.
private enum NativeExpressionGuard {
    static let check = SharedCore.shared.sync {
        let core = SharedCore.shared
        func kinds(_ tokens: [Token]) -> String {
            tokens.map { String(core.token($0).forProperty("t").toInt32()) }.joined(separator: ",")
        }
        let openings = kinds([.lParen, .lBrack, .lBrace])
        let closings = kinds([.rParen, .rBrack, .rBrace])
        let operators = kinds([.plus, .minus, .star, .slash, .percent, .not, .and, .or,
            .eqEq, .notEq, .greater, .less, .greaterEq, .lessEq, .question, .dot])
        return core.context.evaluateScript("""
          (function(statements) {
            const opens = new Set([\(openings)]), closes = new Set([\(closings)]), ops = new Set([\(operators)]);
            if (statements.length > 4096) return true;
            let total = 0;
            for (const statement of statements) {
              let depth = 0, operators = 0;
              for (const token of statement.tokens) {
                if (++total > 100000) return true;
                if (opens.has(token.t)) depth++;
                else if (closes.has(token.t)) depth = Math.max(0, depth - 1);
                else if (ops.has(token.t)) operators++;
                if (depth > 128 || operators > 256) return true;
              }
            }
            return false;
          })
          """)!
    }
}

func sourceExceedsLimits(_ source: String) -> Bool {
    var envelope = NativeSourceEnvelope()
    guard envelope.append(source) else { return true }
    if envelope.triviallySafe { return false }
    return expressionSourceExceedsLimits(source)
}

func expressionSourceExceedsLimits(_ source: String) -> Bool {
    let core = SharedCore.shared
    return core.sync {
        let cleaned = core.call("preprocess", [source])
        let tokens = core.core("tokenize", [cleaned])
        let statements = core.core("split", [tokens])
        let result = NativeExpressionGuard.check.call(withArguments: [statements])
        if core.context.exception != nil { core.context.exception = nil; return true }
        return result?.toBool() ?? true
    }
}

func expressionExceedsLimits(_ tokens: [Token]) -> Bool {
    var depth = 0, operators = 0
    for token in tokens {
        switch token {
        case .lParen, .lBrack, .lBrace: depth += 1
        case .rParen, .rBrack, .rBrace: depth = max(0, depth - 1)
        case .plus, .minus, .star, .slash, .percent, .not, .and, .or, .eqEq, .notEq, .greater, .less, .greaterEq, .lessEq, .question, .dot:
            operators += 1
        default: break
        }
        if depth > 128 || operators > 256 { return true }
    }
    return false
}

func limitedParseResult(preserving previous: ParseResult? = nil) -> ParseResult {
    var result = previous ?? emptyParseResult(incomplete: true)
    result.nativeLimitExceeded = true
    result.meta.incomplete = true
    result.queryStatements = []; result.mutationStatements = []
    result.meta.errors = [OpenUIError(source: .parser, code: .parseException,
        message: "Native input budget exceeded (1,048,576 UTF-16 units, 100,000 tokens, 4,096 statements, 128 nesting levels or 256 operators per expression).",
        hint: "The last valid prefix remains readable but is not executable. Replace or reset this document to resume.")]
    return result
}
