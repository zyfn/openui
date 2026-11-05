import XCTest
@testable import OpenUILang

final class OrderedRenderingTests: XCTestCase {
    private func schema(ordered: Bool = true) -> LibrarySchema {
        let children = ParamDef(name: "children", required: true, schema: .object([
            .init(key: "type", value: .string("array")), .init(key: "items", value: .object([]))
        ]))
        var schema = LibrarySchema(components: [
            "Col": [children], "Row": [children],
            "Text": [ParamDef(name: "text", required: true, schema: .object([.init(key: "type", value: .string("string"))]))]
        ], callDefs: builtinCallDefs, rootComponent: "Col")
        schema.orderedRendering = ordered
        return schema
    }

    private func visible(_ result: ParseResult, schema: LibrarySchema, store: Store) -> EvaluatedElement? {
        store.initialize(defaults: result.stateDeclarations, persisted: [:])
        return Evaluator(context: EvaluationContext(getState: { store.get($0) ?? .null }, resolveRef: { _ in .null }), store: store, schema: schema).evaluateRoot(result)
    }

    private func strings(_ value: Value) -> [String] {
        switch value {
        case .element(let element): return element.props.flatMap { strings($0.1) }
        case .array(let items): return items.flatMap(strings)
        case .string(let text): return [text.displayString]
        default: return []
        }
    }

    func testForwardAndNestedDependenciesCannotBeOvertaken() throws {
        let schema = schema(), parser = createStreamingParser(schema: schema), store = createStore()
        let prefix = "root=Col([Text(\"intro\"),Row([Col([Text(\"nested\"),early]),Text(\"row-tail\")]),Text(\"tail\")])\n"
        let first = try XCTUnwrap(visible(parser.push(prefix), schema: schema, store: store))
        XCTAssertEqual(strings(.element(first)), ["intro", "nested"])
        let end = parser.push("early=Text(\"early\")\n", complete: true)
        let finished = try XCTUnwrap(visible(end, schema: schema, store: store))
        XCTAssertEqual(strings(.element(finished)), ["intro", "nested", "early", "row-tail", "tail"])
        let ordinary = self.schema(ordered: false)
        let full = try XCTUnwrap(visible(createParser(schema: ordinary).parse(prefix + "early=Text(\"early\")\n"), schema: ordinary, store: createStore()))
        XCTAssertEqual(finished, full)
    }

    func testIncompleteEachCallAndPartialInputHoldTheFollowingSibling() throws {
        let schema = schema(), parser = createStreamingParser(schema: schema), store = createStore()
        var result = parser.push("root=Col([Text(\"intro\"),cards,Text(\"tail\")])\ncards=@Each(")
        XCTAssertEqual(strings(.element(try XCTUnwrap(visible(result, schema: schema, store: store)))), ["intro"])
        result = parser.push("records,\"r\",Text(r.name))\nrecords=[{name:\"one\"},")
        let partial = strings(.element(try XCTUnwrap(visible(result, schema: schema, store: store))))
        XCTAssertFalse(partial.contains("tail"))
        result = parser.push("{name:\"two\"}]\n", complete: true)
        XCTAssertEqual(strings(.element(try XCTUnwrap(visible(result, schema: schema, store: store)))), ["intro", "one", "two", "tail"])
    }

    func testLateStateDefaultIsPendingRatherThanAnImplicitFalse() throws {
        let schema = schema(), parser = createStreamingParser(schema: schema), store = createStore()
        let prefix = "root=Col([Text(\"intro\"),$show?Text(\"chosen\"):null,Text(\"tail\")])\n"
        let first = try XCTUnwrap(visible(parser.push(prefix), schema: schema, store: store))
        XCTAssertEqual(strings(.element(first)), ["intro"])
        let last = parser.push("$show=true\n", complete: true)
        XCTAssertEqual(strings(.element(try XCTUnwrap(visible(last, schema: schema, store: store)))), ["intro", "chosen", "tail"])
    }

    func testActualNullInactiveBranchAndEmptyEachDoNotBlock() throws {
        let schema = schema(), parser = createStreamingParser(schema: schema), store = createStore()
        let source = "root=Col([Text(\"intro\"),nothing,false?missing:null,@Each([],\"r\",Text(missing)),Text(\"tail\")])\nnothing=null\n"
        let result = parser.push(source, complete: true)
        XCTAssertEqual(strings(.element(try XCTUnwrap(visible(result, schema: schema, store: store)))), ["intro", "tail"])
    }

    func testPendingNeverMasqueradesAsARealNullOrBusinessObject() {
        let context = EvaluationContext(getState: { _ in .null }, resolveRef: { _ in .null })
        let ordered = Evaluator(context: context, store: createStore(), schema: schema())
        XCTAssertEqual(ordered.evaluate(.ph("later")), .undefined)
        XCTAssertEqual(ordered.evaluate(.null), .null)
        XCTAssertEqual(ordered.evaluate(.obj([])), .object([]))
        let ordinary = Evaluator(context: context, store: createStore(), schema: schema(ordered: false))
        XCTAssertEqual(ordinary.evaluate(.ph("later")), .null)
    }
}
