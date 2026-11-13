import Combine
import OpenUILang
import XCTest
@testable import OpenUISwiftUI

final class AuxiliaryPublicationTests: XCTestCase {
  @MainActor func testPlainTextStreamingDoesNotRepublishEmptyAuxiliaryChannels() throws {
    let state = OpenUIState(schema: textSchema())
    state.push("root=Text(\"A")
    XCTAssertTrue(state.errors.isEmpty)
    var queryPublications = 0, mutationPublications = 0, errorPublications = 0
    var roots = 0, parses = 0
    let subscriptions = [
      state.$queryStates.dropFirst().sink { _ in queryPublications += 1 },
      state.$mutationStates.dropFirst().sink { _ in mutationPublications += 1 },
      state.$errors.dropFirst().sink { _ in errorPublications += 1 },
      state.$root.dropFirst().sink { _ in roots += 1 },
    ]
    defer { subscriptions.forEach { $0.cancel() } }
    state.onParseResult = { _ in parses += 1 }
    for chunk in ["B", "C", "D", "\")\n"] { state.push(chunk) }
    state.complete()
    XCTAssertEqual(parses, 5, "No accepted chunk or completion is dropped")
    XCTAssertEqual(roots, 5, "Content/readiness still reaches the renderer")
    XCTAssertEqual(queryPublications, 0)
    XCTAssertEqual(mutationPublications, 0)
    XCTAssertEqual(errorPublications, 0)
    XCTAssertEqual(PropValue.string(try XCTUnwrap(state.root), "text"), "ABCD")
    XCTAssertTrue(state.canExecuteActions)
  }

  @MainActor func testRemovingQueryPublishesEmptyOnceAndThenStaysQuiet() {
    let state = OpenUIState(schema: textSchema())
    state.setSource("data=Query(\"fixture\",{},\"fallback\")\nroot=Text(data)\n", streaming: true)
    XCTAssertNotNil(state.queryStates["data"])
    var sizes: [Int] = []
    let subscription = state.$queryStates.dropFirst().sink { sizes.append($0.count) }
    defer { subscription.cancel() }
    state.setSource("root=Text(\"plain\")\n", streaming: true)
    state.push("\n")
    XCTAssertEqual(sizes, [0])
    XCTAssertTrue(state.queryStates.isEmpty)
  }

  @MainActor func testRemovingMutationPublishesEmptyOnceAndThenStaysQuiet() {
    let state = OpenUIState(schema: textSchema())
    state.setSource("save=Mutation(\"save\",{})\nroot=Text(\"plain\")\n", streaming: true)
    XCTAssertNotNil(state.mutationStates["save"])
    var sizes: [Int] = []
    let subscription = state.$mutationStates.dropFirst().sink { sizes.append($0.count) }
    defer { subscription.cancel() }
    state.setSource("root=Text(\"plain\")\n", streaming: true)
    state.push("\n")
    XCTAssertEqual(sizes, [0])
    XCTAssertTrue(state.mutationStates.isEmpty)
  }

  @MainActor func testNonemptyQueryAndMutationChannelsKeepTheirPublicationBehavior() {
    let state = OpenUIState(schema: textSchema())
    state.setSource("data=Query(\"load\",{},\"fallback\")\nsave=Mutation(\"save\",{})\nroot=Text(data)\n", streaming: true)
    XCTAssertEqual(state.queryStates.count, 1)
    XCTAssertEqual(state.mutationStates.count, 1)
    var queries = 0, mutations = 0
    let subscriptions = [
      state.$queryStates.dropFirst().sink { _ in queries += 1 },
      state.$mutationStates.dropFirst().sink { _ in mutations += 1 },
    ]
    defer { subscriptions.forEach { $0.cancel() } }
    state.push("\n")
    XCTAssertEqual(queries, 1)
    XCTAssertEqual(mutations, 1)
  }

  @MainActor func testRuntimeErrorPublishesAndClearsWithoutRepeatingAnEmptyErrorList() {
    let state = invalidFunctionState()
    XCTAssertTrue(state.errors.contains { $0.code == .runtimeError })
    var publishedErrorCounts: [Int] = []
    var clearedCallbacks = 0
    let subscription = state.$errors.dropFirst().sink { publishedErrorCounts.append($0.count) }
    defer { subscription.cancel() }
    state.onError = { if $0.isEmpty { clearedCallbacks += 1 } }
    state.setState("$value", value: .number(4))
    XCTAssertGreaterThan(publishedErrorCounts.last ?? 0, 0,
      "Nonempty errors retain their previous delivery behavior")
    state.setState("$value", value: .string("fixed"))
    XCTAssertTrue(state.errors.isEmpty)
    let countAfterClear = publishedErrorCounts.count
    XCTAssertEqual(publishedErrorCounts.last, 0)
    state.setState("$value", value: .string("still valid"))
    XCTAssertEqual(publishedErrorCounts.count, countAfterClear)
    XCTAssertEqual(clearedCallbacks, 1)
  }

  @MainActor func testFieldWriteStillPublishesRootWithoutEmptyAuxiliaryNotifications() throws {
    let state = OpenUIState(schema: textSchema())
    state.setSource("$value=\"before\"\nroot=Text($value)\n")
    var roots = 0, auxiliary = 0
    let subscriptions = [
      state.$root.dropFirst().sink { _ in roots += 1 },
      state.$queryStates.dropFirst().sink { _ in auxiliary += 1 },
      state.$mutationStates.dropFirst().sink { _ in auxiliary += 1 },
      state.$errors.dropFirst().sink { _ in auxiliary += 1 },
    ]
    defer { subscriptions.forEach { $0.cancel() } }
    state.setState("$value", value: .string("after"))
    XCTAssertEqual(roots, 1)
    XCTAssertEqual(auxiliary, 0)
    XCTAssertEqual(PropValue.string(try XCTUnwrap(state.root), "text"), "after")
  }

  @MainActor func testReadinessOnlyCompletionStillPermitsTheConfirmedAction() async throws {
    let library = try OpenUIStandardComponents.library()
    let state = OpenUIState(schema: library.library.toSchema())
    state.push("root=Button(\"Go\",@ToAssistant(\"go\")")
    XCTAssertFalse(state.canExecuteActions)
    var roots = 0, auxiliary = 0
    let subscriptions = [
      state.$root.dropFirst().sink { _ in roots += 1 },
      state.$queryStates.dropFirst().sink { _ in auxiliary += 1 },
      state.$mutationStates.dropFirst().sink { _ in auxiliary += 1 },
      state.$errors.dropFirst().sink { _ in auxiliary += 1 },
    ]
    defer { subscriptions.forEach { $0.cancel() } }
    state.push(")\n")
    state.complete()
    XCTAssertEqual(roots, 2)
    XCTAssertEqual(auxiliary, 0)
    XCTAssertTrue(state.canExecuteActions)
    let root = try XCTUnwrap(state.root)
    let plan = try XCTUnwrap(PropValue.actionPlan(root, "action"))
    let events = await state.perform(plan)
    XCTAssertEqual(events.count, 1)
    XCTAssertEqual(events.first?.type, "continue_conversation")
    XCTAssertEqual(auxiliary, 0)
  }

  @MainActor func testResetStillPublishesItsLifecycleTransition() {
    let state = OpenUIState(schema: textSchema())
    state.setSource("root=Text(\"plain\")\n")
    var queries = 0, mutations = 0, errors = 0
    let subscriptions = [
      state.$queryStates.dropFirst().sink { _ in queries += 1 },
      state.$mutationStates.dropFirst().sink { _ in mutations += 1 },
      state.$errors.dropFirst().sink { _ in errors += 1 },
    ]
    defer { subscriptions.forEach { $0.cancel() } }
    state.reset()
    XCTAssertEqual(queries, 1)
    XCTAssertEqual(mutations, 1)
    XCTAssertEqual(errors, 1)
    XCTAssertNil(state.root)
    XCTAssertFalse(state.isComplete)
  }

  private func textSchema() -> LibrarySchema {
    LibrarySchema(components: ["Text": [ParamDef(name: "text", required: true)]],
      callDefs: builtinCallDefs, rootComponent: "Text")
  }

  @MainActor private func invalidFunctionState() -> OpenUIState {
    let text = ParamDef(name: "text", required: true,
      schema: .object([.init(key: "type", value: .string("string"))]))
    var schema = textSchema()
    schema.callDefs["Upper"] = CallDef(kind: .function, params: [text])
    let state = OpenUIState(schema: schema,
      functions: ["Upper": CustomFunction(params: [text], fn: { $0["text"] ?? .null })])
    state.setSource("$value=3\nroot=Text(@Upper($value))\n")
    return state
  }
}
