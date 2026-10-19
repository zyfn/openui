// OpenUILang — Public API.
//
// createParser / createStreamingParser. Mirrors parser.ts.

import Foundation

/// Batch parser. Mirrors the Parser interface from parser.ts.
public final class OUIParser: OUIParserProtocol {
    private let catalog: [String: [ParamDef]]?
    private let callDefs: [String: CallDef]
    private let rootName: String?

    init(catalog: [String: [ParamDef]]?, callDefs: [String: CallDef], rootName: String?) {
        self.catalog = catalog
        self.callDefs = callDefs
        self.rootName = rootName
    }

    /// Parse a complete program in one pass.
    public func parse(_ input: String) -> ParseResult {
        parseProgram(input, catalog: catalog, callDefs: callDefs, rootName: rootName)
    }
}

/// Create a batch parser from a compiled library schema.
/// Pass the schema produced from your library (see Library.swift).
public func createParser(schema: LibrarySchema) -> OUIParserProtocol {
    OUIParser(catalog: schema.components, callDefs: schema.callDefs, rootName: schema.rootComponent)
}

/// Create a streaming parser from a compiled library schema.
public func createStreamingParser(schema: LibrarySchema) -> OUIStreamingParserProtocol {
    OUIStreamingParser(catalog: schema.components, callDefs: schema.callDefs, rootName: schema.rootComponent)
}
