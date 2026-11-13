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
#endif
