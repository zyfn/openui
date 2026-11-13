import OpenUILang
import XCTest
@testable import OpenUISwiftUI

final class LiveElementIndexTests: XCTestCase {
  func testIndexSeparatesTypesAndDeclarations() {
    var index = NativeLiveElementIndex()
    let first = element("TextContent", "first")
    let second = element("TextContent", "second")
    let otherType = element("Button", "first")
    [first, second, otherType].forEach { index.insert($0) }
    assertIdentities(index.candidates(for: first), [first])
    assertIdentities(index.candidates(for: second), [second])
    assertIdentities(index.candidates(for: otherType), [otherType])
    XCTAssertTrue(index.candidates(for: element("TextContent", "missing")).isEmpty)
  }

  func testOptionalStatementIDDoesNotCollapseNilIntoEmpty() {
    var index = NativeLiveElementIndex()
    let unnamed = element("TextContent", nil)
    let empty = element("TextContent", "")
    index.insert(unnamed); index.insert(empty)
    assertIdentities(index.candidates(for: unnamed), [unnamed])
    assertIdentities(index.candidates(for: empty), [empty])
  }

  func testStructuredKeyCannotCollideThroughSeparatorText() {
    var index = NativeLiveElementIndex()
    let first = element("Text|a", "b")
    let second = element("Text", "a|b")
    index.insert(first); index.insert(second)
    assertIdentities(index.candidates(for: first), [first])
    assertIdentities(index.candidates(for: second), [second])
  }

  func testDuplicateCandidatesRemainOrderedForTheExistingAmbiguityCheck() {
    var index = NativeLiveElementIndex()
    let pending = element("Button", "shared", complete: false)
    let ready = element("Button", "shared", complete: true)
    let differentProps = EvaluatedElement(typeName: "Button", props: [("label", .string("different"))],
      statementId: "shared")
    [pending, ready, differentProps].forEach { index.insert($0) }
    // The index must not choose the first or last candidate, nor discard one
    // because its props/readiness differ. OpenUIState owns that decision.
    assertIdentities(index.candidates(for: pending), [pending, ready, differentProps])
  }

  func testUnnamedInlineNodesRetainAllCandidates() {
    var index = NativeLiveElementIndex()
    let first = element("TextContent", nil)
    let second = element("TextContent", nil)
    index.insert(first); index.insert(second)
    assertIdentities(index.candidates(for: first), [first, second])
  }

  func testKeyUsesTheSameSwiftStringEqualityAsThePreviousFilter() {
    var index = NativeLiveElementIndex()
    let composed = element("TextContent", "\u{00E9}")
    let decomposed = element("TextContent", "e\u{0301}")
    XCTAssertEqual(composed.statementId, decomposed.statementId)
    index.insert(composed); index.insert(decomposed)
    assertIdentities(index.candidates(for: composed), [composed, decomposed])
  }

  func testClearReleasesCandidatesEvenWhenKeepingDictionaryCapacity() {
    var index = NativeLiveElementIndex()
    weak var retained: EvaluatedElement?
    do {
      let value = element("TextContent", "old")
      retained = value
      index.insert(value)
    }
    XCTAssertNotNil(retained)
    index.removeAll(keepingCapacity: true)
    XCTAssertNil(retained)
    XCTAssertTrue(index.candidates(for: element("TextContent", "old")).isEmpty)
    let replacement = element("TextContent", "old")
    index.insert(replacement)
    assertIdentities(index.candidates(for: replacement), [replacement])
  }

  func testOneThousandDistinctDeclarationsDoNotShareATypeOnlyBucket() {
    var index = NativeLiveElementIndex()
    let values = (0..<1000).map { element("TextContent", "item\($0)") }
    values.forEach { index.insert($0) }
    for value in values {
      let expected = values.filter {
        $0.typeName == value.typeName && $0.statementId == value.statementId
      }
      assertIdentities(index.candidates(for: value), expected)
      XCTAssertEqual(index.candidates(for: value).count, 1)
    }
    // Candidate counts are an algorithmic check, not a frame-time benchmark.
  }

  @MainActor func testLiveResolutionDoesNotBorrowAnEqualSiblingWithAnotherDeclaration() throws {
    let library = try OpenUIStandardComponents.library()
    let state = OpenUIState(schema: library.library.toSchema())
    state.setSource("root=Stack([first,second])\nfirst=TextContent(\"Same\")\nsecond=TextContent(\"Same\")\n")
    let children = PropValue.children(try XCTUnwrap(state.root))
    XCTAssertEqual(children.count, 2)
    guard children.count == 2 else { return }
    XCTAssertNotEqual(children[0].statementId, children[1].statementId)
    for child in children {
      let stale = EvaluatedElement(typeName: child.typeName, props: child.props,
        partial: child.partial, statementId: child.statementId, isSourceComplete: false)
      XCTAssertTrue(state.liveElement(matching: stale) === child)
    }
  }

  @MainActor func testLiveResolutionStillRejectsChangedPropsAndClearsPreviousSearchCache() throws {
    let library = try OpenUIStandardComponents.library()
    let state = OpenUIState(schema: library.library.toSchema())
    state.setSource("root=Stack([first])\nfirst=TextContent(\"Before\")\n")
    let first = try XCTUnwrap(PropValue.children(try XCTUnwrap(state.root)).first)
    let stale = EvaluatedElement(typeName: first.typeName, props: first.props,
      partial: first.partial, statementId: first.statementId, isSourceComplete: false)
    XCTAssertTrue(state.liveElement(matching: stale) === first)
    state.setSource("root=Stack([first])\nfirst=TextContent(\"After\")\n")
    XCTAssertTrue(state.liveElement(matching: stale) === stale,
      "A previous match must not survive rebuilding the live index")
  }

  private func element(_ type: String, _ statement: String?, complete: Bool = true) -> EvaluatedElement {
    EvaluatedElement(typeName: type, statementId: statement, isSourceComplete: complete)
  }

  private func assertIdentities(_ actual: [EvaluatedElement], _ expected: [EvaluatedElement],
                                file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertEqual(actual.map(ObjectIdentifier.init), expected.map(ObjectIdentifier.init), file: file, line: line)
  }
}
