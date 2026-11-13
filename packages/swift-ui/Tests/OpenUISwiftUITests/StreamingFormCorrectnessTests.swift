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
  @MainActor func testInvalidDraftBlocksSubmissionAndCancelsEarlierPendingValue() {
    for invalid in ["", " ", "-", "1e", "invalid", "nan", "inf"] {
      let draft = NativeSliderDraft(), validation = NativeFormValidation()
      var writes: [[Double]] = []
      draft.commit = { writes.append($0) }
      draft.receive([10])
      validation.registerPendingWrite("amount", owner: UUID(), flush: { draft.flush() },
        error: { draft.validationError() })
      draft.edit("20", at: 0)
      draft.edit(invalid, at: 0)
      XCTAssertFalse(validation.validateAll(), invalid)
      XCTAssertEqual(validation.errors["amount"], "Invalid number")
      draft.flush()
      XCTAssertTrue(writes.isEmpty, "An older valid edit must not escape after malformed input")
      draft.edit("25", at: 0)
      XCTAssertTrue(validation.validateAll())
      XCTAssertEqual(writes, [[25]])
      XCTAssertNil(validation.errors["amount"])
    }
  }

  @MainActor func testBoundsAndInvertedRangesAreNotWrittenByTimerOrSubmitFlush() {
    let draft = NativeSliderDraft()
    draft.configuration = NativeSliderConfiguration(minimum: 0, maximum: 100, step: 1, discrete: false)
    var writes: [[Double]] = []
    draft.commit = { writes.append($0) }
    draft.receive([10, 50])
    draft.edit("110", at: 0); draft.flush()
    XCTAssertTrue(writes.isEmpty)
    XCTAssertNotNil(draft.validationError())
    draft.edit("60", at: 0); draft.flush()
    XCTAssertTrue(writes.isEmpty)
    XCTAssertEqual(draft.validationError(), "Min must be less than max")
    draft.edit("20", at: 0); draft.flush()
    XCTAssertEqual(writes, [[20, 50]])
  }

  @MainActor func testDeclarationOrderAndUnmountedFieldsParticipateInValidation() throws {
    let validation = NativeFormValidation()
    let required = parseStructuredRules(try parseJSONPreservingOrder(#"{"required":true}"#))
    validation.setDeclarations([
      ("z-first", .init(rules: required, value: { .string("") })),
      ("a-second", .init(rules: required, value: { .string("") }))
    ])
    XCTAssertFalse(validation.validateAll())
    XCTAssertEqual(validation.firstInvalid, "z-first", "Use source order, not alphabetic ordering")
    let owner = UUID()
    validation.register("z-first", owner: owner, rules: required, value: { .string("") })
    validation.unregister("z-first", owner: owner)
    XCTAssertFalse(validation.validateAll(), "Unmounting a tab must not erase required validation")
    XCTAssertEqual(validation.errors.count, 2)
    validation.setDeclarations([("a-second", .init(rules: [], value: { .string("ready") }))])
    XCTAssertTrue(validation.validateAll())
  }

  @MainActor func testUnmountedDraftStillBlocksItsDeclaredField() {
    let draft = NativeSliderDraft(), validation = NativeFormValidation()
    validation.setDeclarations([("amount", .init(rules: [], value: { .number(10) }))])
    let owner = UUID()
    validation.registerPendingWrite("amount", owner: owner, flush: { draft.flush() },
      error: { draft.validationError() })
    draft.receive([10]); draft.edit("-", at: 0)
    validation.unregisterPendingWrite("amount", owner: owner)
    XCTAssertFalse(validation.validateAll())
    XCTAssertEqual(validation.errors["amount"], "Invalid number")
  }

  @MainActor func testDocumentOwnsOnlyNecessaryEditingRecordsWithoutRetainCycle() throws {
    let library = try OpenUIStandardComponents.library()
    var state: OpenUIState? = OpenUIState(schema: library.library.toSchema())
    state?.setSource("root=TextContent(\"ready\")")
    weak var releasedState = state
    var draft: NativeSliderDraft?
    do {
      let runtime = try XCTUnwrap(state)
      let context = OpenUIComponentContext(element: try XCTUnwrap(runtime.root), registry: library.registry, state: runtime)
      let first: NativeSliderDraft = context.editingRecord(kind: "slider", name: "amount", create: NativeSliderDraft.init)
      first.receive([10]); first.edit("-", at: 0)
      first.commit = context.weakOperation { (_: OpenUIComponentContext, _: [Double]) in }
      let second: NativeSliderDraft = context.editingRecord(kind: "slider", name: "amount", create: NativeSliderDraft.init)
      XCTAssertTrue(first === second)
      XCTAssertEqual(second.text, ["-"])
      draft = first
    }
    state = nil
    XCTAssertNil(releasedState, "Document-owned records must not retain their document through callbacks")
    draft?.flush()
  }

  @MainActor func testReplacementReleasesDraftsButFullBufferCompletionRetainsThem() throws {
    let library = try OpenUIStandardComponents.library()
    let state = OpenUIState(schema: library.library.toSchema())
    state.setSource("root=TextContent(\"A", streaming: true)
    let record = state.editingRecord(kind: "table", form: nil, name: "draft", create: NativeTableEditingState.init)
    let revision = state.sourceRevision
    state.setSource("root=TextContent(\"AB\")", streaming: false)
    XCTAssertEqual(state.sourceRevision, revision, "Final suffix is still the same source epoch")
    let retained: NativeTableEditingState? = state.existingEditingRecord(kind: "table", form: nil, name: "draft")
    XCTAssertTrue(retained === record)
    state.setSource("root=TextContent(\"replacement\")")
    let cleared: NativeTableEditingState? = state.existingEditingRecord(kind: "table", form: nil, name: "draft")
    XCTAssertNil(cleared)
  }

}
