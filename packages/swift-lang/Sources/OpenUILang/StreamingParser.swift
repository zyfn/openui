import Foundation
import JavaScriptCore

/// Native transport and budgets around the shared parser. No second lexer or
/// parser is introduced. A failed append preserves the last successful prefix.
final class CoreStreamParser: StreamParser {
    private let core = SharedCore.shared
    private let parser: JSValue
    private var source = ""
    private var input = ""
    private var envelope = NativeSourceEnvelope()
    private var budgetChecked = false
    private var blocked = false
    private var lastGood: ParseResult?

    init(schema: LibrarySchema) {
        parser = SharedCore.shared.sync {
            SharedCore.shared.core("createStreamingParser", [
                SharedCore.shared.json(SharedCore.shared.schemaJSON(schema)), schema.rootComponent as Any,
            ])
        }
    }
    @discardableResult func push(_ chunk: String, complete: Bool = false) -> ParseResult {
        core.sync {
            guard !blocked else { return limitedParseResult(preserving: lastGood) }
            guard envelope.append(chunk) else { blocked = true; return limitedParseResult(preserving: lastGood) }
            source += chunk
            input = source
            if !chunk.isEmpty { budgetChecked = false }
            guard withinBudget else { return limitedParseResult(preserving: lastGood) }
            let result = core.parseResult(parser.invokeMethod("push", withArguments: [chunk, complete]))
            lastGood = result
            return result
        }
    }
    @discardableResult func set(_ fullText: String, complete: Bool = false) -> ParseResult {
        core.sync {
            let extends = fullText.utf16.starts(with: input.utf16)
            if !extends { lastGood = nil }
            blocked = false; budgetChecked = false; envelope = NativeSourceEnvelope()
            guard OpenUIRuntimeBudget.acceptsSource(fullText) else {
                blocked = true; return limitedParseResult(preserving: lastGood)
            }
            input = fullText
            source = stripMessageMarkers(fullText)
            guard envelope.append(source), withinBudget else {
                blocked = true; return limitedParseResult(preserving: lastGood)
            }
            let result = core.parseResult(parser.invokeMethod("set", withArguments: [source, complete]))
            lastGood = result
            return result
        }
    }
    func getResult(complete: Bool = false) -> ParseResult {
        core.sync {
            guard withinBudget else { return limitedParseResult(preserving: lastGood) }
            let result = core.parseResult(parser.invokeMethod("getResult", withArguments: [complete]))
            lastGood = result
            return result
        }
    }
    private var withinBudget: Bool {
        if blocked { return false }
        if budgetChecked { return true }
        blocked = !envelope.triviallySafe && expressionSourceExceedsLimits(source)
        budgetChecked = !blocked
        return !blocked
    }
}
