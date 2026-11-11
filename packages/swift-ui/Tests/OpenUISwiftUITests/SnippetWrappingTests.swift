#if os(macOS)
import AppKit
import SwiftUI
import OpenUILang
import XCTest
@testable import OpenUISwiftUI

final class SnippetWrappingTests: XCTestCase {
  @MainActor func testLongSnippetAddressWrapsInTheRightColumn() throws {
    _ = NSApplication.shared
    let frames = SnippetBounds()
    let standard = try OpenUIStandardComponents.library()
    let probes = try ["IconText", "Text"].map { name -> OpenUIComponent in
      let definition = try XCTUnwrap(standard.library.components.first { $0.name == name })
      let original = try XCTUnwrap(standard.registry[name])
      return OpenUIComponent(definition) { context in
        original(context.element, standard.registry).background(GeometryReader { geometry in
          Color.clear.onAppear { frames.values[name] = geometry.frame(in: .named("snippet")) }
            .onChange(of: geometry.frame(in: .named("snippet"))) { frames.values[name] = $0 }
        })
      }
    }
    let library = try standard.extending(overriding: probes)
    let state = OpenUIState(schema: library.library.toSchema())
    let host = NSHostingView(rootView: OpenUIRenderer(state: state, registry: library.registry).frame(width: 320).coordinateSpace(name: "snippet"))
    let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 320, height: 600), styleMask: [.borderless], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false; window.contentView = host
    window.setFrameOrigin(NSPoint(x: -10000, y: -10000)); window.orderFront(nil)
    defer { window.close() }
    var shortHeight: CGFloat = 0
    for value in ["重庆北路 188 号", "重庆北路 188 号总店，地址说明很长时继续在原右侧列内阅读，不把整列挪到下一行"] {
      state.setSource("root=SnippetCardItem(\"shop\",IconText(Icon(\"utensils\"),\"neutral\",\"m\",\"东泰祥\",\"半发酵工艺非遗\"),Text(\"text\",\(jsonStringLiteral(value))))")
      XCTAssertTrue(state.errors.isEmpty, "\(state.errors)")
      host.layoutSubtreeIfNeeded(); RunLoop.main.run(until: Date().addingTimeInterval(0.15))
      let left = try XCTUnwrap(frames.values["IconText"]), right = try XCTUnwrap(frames.values["Text"])
      XCTAssertGreaterThanOrEqual(right.minX, left.maxX + 8)
      XCTAssertGreaterThanOrEqual(right.width, 100, "The address must retain a readable column")
      XCTAssertEqual(left.midY, right.midY, accuracy: 1, "Long text must remain alongside the label")
      if shortHeight == 0 { shortHeight = right.height } else { XCTAssertGreaterThan(right.height, shortHeight) }
    }
  }
}
@MainActor private final class SnippetBounds { var values: [String: CGRect] = [:] }
#endif
