import Combine
import OpenUILang
import XCTest
@testable import OpenUISwiftUI

final class StreamingReplayTests: XCTestCase {
  @MainActor func testRepeatedInFlightBufferDoesNotParsePublishOrAdvanceIdentity() throws {
    let library = try OpenUIStandardComponents.library()
    let state = OpenUIState(schema: library.library.toSchema())
    let source = "root=Stack([TextContent(\"正在接收中文内容\")])"
    var parses = 0
    state.onParseResult = { _ in parses += 1 }
    state.setSource(source, streaming: true)
    state.setFieldValue(form: "draft", name: "name", value: .string("User edit"))
    let root = try XCTUnwrap(state.root)
    let fields = state.snapshotState()
    let sourceRevision = state.sourceRevision
    let presentationRevision = state.presentationRevision
    let mediaGeneration = state.mediaCache.generation
    var publications = 0
    let subscription = state.objectWillChange.sink { publications += 1 }
    defer { subscription.cancel() }

    for _ in 0..<100 { state.setSource(source, streaming: true) }

    XCTAssertEqual(parses, 1)
    XCTAssertEqual(publications, 0)
    XCTAssertTrue(state.root === root)
    XCTAssertEqual(state.snapshotState(), fields)
    XCTAssertEqual(state.sourceRevision, sourceRevision)
    XCTAssertEqual(state.presentationRevision, presentationRevision)
    XCTAssertEqual(state.mediaCache.generation, mediaGeneration)
    XCTAssertFalse(state.isComplete)
    XCTAssertFalse(state.isInterrupted)
  }

  @MainActor func testSameBytesStillCompleteExactlyOnce() throws {
    let library = try OpenUIStandardComponents.library()
    let state = OpenUIState(schema: library.library.toSchema())
    let source = "root=Stack([TextContent(\"Complete this stream\")])"
    var parses = 0
    state.onParseResult = { _ in parses += 1 }
    state.setSource(source, streaming: true)
    XCTAssertFalse(state.canExecuteActions)
    state.setSource(source)
    XCTAssertTrue(state.isComplete)
    XCTAssertTrue(state.canExecuteActions)
    XCTAssertEqual(parses, 2)
    state.setSource(source)
    state.complete()
    XCTAssertEqual(parses, 2)
  }

  @MainActor func testInitialEmptyStreamingSnapshotIsAcceptedBeforeDuplicatesAreSkipped() throws {
    let library = try OpenUIStandardComponents.library()
    let state = OpenUIState(schema: library.library.toSchema())
    var parses = 0
    state.onParseResult = { _ in parses += 1 }
    state.setSource("", streaming: true)
    state.setSource("", streaming: true)
    XCTAssertEqual(parses, 1)
    state.setSource("")
    XCTAssertEqual(parses, 2)
    XCTAssertTrue(state.isComplete)
  }

  @MainActor func testInterruptedAndCompletedStreamsCanExplicitlyRestart() throws {
    let library = try OpenUIStandardComponents.library()
    let source = "root=Stack([TextContent(\"Resume me\")])"
    for finishNormally in [false, true] {
      let state = OpenUIState(schema: library.library.toSchema())
      state.setSource(source, streaming: true)
      if finishNormally { state.complete() } else { state.interrupt() }
      let revision = state.presentationRevision
      var parses = 0
      state.onParseResult = { _ in parses += 1 }
      state.setSource(source, streaming: true)
      XCTAssertEqual(parses, 1)
      XCTAssertFalse(state.isComplete)
      XCTAssertFalse(state.isInterrupted)
      XCTAssertGreaterThan(state.presentationRevision, revision)
      state.setSource(source, streaming: true)
      XCTAssertEqual(parses, 1)
    }
  }

  @MainActor func testInterruptedSnapshotCanBeExplicitlyFinalized() throws {
    let library = try OpenUIStandardComponents.library()
    let state = OpenUIState(schema: library.library.toSchema())
    let source = "root=Stack([TextContent(\"Resume as final\")])"
    state.setSource(source, streaming: true)
    state.interrupt()
    var parses = 0
    state.onParseResult = { _ in parses += 1 }
    state.setSource(source)
    XCTAssertEqual(parses, 1)
    XCTAssertTrue(state.isComplete)
    XCTAssertFalse(state.isInterrupted)
    XCTAssertTrue(state.canExecuteActions)
  }

  @MainActor func testGrowingAndSameLengthChangedBuffersAreNotSkipped() throws {
    let library = try OpenUIStandardComponents.library()
    let state = OpenUIState(schema: library.library.toSchema())
    var parses = 0
    state.onParseResult = { _ in parses += 1 }
    state.setSource("root=Stack([TextContent(\"A", streaming: true)
    state.setSource("root=Stack([TextContent(\"AB\")])", streaming: true)
    state.setSource("root=Stack([TextContent(\"AC\")])", streaming: true)
    XCTAssertEqual(parses, 3)
    let root = try XCTUnwrap(state.root)
    let text = try XCTUnwrap(PropValue.children(root).first)
    XCTAssertEqual(PropValue.string(text, "text"), "AC")
  }


  @MainActor func testFullBufferAppendUsesSameDocumentEpochAndRetainsDraft() throws {
    let library = try OpenUIStandardComponents.library()
    let state = OpenUIState(schema: library.library.toSchema())
    let initial = "root=Stack([TextContent(\"First\")"
    state.setSource(initial, streaming: true)
    let generation = state.sourceRevision
    let presentation = state.presentationRevision
    state.setFieldValue(form: "draft", name: "note", value: .string("editing"))
    let extended = initial + ",TextContent(\"Second\")])"
    state.setSource(extended, streaming: true)
    XCTAssertEqual(state.sourceRevision, generation)
    XCTAssertEqual(state.presentationRevision, presentation)
    XCTAssertEqual(state.fieldValue(form: "draft", name: "note"), .string("editing"))
    state.setSource(extended)
    XCTAssertTrue(state.isComplete)
    XCTAssertEqual(state.sourceRevision, generation)
    let root = try XCTUnwrap(state.root)
    XCTAssertEqual(PropValue.children(root).count, 2)
  }

  @MainActor func testFullBufferReplacementStillCreatesNewPresentation() throws {
    let library = try OpenUIStandardComponents.library()
    let state = OpenUIState(schema: library.library.toSchema())
    state.setSource("root=TextContent(\"First\")", streaming: true)
    let generation = state.sourceRevision
    let presentation = state.presentationRevision
    state.setSource("root=TextContent(\"Changed\")", streaming: true)
    XCTAssertGreaterThan(state.sourceRevision, generation)
    XCTAssertGreaterThan(state.presentationRevision, presentation)
  }

  @MainActor func testCanonicalStringEqualityDoesNotHideDifferentUTF16Source() throws {
    let library = try OpenUIStandardComponents.library()
    let state = OpenUIState(schema: library.library.toSchema())
    let composed = "root=Stack([TextContent(\"\u{00E9}\")])"
    let decomposed = "root=Stack([TextContent(\"e\u{0301}\")])"
    XCTAssertEqual(composed, decomposed, "Swift String compares canonical equivalence")
    XCTAssertFalse(composed.utf16.elementsEqual(decomposed.utf16))
    var parses = 0
    state.onParseResult = { _ in parses += 1 }
    state.setSource(composed, streaming: true)
    state.setSource(decomposed, streaming: true)
    XCTAssertEqual(parses, 2, "Language literals preserve code units")
    let root = try XCTUnwrap(state.root)
    let text = try XCTUnwrap(PropValue.children(root).first)
    let value = try XCTUnwrap(PropValue.string(text, "text"))
    XCTAssertEqual(Array(value.utf16), Array("e\u{0301}".utf16))
  }
}
