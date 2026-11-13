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


extension StreamingFormCorrectnessTests {
  @MainActor func testTableExternalRefreshRequiresExplicitConflictDecision() {
    func source(_ value: String) -> Value {
      .array([.object([.init(key: "id", value: .string("r")),
        .init(key: "values", value: .array([.string(value)]))])])
    }
    let editing = NativeTableEditingState()
    editing.receive(source("base"), revision: 1)
    editing.draft.write(.string("local"), row: 0, column: 0)
    editing.receive(source("remote"), revision: 1)
    XCTAssertTrue(editing.hasSourceConflict)
    XCTAssertEqual(editing.draft.value(row: 0, column: 0), .string("local"))
    editing.keepLocalEdits()
    XCTAssertFalse(editing.hasSourceConflict)
    editing.receive(source("remote"), revision: 1)
    XCTAssertFalse(editing.hasSourceConflict, "Acknowledged remote version must not recreate the same conflict")
    editing.receive(source("newer remote"), revision: 1)
    XCTAssertTrue(editing.hasSourceConflict)
    editing.useUpdatedSource()
    XCTAssertEqual(editing.draft.value(row: 0, column: 0), .string("newer remote"))
    XCTAssertFalse(editing.draft.hasChanges)
    XCTAssertFalse(editing.hasSourceConflict)
    editing.draft.write(.string("later local"), row: 0, column: 0)
    editing.receive(source("replacement"), revision: 2)
    XCTAssertFalse(editing.hasSourceConflict)
    XCTAssertEqual(editing.draft.value(row: 0, column: 0), .string("replacement"))
  }

  @MainActor func testValidationCanLocateAFieldInsideNestedDisclosureContent() {
    let field = EvaluatedElement(typeName: "Input", props: [("name", .string("amount"))])
    let panel = EvaluatedElement(typeName: "TabItem", props: [
      ("value", .string("details")), ("content", .array([.element(field)]))])
    XCTAssertTrue(NativeFormValidation.containsField("amount", in: .element(panel)))
    XCTAssertFalse(NativeFormValidation.containsField("other", in: .element(panel)))
    XCTAssertFalse(NativeFormValidation.containsField("amount", in: .element(panel), depth: 128))
  }

  @MainActor func testEditingRecordsAreIsolatedByFormAndComponentKind() throws {
    let library = try OpenUIStandardComponents.library()
    let state = OpenUIState(schema: library.library.toSchema())
    state.setSource("root=TextContent(\"Example\")")
    let first = state.editingRecord(kind: "table", form: "first", name: "same", create: NativeTableEditingState.init)
    let second = state.editingRecord(kind: "table", form: "second", name: "same", create: NativeTableEditingState.init)
    XCTAssertFalse(first === second)
    let retained = state.editingRecord(kind: "table", form: "first", name: "same", create: NativeTableEditingState.init)
    XCTAssertTrue(first === retained)
    let other: NativeSliderDraft? = state.existingEditingRecord(kind: "slider", form: "first", name: "same")
    XCTAssertNil(other)
  }
}

extension StreamingFormCorrectnessTests {
  @MainActor func testValidationDoesNotStealFocusUntilAnExplicitSubmitAttempt() throws {
    let validation = NativeFormValidation()
    let rules = parseStructuredRules(try parseJSONPreservingOrder(#"{"required":true}"#))
    validation.register("name", rules: rules, value: { .string("") })
    validation.changed("name", value: .string(""), rules: rules)
    XCTAssertNil(validation.focusRequest)
    XCTAssertFalse(validation.validateAll())
    XCTAssertNil(validation.focusRequest)
    validation.requestInvalidFieldFocus()
    XCTAssertEqual(validation.focusRequest?.name, "name")
    let firstID = validation.focusRequest?.id
    validation.requestInvalidFieldFocus()
    XCTAssertNotEqual(validation.focusRequest?.id, firstID, "Another rejected attempt can focus the same field again")
  }
}


extension StreamingFormCorrectnessTests {
  func testSliderRTLGeometryUsesOneMappingForValuesFillAndHitTesting() {
    for width: CGFloat in [80, 320, 600] {
      let ltr = NativeSliderTrackGeometry(width: width, minimum: -20, maximum: 80, rightToLeft: false)
      let rtl = NativeSliderTrackGeometry(width: width, minimum: -20, maximum: 80, rightToLeft: true)
      for value in stride(from: -20.0, through: 80.0, by: 5) {
        XCTAssertEqual(ltr.x(for: value) + rtl.x(for: value), width, accuracy: 0.0001)
        XCTAssertEqual(ltr.value(at: ltr.x(for: value)), value, accuracy: 0.0001)
        XCTAssertEqual(rtl.value(at: rtl.x(for: value)), value, accuracy: 0.0001)
      }
      let values = [-10.0, 60.0]
      XCTAssertEqual(rtl.nearestIndex(to: rtl.x(for: -10), values: values), 0)
      XCTAssertEqual(rtl.nearestIndex(to: rtl.x(for: 60), values: values), 1)
      let a = ltr.selection(from: values[0], to: values[1])
      let b = rtl.selection(from: values[0], to: values[1])
      XCTAssertEqual(a.lowerBound, width - b.upperBound, accuracy: 0.0001)
      XCTAssertEqual(a.upperBound, width - b.lowerBound, accuracy: 0.0001)
      XCTAssertGreaterThan(b.upperBound - b.lowerBound, 0)
      XCTAssertEqual(rtl.value(at: -100), 80)
      XCTAssertEqual(rtl.value(at: width + 100), -20)
    }
  }

  func testRTLSliderDragProgressesAndSnapsWithoutReorderingStoredRange() {
    let config = NativeSliderConfiguration(minimum: 0, maximum: 100, step: 5, discrete: true)
    let geometry = NativeSliderTrackGeometry(width: 320, minimum: 0, maximum: 100, rightToLeft: true)
    let initial = [20.0, 80.0]
    let index = geometry.nearestIndex(to: geometry.x(for: 20), values: initial)
    XCTAssertEqual(index, 0)
    let leftward = geometry.x(for: 20) - geometry.span * 0.1
    XCTAssertEqual(config.snapped(geometry.value(at: leftward)), 30)
    XCTAssertEqual(initial, [20, 80], "RTL is a coordinate convention, not an array reversal")
  }

  @MainActor func testSliderShowsOneDraftErrorUntilTheWrapperPresentsIt() {
    let config = NativeSliderConfiguration(minimum: 0, maximum: 100, step: 1, discrete: false)
    let draft = NativeSliderDraft(); draft.configuration = config; draft.receive([20, 80])
    draft.edit("", at: 0); draft.edit("invalid", at: 1)
    XCTAssertEqual(draft.inlineValidationError(presentedError: nil, configuration: config), "Invalid number")
    XCTAssertNil(draft.inlineValidationError(presentedError: "Invalid number", configuration: config))
    XCTAssertNil(draft.inlineValidationError(presentedError: "This field is required", configuration: config))
    // Standalone fields have no inherited feedback; invalid edits stay visible.
    XCTAssertNotNil(draft.inlineValidationError(presentedError: nil, configuration: config))
    draft.edit("30", at: 0); draft.edit("70", at: 1); draft.flush()
    XCTAssertNil(draft.inlineValidationError(presentedError: nil, configuration: config))
  }
}
