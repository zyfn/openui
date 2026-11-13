import OpenUILang
import XCTest
@testable import OpenUISwiftUI

final class StreamingFormCorrectnessTests: XCTestCase {
  @MainActor func testSliderFlushCommitsLatestFiniteEditBeforeImmediateFormSubmission() {
    let draft = NativeSliderDraft()
    var commits: [[Double]] = []
    draft.commit = { commits.append($0) }
    draft.receive([10])
    draft.edit("12", at: 0)
    XCTAssertTrue(commits.isEmpty, "Rapid edits remain coalesced until an action or timer flush")
    XCTAssertEqual(draft.values, [12])
    draft.flush()
    XCTAssertEqual(commits, [[12]], "The Store write must precede the next action")
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
    draft.flush()
    XCTAssertEqual(commits, [[20]])
  }

  @MainActor func testValidationFlushesPendingSliderEditsBeforeReadingFields() {
    let draft = NativeSliderDraft()
    let validation = NativeFormValidation()
    var committed: [Double] = []
    draft.commit = { values in committed = values }
    draft.receive([10])
    let owner = UUID()
    validation.registerPendingWrite("amount", owner: owner) { [weak draft] in draft?.flush() }
    draft.edit("21", at: 0)
    XCTAssertTrue(committed.isEmpty)
    XCTAssertTrue(validation.validateAll())
    XCTAssertEqual(committed, [21])
    validation.validateAll()
    XCTAssertEqual(committed, [21], "Repeated validation cannot re-dispatch a flushed edit")
    validation.unregisterPendingWrite("amount", owner: owner)
  }

  @MainActor func testDisappearingOldFieldCannotUnregisterReplacement() {
    let validation = NativeFormValidation()
    let oldOwner = UUID(), currentOwner = UUID()
    var oldCalls = 0, currentCalls = 0
    validation.registerPendingWrite("amount", owner: oldOwner) { oldCalls += 1 }
    validation.registerPendingWrite("amount", owner: currentOwner) { currentCalls += 1 }
    validation.unregisterPendingWrite("amount", owner: oldOwner)
    validation.flushPendingWrites()
    XCTAssertEqual(oldCalls, 0)
    XCTAssertEqual(currentCalls, 1)
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
