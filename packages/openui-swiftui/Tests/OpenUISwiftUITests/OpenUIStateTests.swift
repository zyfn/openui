import XCTest
import SwiftUI
import Combine
import OpenUILang
@testable import OpenUISwiftUI

final class OpenUIStateTests: XCTestCase {
    private func schema() -> LibrarySchema {
        LibrarySchema(components: ["Text": [ParamDef(name: "text", required: true)]],
                      callDefs: builtinCallDefs, rootComponent: "Text")
    }

    @MainActor func testResetStartsIndependentStream() {
        let state = OpenUIState(schema: schema())
        state.push("root = Text(\"first\")")
        state.complete()
        XCTAssertEqual(PropValue.string(state.root!, "text"), "first")
        state.reset()
        XCTAssertNil(state.root)
        XCTAssertFalse(state.isComplete)
        XCTAssertTrue(state.errors.isEmpty)
        XCTAssertTrue(state.queryStates.isEmpty)
        state.push("root = Text(\"second\")")
        state.complete()
        XCTAssertEqual(PropValue.string(state.root!, "text"), "second")
    }

    @MainActor func testRegistryKeepsDictionaryLiteralAndLookup() {
        var registry: ComponentRegistry = ["Text": { el, _ in AnyView(Text(PropValue.string(el, "text") ?? "")) }]
        XCTAssertNotNil(registry["Text"])
        registry["Text"] = nil
        XCTAssertNil(registry["Text"])
    }

    struct Provider: ToolProvider {
        func callTool(name: String, arguments: [String: Value]) async throws -> Value {
            .object([ObjectField(key: "label", value: .string("loaded"))])
        }
    }

    @MainActor func testExplicitQueryPublishesAndReevaluatesRoot() {
        let state = OpenUIState(schema: schema(), toolProvider: Provider())
        state.push("data = Query(\"load\", {}, {label: \"default\"})\nroot = Text(data.label)")
        state.runQuery(statementId: "data", tool: "load", args: .object([]))
        XCTAssertEqual(state.queryStates["data"]?.status, .idle)
        state.complete()
        XCTAssertEqual(PropValue.string(state.root!, "text"), "default")
        let settled = expectation(description: "Query settled")
        let subscription = state.$queryStates.sink { states in
            if states["data"]?.status == .success { settled.fulfill() }
        }
        state.runQuery(statementId: "data", tool: "load", args: .object([]))
        wait(for: [settled], timeout: 3)
        XCTAssertEqual(PropValue.string(state.root!, "text"), "loaded")
        withExtendedLifetime(subscription) {}
    }
}
