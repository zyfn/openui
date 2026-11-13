#if os(macOS)
import AppKit
import Combine
import OpenUILang
import SwiftUI
import XCTest
@testable import OpenUISwiftUI

/// A fixed-width native host exercises fitting without network, Markdown
/// preparation, or client chat-list callbacks. Real client profiling is separate.
final class HostSizingIsolationTests: XCTestCase {
  @MainActor func testRepeatedFittingDoesNotPublishOrReparseStaticContent() throws {
    try checkFitting(replayStreamingBuffer: false)
  }

  @MainActor func testRepeatedStreamingSnapshotAndFittingDoNotRebuildContent() throws {
    try checkFitting(replayStreamingBuffer: true)
  }

  @MainActor private func checkFitting(replayStreamingBuffer: Bool) throws {
    _ = NSApplication.shared
    let mounts = SizingMountLog()
    let standard = try OpenUIStandardComponents.library()
    let definition = try XCTUnwrap(standard.library.components.first { $0.name == "TextContent" })
    let library = try standard.extending(overriding: [OpenUIComponent(definition) { context in
      Text(context.string("text") ?? "")
        .fixedSize(horizontal: false, vertical: true)
        .background(SizingMountMarker(log: mounts))
    }])
    let state = OpenUIState(schema: library.library.toSchema())
    let source = "root=Stack([TextContent(\"Stable prefix\"),TextContent(\"流式内容与尺寸测量保持分离\")])"
    state.setSource(source, streaming: replayStreamingBuffer)
    let hosting = NSHostingView(rootView: OpenUIRenderer(state: state, registry: library.registry).frame(width: 320))
    let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 320, height: 600),
      styleMask: [.borderless], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false
    window.contentView = hosting
    window.setFrameOrigin(NSPoint(x: -10000, y: -10000))
    window.orderFront(nil)
    defer { window.close() }
    func settle() {
      hosting.layoutSubtreeIfNeeded()
      RunLoop.main.run(until: Date().addingTimeInterval(0.1))
      hosting.layoutSubtreeIfNeeded()
    }
    settle()
    let expectedSize = hosting.fittingSize
    settle()
    let initialMounts = mounts.created
    let initialRemovals = mounts.removed
    let root = try XCTUnwrap(state.root)
    let revision = state.sourceRevision
    var parses = 0, publications = 0, actions = 0
    state.onParseResult = { _ in parses += 1 }
    state.onAction = { _ in actions += 1 }
    let subscription = state.objectWillChange.sink { publications += 1 }
    defer { subscription.cancel() }

    XCTAssertGreaterThan(initialMounts, 0)
    XCTAssertGreaterThan(expectedSize.height, 0)
    for _ in 0..<100 {
      if replayStreamingBuffer { state.setSource(source, streaming: true) }
      let size = hosting.fittingSize
      XCTAssertTrue(size.width.isFinite && size.height.isFinite)
      XCTAssertEqual(size.width, expectedSize.width, accuracy: 0.5)
      XCTAssertEqual(size.height, expectedSize.height, accuracy: 0.5)
      hosting.layoutSubtreeIfNeeded()
    }
    settle()
    XCTAssertEqual(parses, 0)
    XCTAssertEqual(publications, 0)
    XCTAssertEqual(actions, 0)
    XCTAssertEqual(state.sourceRevision, revision)
    XCTAssertTrue(state.root === root)
    XCTAssertEqual(mounts.created, initialMounts)
    XCTAssertEqual(mounts.removed, initialRemovals)
    // We intentionally do not assert body/layout counts are zero. SwiftUI may
    // probe multiple proposals; fitting must not create new semantic updates.
  }
}

@MainActor private final class SizingMountLog {
  var created = 0
  var removed = 0
}

private struct SizingMountMarker: NSViewRepresentable {
  let log: SizingMountLog
  func makeCoordinator() -> SizingMountLog { log }
  func makeNSView(context: Context) -> NSView {
    log.created += 1
    return NSView()
  }
  func updateNSView(_ view: NSView, context: Context) {}
  static func dismantleNSView(_ view: NSView, coordinator: SizingMountLog) {
    coordinator.removed += 1
  }
}


extension HostSizingIsolationTests {
  @MainActor func testActualMarkdownHostFittingDoesNotRepeatPreparationOrSemanticUpdates() async throws {
    _ = NSApplication.shared
    let library = try OpenUIStandardComponents.library()
    let state = OpenUIState(schema: library.library.toSchema())
    let document = NativeMarkdownDocument()
    let definition = try XCTUnwrap(library.library.components.first { $0.name == "TextContent" })
    let measured = try library.extending(overriding: [OpenUIComponent(definition) { context in
      MainActor.assumeIsolated { NativeMarkdownText(text: context.string("text") ?? "", document: document) }
    }])
    let text = "## 原生 Markdown 测量\n\n" + String(repeating: "**强调**与普通中文保持稳定。A link is [readable](https://example.com).\n\n", count: 20)
    let literal = String(data: try JSONEncoder().encode(text), encoding: .utf8)!
    let source = "root=TextContent(\(literal))"
    state.setSource(source, streaming: true)
    let hosting = NSHostingView(rootView: OpenUIRenderer(state: state, registry: measured.registry).frame(width: 320))
    let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 320, height: 600),
      styleMask: [.borderless], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false; window.contentView = hosting
    window.setFrameOrigin(NSPoint(x: -10000, y: -10000)); window.orderFront(nil)
    defer { window.close(); document.cancel() }
    hosting.layoutSubtreeIfNeeded()
    let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in document.currentSource == OpenUIString(text) }, object: nil)
    await fulfillment(of: [ready], timeout: 8)
    hosting.layoutSubtreeIfNeeded()
    let expected = hosting.fittingSize
    let preparations = document.preparationCount, fallbacks = document.fallbackParseCount
    var semanticUpdates = 0
    let subscription = state.objectWillChange.sink { semanticUpdates += 1 }
    defer { subscription.cancel() }
    var durations: [Double] = []
    for _ in 0..<100 {
      let start = DispatchTime.now().uptimeNanoseconds
      state.setSource(source, streaming: true)
      let size = hosting.fittingSize
      hosting.layoutSubtreeIfNeeded()
      durations.append(Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000)
      XCTAssertEqual(size.height, expected.height, accuracy: 0.5)
      XCTAssertEqual(size.width, expected.width, accuracy: 0.5)
    }
    XCTAssertEqual(document.preparationCount, preparations)
    XCTAssertEqual(document.fallbackParseCount, fallbacks)
    XCTAssertEqual(semanticUpdates, 0)
    XCTAssertGreaterThan(expected.height, 0)
    if let directory = ProcessInfo.processInfo.environment["OPENUI_SNAPSHOT_DIR"] {
      let ordered = durations.sorted()
      let report: [String: Any] = ["case": "native-markdown-100-identical-fits", "width": 320,
        "sourceUTF16": text.utf16.count, "count": durations.count, "p50Milliseconds": ordered[49],
        "p95Milliseconds": ordered[94], "maxMilliseconds": ordered.last!,
        "additionalSemanticUpdates": semanticUpdates,
        "additionalPreparations": document.preparationCount - preparations,
        "additionalFallbackParses": document.fallbackParseCount - fallbacks,
        "build": _isDebugAssertConfiguration() ? "debug" : "release",
        "note": "SDK native-host fitting probe, not a client FPS or Instruments trace"]
      try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
      try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
        .write(to: URL(fileURLWithPath: directory).appendingPathComponent("markdown-fitting-\(_isDebugAssertConfiguration() ? "debug" : "release").json"))
    }
  }
}
#endif
