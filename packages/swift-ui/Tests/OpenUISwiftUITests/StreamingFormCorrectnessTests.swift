import OpenUILang
import XCTest
@testable import OpenUISwiftUI

final class StreamingFormCorrectnessTests: XCTestCase {
  @MainActor func testSliderCommitsFiniteEditsBeforeImmediateFormSubmission() {
    let draft = NativeSliderDraft()
    var commits: [[Double]] = []
    draft.commit = { commits.append($0) }
    draft.receive([10])
    draft.edit("12", at: 0)
    XCTAssertEqual(commits, [[12]], "The Store write must precede the next action")
    XCTAssertEqual(draft.values, [12])
    draft.flush()
    XCTAssertEqual(commits.count, 1, "Disappearance must not duplicate a commit")
  }

  @MainActor func testSliderKeepsInvalidTextLocalWithoutPublishingIt() {
    let draft = NativeSliderDraft()
    var commits: [[Double]] = []
    draft.commit = { commits.append($0) }
    draft.receive([10])
    draft.edit("invalid", at: 0)
    XCTAssertEqual(draft.text, ["invalid"])
    XCTAssertEqual(draft.values, [10])
    XCTAssertTrue(commits.isEmpty)
    draft.select(20, at: 0)
    XCTAssertEqual(commits, [[20]])
  }

  @MainActor func testTableDraftSurvivesStreamingUpdatesButNotDocumentReplacement() {
    let editing = NativeTableEditingState()
    func source(_ value: String) -> Value {
      .array([.object([
        ObjectField(key: "id", value: .string("row")),
        ObjectField(key: "values", value: .array([.string(value)]))
      ])])
    }
    editing.receive(source("initial"), revision: 3)
    editing.draft.write(.string("unsaved"), row: 0, column: 0)
    editing.receive(source("new streamed source"), revision: 3)
    XCTAssertEqual(editing.draft.value(row: 0, column: 0), .string("unsaved"))
    editing.receive(source("replacement"), revision: 4)
    XCTAssertEqual(editing.draft.value(row: 0, column: 0), .string("replacement"))
  }
}
