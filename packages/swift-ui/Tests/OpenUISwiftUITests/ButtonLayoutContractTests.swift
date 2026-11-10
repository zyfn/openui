#if os(macOS)
import AppKit
import OpenUILang
import SwiftUI
import XCTest
@testable import OpenUISwiftUI

final class ButtonLayoutContractTests: XCTestCase {
  @MainActor func testUnboundedColumnMeasuresItsWidestChildInsteadOfSummingWidths() {
    _ = NSApplication.shared
    let host = NSHostingView(rootView: NativeButtonsLayout(column: true) {
      Color.clear.frame(width: 40, height: 20)
      Color.clear.frame(width: 70, height: 20)
    }.fixedSize())
    XCTAssertEqual(host.fittingSize.width, 70, accuracy: 1)
    XCTAssertEqual(host.fittingSize.height, 52, accuracy: 1)
  }

  @MainActor private func inspect(_ source: String,
    body: (OpenUIState, ButtonFrames, () -> Void) throws -> Void) throws {
    _ = NSApplication.shared
    let frames = ButtonFrames()
    let standard = try OpenUIStandardComponents.library()
    let definition = try XCTUnwrap(standard.library.components.first { $0.name == "Button" })
    let library = try standard.extending(overriding: [OpenUIComponent(definition) { context in
      let key = context.string("label") ?? ""
      return OpenUINativeButton(context: context).background(GeometryReader { geometry in
        Color.clear.onAppear {
          frames.rects[key] = geometry.frame(in: .global)
          frames.mounts[key, default: 0] += 1
        }.onChange(of: geometry.frame(in: .global)) { frames.rects[key] = $0 }
      })
    }])
    let state = OpenUIState(schema: library.library.toSchema())
    state.setSource(source)
    XCTAssertTrue(state.errors.isEmpty, "\(state.errors)")
    let host = NSHostingView(rootView: OpenUIRenderer(state: state, registry: library.registry).frame(width: 320))
    let window = NSWindow(contentRect: .init(x: 0, y: 0, width: 320, height: 600),
      styleMask: [.borderless], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false; window.contentView = host
    window.setFrameOrigin(.init(x: -10000, y: -10000)); window.orderFront(nil)
    defer { window.close() }
    func settle() {
      host.layoutSubtreeIfNeeded()
      RunLoop.main.run(until: Date().addingTimeInterval(0.15))
      host.layoutSubtreeIfNeeded()
    }
    settle()
    try body(state, frames, settle)
  }

  @MainActor func testColumnFillsAndRowWrapsWithoutRemountingButtons() throws {
    try inspect("root=Buttons([a,b,c],$direction)\n$direction=\"column\"\na=Button(\"One\")\nb=Button(\"Two\")\nc=Button(\"A substantially longer third action\")") { state, values, settle in
      for rect in values.rects.values { XCTAssertEqual(rect.width, 320, accuracy: 1) }
      XCTAssertEqual(values.rects.count, 3)
      state.setState("$direction", value: .string("row")); settle()
      let a = try XCTUnwrap(values.rects["One"])
      let b = try XCTUnwrap(values.rects["Two"])
      let c = try XCTUnwrap(values.rects["A substantially longer third action"])
      XCTAssertEqual(a.minY, b.minY, accuracy: 1)
      XCTAssertGreaterThan(b.minX, a.maxX)
      XCTAssertGreaterThan(abs(c.minY - a.minY), a.height)
      XCTAssertEqual(values.mounts.values.sorted(), [1, 1, 1])
    }
  }

  @MainActor func testStackStretchReachesButtonAndCenterKeepsIntrinsicWidth() throws {
    try inspect("root=Stack([a],\"column\",\"m\",$alignment)\n$alignment=\"stretch\"\na=Button(\"One\")") { state, values, settle in
      XCTAssertEqual(try XCTUnwrap(values.rects["One"]).width, 320, accuracy: 1)
      state.setState("$alignment", value: .string("center")); settle()
      let rect = try XCTUnwrap(values.rects["One"])
      XCTAssertLessThan(rect.width, 160)
      XCTAssertEqual(values.mounts["One"], 1)
    }
  }

  @MainActor func testNestedStacksKeepTheirContentWidthsWhileCardsShareTheRow() throws {
    let left = "Stack([Button(\"One\")])"
    let right = "Stack([Button(\"A longer action\")])"
    try inspect("root=Stack([\(left),\(right)],\"row\")") { _, values, _ in
      XCTAssertLessThan(try XCTUnwrap(values.rects["One"]).width,
        try XCTUnwrap(values.rects["A longer action"]).width)
    }
    try inspect("root=Stack([Card([\(left)]),Card([\(right)])],\"row\")") { _, values, _ in
      XCTAssertEqual(try XCTUnwrap(values.rects["One"]).width,
        try XCTUnwrap(values.rects["A longer action"]).width, accuracy: 1)
    }
  }

  @MainActor func testButtonsInTheSameRowAcceptTheSharedHeight() throws {
    try inspect("root=Buttons([Button(\"One\",null,\"primary\",\"normal\",\"extra-small\"),Button(\"Two\",null,\"primary\",\"normal\",\"large\")],\"row\")") { _, values, _ in
      XCTAssertEqual(try XCTUnwrap(values.rects["One"]).height,
        try XCTUnwrap(values.rects["Two"]).height, accuracy: 1)
    }
  }

  @MainActor func testStretchDoesNotLeakThroughATableIntoItsCellButton() throws {
    try inspect("root=Stack([Table([Col(\"Action\",[Button(\"One\")],\"string\")])],\"column\",\"m\",\"stretch\")") { _, values, _ in
      XCTAssertLessThan(try XCTUnwrap(values.rects["One"]).width, 160)
    }
  }
}

private final class ButtonFrames {
  var rects: [String: CGRect] = [:]
  var mounts: [String: Int] = [:]
}
#endif
