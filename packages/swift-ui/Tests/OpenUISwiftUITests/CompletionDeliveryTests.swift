import Combine
import XCTest
import OpenUILang
@testable import OpenUISwiftUI

final class CompletionDeliveryTests: XCTestCase {
  @MainActor func testDuplicateFinalDeliveryAndEmptyChunksNeverClearTheRenderedRoot() throws {
    let library = try OpenUIStandardComponents.library()
    let state = OpenUIState(schema: library.library.toSchema())
    let source = "root=Stack([TextContent(\"Visible prefix\"),Image(\"Photo\",\"https://example.com/image.png\")])"
    state.push(source)
    let revision = state.presentationRevision
    let mediaGeneration = state.mediaCache.generation
    var emptyFrames = 0
    let subscription = state.$root.sink { if $0 == nil { emptyFrames += 1 } }
    state.complete()
    state.push("")
    state.setSource(source)
    state.complete()
    state.setSource(source)
    XCTAssertEqual(emptyFrames, 0)
    XCTAssertEqual(state.presentationRevision, revision)
    XCTAssertEqual(state.mediaCache.generation, mediaGeneration)
    XCTAssertTrue(state.isComplete)
    withExtendedLifetime(subscription) {}
    state.setSource("root=TextContent(\"Different message\")")
    XCTAssertGreaterThan(state.presentationRevision, revision, "Actual replacements still reset the presentation")
  }
  @MainActor func testSameFinalSnapshotPreservesUserFields() throws {
    let library = try OpenUIStandardComponents.library()
    let state = OpenUIState(schema: library.library.toSchema())
    let source = "root=Form(\"prefs\",Buttons([Button(\"Submit\")]),[FormControl(\"Name\",Input(\"name\"))])"
    state.setSource(source)
    state.setFieldValue(form: "prefs", name: "name", value: .string("Edited"), componentType: "Input")
    let snapshot = state.snapshotState()
    state.setSource(source)
    state.push("")
    XCTAssertEqual(state.snapshotState(), snapshot)
  }
}
