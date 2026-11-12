#if os(macOS)
import AppKit
import OpenUILang
import SwiftUI
import XCTest
@testable import OpenUISwiftUI

final class GalleryReadingWidthTests: XCTestCase {
  @MainActor private func height(_ source: String, width: CGFloat, streaming: Bool = false) throws -> CGFloat {
    _ = NSApplication.shared
    let library = try OpenUIStandardComponents.library()
    let state = OpenUIState(schema: library.library.toSchema())
    if streaming { state.push(source) } else { state.setSource(source) }
    XCTAssertTrue(state.errors.isEmpty, "\(state.errors)")
    let host = NSHostingView(rootView: OpenUIRenderer(state: state, registry: library.registry).frame(width: width))
    let window = NSWindow(contentRect: .init(x: -10000, y: -10000, width: width, height: 1400),
      styleMask: [.borderless], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false; window.contentView = host; window.orderFront(nil)
    defer { window.close() }
    host.layoutSubtreeIfNeeded(); RunLoop.main.run(until: Date().addingTimeInterval(0.1))
    return host.fittingSize.height
  }

  @MainActor func testActualGalleryReflowsThreeImagesAtReadingWidths() throws {
    let source = "root=Stack([ImageGallery([{src:\"\",alt:\"A\"},{src:\"\",alt:\"B\"},{src:\"\",alt:\"C\"}])])"
    // Validate the real registered renderer, not just the generic grid helper.
    XCTAssertEqual(try height(source, width: 350), 169 * 9 / 16 * 2 + 12, accuracy: 1)
    XCTAssertEqual(try height(source, width: 530), (530 - 24) / 3 * 9 / 16, accuracy: 1)
    XCTAssertEqual(try height(source, width: 240), 240 * 9 / 16 * 3 + 24, accuracy: 1)
  }

  @MainActor func testInlinePreviewAllocatesOnlyItsFiveVisibleSlotsWhileReferencesArrive() throws {
    let completed = "root=Stack([ImageGallery([{src:\"\",alt:\"A\"},{src:\"\",alt:\"B\"},{src:\"\",alt:\"C\"},{src:\"\",alt:\"D\"},{src:\"\",alt:\"E\"}])])"
    let partial = "root=Stack([ImageGallery([a,b,c,d,e,f])])\na={src:\"\",alt:\"A\"}\n"
    XCTAssertEqual(try height(partial, width: 1200, streaming: true), try height(completed, width: 1200), accuracy: 1,
      "Future records outside the five-photo preview must not make the first visible photo narrower")
  }

  @MainActor func testAdditionalImagesDoNotAddAnInlineButtonOrExpandThePreview() throws {
    func source(_ count: Int) -> String {
      let images = (1...count).map { "{src:\"\",alt:\"Photo \($0)\"}" }.joined(separator: ",")
      return "root=Stack([ImageGallery([\(images)])])"
    }
    // At one column a sixth image or an extra button would increase height.
    XCTAssertEqual(try height(source(6), width: 240), try height(source(5), width: 240), accuracy: 1)
  }
}
#endif
