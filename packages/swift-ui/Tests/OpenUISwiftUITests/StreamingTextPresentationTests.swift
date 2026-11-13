import XCTest
@testable import OpenUISwiftUI

final class StreamingTextPresentationTests: XCTestCase {
  @MainActor func testRapidAppendCoalescesWithoutLosingFinalSuffix() async {
    let buffer = NativeStreamingTextBuffer()
    buffer.receive("A", streaming: true)
    for index in 1...50 { buffer.receive("A" + String(repeating: "b", count: index), streaming: true) }
    XCTAssertEqual(buffer.displayed, "A")
    try? await Task.sleep(nanoseconds: 120_000_000)
    XCTAssertEqual(buffer.displayed, "A" + String(repeating: "b", count: 50))
  }

  @MainActor func testCompletionShowsExactFinalTextImmediately() {
    let buffer = NativeStreamingTextBuffer()
    buffer.receive("initial", streaming: true)
    buffer.receive("initial growing", streaming: true)
    buffer.receive("initial growing final", streaming: false)
    XCTAssertEqual(buffer.displayed, "initial growing final")
    buffer.flush()
    XCTAssertEqual(buffer.displayed, "initial growing final")
  }

  @MainActor func testReplacementIsNeverHeldBehindPendingAppend() {
    let buffer = NativeStreamingTextBuffer()
    buffer.receive("old", streaming: true)
    buffer.receive("old append", streaming: true)
    buffer.receive("new document", streaming: true)
    XCTAssertEqual(buffer.displayed, "new document")
    buffer.flush()
    XCTAssertEqual(buffer.displayed, "new document")
  }

  @MainActor func testRevertingToVisiblePrefixCancelsObsoleteSuffix() {
    let buffer = NativeStreamingTextBuffer()
    buffer.receive("A", streaming: true)
    buffer.receive("AB", streaming: true)
    buffer.receive("A", streaming: true)
    buffer.flush()
    XCTAssertEqual(buffer.displayed, "A")
  }

  @MainActor func testUTF16DistinctReplacementsAreNotSkipped() {
    let buffer = NativeStreamingTextBuffer()
    buffer.receive("\u{00E9}", streaming: true)
    buffer.receive("e\u{0301}", streaming: true)
    XCTAssertEqual(Array((buffer.displayed ?? "").utf16), Array("e\u{0301}".utf16))
  }

  @MainActor func testCancelStopsPendingPresentationWork() async {
    let buffer = NativeStreamingTextBuffer()
    buffer.receive("A", streaming: true)
    buffer.receive("AB", streaming: true)
    buffer.cancel()
    try? await Task.sleep(nanoseconds: 120_000_000)
    XCTAssertEqual(buffer.displayed, "A")
    buffer.receive("ABC", streaming: false)
    XCTAssertEqual(buffer.displayed, "ABC")
  }
}
