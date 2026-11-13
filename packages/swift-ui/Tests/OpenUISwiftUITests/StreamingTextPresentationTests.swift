import Combine
import XCTest
import OpenUILang
@testable import OpenUISwiftUI

final class StreamingTextPresentationTests: XCTestCase {
  @MainActor private final class ManualScheduler {
    var deliveries: [@MainActor () -> Void] = []
    var cancelled = Set<Int>()

    func schedule(_ delivery: @escaping @MainActor () -> Void) -> NativeStreamingTextBuffer.Cancellation {
      let index = deliveries.count
      deliveries.append(delivery)
      return { [weak self] in self?.cancelled.insert(index) }
    }

    func fire(_ index: Int, evenIfCancelled: Bool = false) {
      guard deliveries.indices.contains(index), evenIfCancelled || !cancelled.contains(index) else { return }
      deliveries[index]()
    }
  }

  @MainActor func testRapidAppendSchedulesOneDeliveryAndKeepsLatestSuffix() {
    let clock = ManualScheduler()
    let buffer = NativeStreamingTextBuffer(schedule: clock.schedule)
    buffer.receive("A", streaming: true)
    for count in 1...50 { buffer.receive("A" + String(repeating: "b", count: count), streaming: true) }
    XCTAssertEqual(buffer.displayed, "A")
    XCTAssertEqual(clock.deliveries.count, 1)
    clock.fire(0)
    XCTAssertEqual(buffer.displayed, "A" + String(repeating: "b", count: 50))
  }

  @MainActor func testDuplicatePendingSnapshotDoesNotExtendItsDeliveryWindow() {
    let clock = ManualScheduler()
    let buffer = NativeStreamingTextBuffer(schedule: clock.schedule)
    buffer.receive("A", streaming: true)
    for _ in 0..<100 { buffer.receive("AB", streaming: true) }
    XCTAssertEqual(clock.deliveries.count, 1)
    XCTAssertTrue(clock.cancelled.isEmpty)
    clock.fire(0)
    XCTAssertEqual(buffer.displayed, "AB")
  }

  @MainActor func testCompletionShowsExactFinalTextAndRejectsLateDelivery() {
    let clock = ManualScheduler()
    let buffer = NativeStreamingTextBuffer(schedule: clock.schedule)
    buffer.receive("initial", streaming: true)
    buffer.receive("initial growing", streaming: true)
    buffer.receive("initial growing final", streaming: false)
    XCTAssertEqual(buffer.displayed, "initial growing final")
    clock.fire(0, evenIfCancelled: true)
    XCTAssertEqual(buffer.displayed, "initial growing final")
  }

  @MainActor func testCorrectionOfPendingSuffixIsImmediate() {
    let clock = ManualScheduler()
    let buffer = NativeStreamingTextBuffer(schedule: clock.schedule)
    buffer.receive("A", streaming: true)
    buffer.receive("AB", streaming: true)
    // Both extend the displayed "A", but AC does not extend the accepted AB.
    XCTAssertEqual(buffer.text(for: "AC", streaming: true), "AC")
    buffer.receive("AC", streaming: true)
    XCTAssertEqual(buffer.displayed, "AC")
    clock.fire(0, evenIfCancelled: true)
    XCTAssertEqual(buffer.displayed, "AC")
  }

  @MainActor func testRevertingToVisiblePrefixCancelsObsoleteSuffix() {
    let clock = ManualScheduler()
    let buffer = NativeStreamingTextBuffer(schedule: clock.schedule)
    buffer.receive("A", streaming: true)
    buffer.receive("AB", streaming: true)
    buffer.receive("A", streaming: true)
    clock.fire(0, evenIfCancelled: true)
    XCTAssertEqual(buffer.displayed, "A")
  }

  @MainActor func testOldDeliveryCannotFlushANewerScheduledGeneration() {
    let clock = ManualScheduler()
    let buffer = NativeStreamingTextBuffer(schedule: clock.schedule)
    buffer.receive("old", streaming: true)
    buffer.receive("old append", streaming: true)
    buffer.receive("new", streaming: true)
    buffer.receive("new append", streaming: true)
    XCTAssertEqual(clock.deliveries.count, 2)
    clock.fire(0, evenIfCancelled: true)
    XCTAssertEqual(buffer.displayed, "new")
    clock.fire(1)
    XCTAssertEqual(buffer.displayed, "new append")
  }

  @MainActor func testCancelAndReappearWithSameInputRestartsPendingDelivery() {
    let clock = ManualScheduler()
    let buffer = NativeStreamingTextBuffer(schedule: clock.schedule)
    buffer.receive("A", streaming: true)
    buffer.receive("AB", streaming: true)
    buffer.cancel()
    clock.fire(0, evenIfCancelled: true)
    XCTAssertEqual(buffer.displayed, "A")
    buffer.receive("AB", streaming: true)
    XCTAssertEqual(clock.deliveries.count, 2)
    clock.fire(1)
    XCTAssertEqual(buffer.displayed, "AB")
  }

  @MainActor func testUTF16DistinctReplacementIsNotSkipped() {
    let buffer = NativeStreamingTextBuffer()
    buffer.receive("\u{00E9}", streaming: true)
    buffer.receive("e\u{0301}", streaming: true)
    XCTAssertEqual(Array((buffer.displayed ?? "").utf16), Array("e\u{0301}".utf16))
  }

  @MainActor func testReadingPresentationDoesNotScheduleOrPublishWork() {
    let clock = ManualScheduler()
    let buffer = NativeStreamingTextBuffer(schedule: clock.schedule)
    buffer.receive("A", streaming: true)
    for _ in 0..<100 {
      XCTAssertEqual(buffer.text(for: "AB", streaming: true), "A")
      XCTAssertEqual(buffer.text(for: "replaced", streaming: true), "replaced")
      XCTAssertEqual(buffer.text(for: "AB", streaming: false), "AB")
    }
    XCTAssertEqual(buffer.displayed, "A")
    XCTAssertTrue(clock.deliveries.isEmpty)
  }

  @MainActor func testSynchronousSchedulerDoesNotRetainAnObsoleteHandle() {
    var deliveries = 0
    let buffer = NativeStreamingTextBuffer(schedule: { deliver in
      deliveries += 1
      deliver()
      return { }
    })
    buffer.receive("A", streaming: true)
    buffer.receive("AB", streaming: true)
    buffer.receive("ABC", streaming: true)
    XCTAssertEqual(deliveries, 2)
    XCTAssertEqual(buffer.displayed, "ABC")
  }

  @MainActor func testPendingDeliveryDoesNotRetainTheBuffer() {
    let clock = ManualScheduler()
    weak var weakBuffer: NativeStreamingTextBuffer?
    do {
      let buffer = NativeStreamingTextBuffer(schedule: clock.schedule)
      weakBuffer = buffer
      buffer.receive("A", streaming: true)
      buffer.receive("AB", streaming: true)
    }
    XCTAssertNil(weakBuffer)
    clock.fire(0)
  }

  @MainActor func testRepeatedFlushDoesNotRepublishAnUnchangedValue() {
    let clock = ManualScheduler()
    let buffer = NativeStreamingTextBuffer(schedule: clock.schedule)
    var values: [String] = []
    let subscription = buffer.$displayed.compactMap { $0 }.sink { values.append($0) }
    defer { subscription.cancel() }
    buffer.receive("A", streaming: true)
    buffer.receive("AB", streaming: true)
    buffer.flush()
    buffer.flush()
    buffer.receive("AB", streaming: false)
    clock.fire(0, evenIfCancelled: true)
    XCTAssertEqual(values, ["A", "AB"])
  }

  @MainActor func testDefaultSchedulerEventuallyDeliversWithoutAssumingAnExactWakeTime() async {
    let buffer = NativeStreamingTextBuffer()
    let delivered = expectation(description: "Latest presentation was actually published")
    let subscription = buffer.$displayed.sink { value in
      if value == "AB" { delivered.fulfill() }
    }
    defer { subscription.cancel(); buffer.cancel() }
    buffer.receive("A", streaming: true)
    buffer.receive("AB", streaming: true)
    await fulfillment(of: [delivered], timeout: 3)
    XCTAssertEqual(buffer.displayed, "AB")
  }
}

extension StreamingTextPresentationTests {
  @MainActor func testCanonicalMarkdownPreparationCoalescesWithoutStarvingContinuousInput() async throws {
    let document = NativeMarkdownDocument()
    func request(_ text: String) -> NativeRichTextRequest {
      .init(source: OpenUIString(text), mode: .textContent, sources: [], fontSize: 16, color: "#202124")
    }
    document.receive(request("**Start**"))
    var final = ""
    for index in 1...100 {
      final = "**Start** " + String(repeating: "中文内容 ", count: index)
      document.receive(request(final))
    }
    let finalSource = OpenUIString(final)
    let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
      document.currentSource == finalSource
    }, object: nil)
    await fulfillment(of: [ready], timeout: 5)
    XCTAssertEqual(document.currentSource, finalSource)
    XCTAssertLessThanOrEqual(document.preparationCount, 2,
      "One active snapshot and one latest pending snapshot, not 100 queued jobs")
    XCTAssertTrue(document.content(for: request(final)).renderPlainText().contains("中文内容"))
    document.cancel()
  }

  @MainActor func testRepeatedMarkdownSizingReadsReuseTheSameParsedFallback() {
    let document = NativeMarkdownDocument()
    let request = NativeRichTextRequest(source: "**Readable** before mount", mode: .markdown,
      sources: [], fontSize: 16, color: "#202124")
    for _ in 0..<100 { _ = document.content(for: request) }
    XCTAssertEqual(document.fallbackParseCount, 1)
    XCTAssertEqual(document.preparationCount, 0, "A read must not launch background preparation")
    XCTAssertNil(document.currentSource)
  }

  @MainActor func testMarkdownCorrectionRejectsEarlierPreparedResult() async {
    let document = NativeMarkdownDocument()
    func request(_ source: String) -> NativeRichTextRequest {
      .init(source: OpenUIString(source), mode: .textContent, sources: [], fontSize: 16, color: "#202124")
    }
    document.receive(request("Old content"))
    document.receive(request("Replacement"))
    let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
      document.currentSource == "Replacement"
    }, object: nil)
    await fulfillment(of: [ready], timeout: 5)
    XCTAssertEqual(document.content(for: request("Replacement")).renderPlainText(), "Replacement")
    document.cancel()
    document.receive(request("After remount"))
    let remounted = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
      document.currentSource == "After remount"
    }, object: nil)
    await fulfillment(of: [remounted], timeout: 5)
    XCTAssertEqual(document.currentSource, "After remount")
    document.cancel()
  }
}
