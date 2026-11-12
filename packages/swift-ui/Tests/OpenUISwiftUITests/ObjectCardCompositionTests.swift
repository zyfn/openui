#if os(macOS)
import AppKit
import OpenUILang
import SwiftUI
import XCTest
@testable import OpenUISwiftUI

final class ObjectCardCompositionTests: XCTestCase {
  @MainActor private func frames(_ source: String, width: CGFloat) throws -> [String: CGRect] {
    _ = NSApplication.shared
    let library = try OpenUIStandardComponents.library()
    let measured = ObjectCardFrames()
    var registry = library.registry
    for name in ["ImageTextLarge", "BoldText", "Button", "Image"] {
      let original = try XCTUnwrap(registry[name])
      registry[name] = { element, registry in
        AnyView(original(element, registry).background(GeometryReader { geometry in
          Color.clear.onAppear { measured.record(name, geometry.frame(in: .named("objects"))) }
            .onChange(of: geometry.frame(in: .named("objects"))) { measured.record(name, $0) }
        }))
      }
    }
    let state = OpenUIState(schema: library.library.toSchema())
    state.setSource(source)
    XCTAssertTrue(state.errors.isEmpty, "\(state.errors)")
    let host = NSHostingView(rootView: OpenUIRenderer(state: state, registry: registry)
      .frame(width: width).coordinateSpace(name: "objects"))
    let window = NSWindow(contentRect: .init(x: 0, y: 0, width: width, height: 1800),
      styleMask: [.borderless], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false; window.contentView = host
    window.setFrameOrigin(.init(x: -10000, y: -10000)); window.orderFront(nil)
    defer { window.close() }
    host.layoutSubtreeIfNeeded(); RunLoop.main.run(until: Date().addingTimeInterval(0.12))
    host.layoutSubtreeIfNeeded()
    return measured.values
  }

  private var definitions: String {
    """
    heading=ImageTextLarge("", "Room", "A room by the lake", "One night", true)
    copy=Text("text", "A quiet room near the destination.")
    price=BoldText("number", "¥12,345", "Per night", "text", "lg")
    action=Button("Book room", @OpenUrl("https://example.invalid/room"), "primary", "normal", "small")
    """
  }
  private var single: String {
    """
    root=Stack([Card([Stack([heading]), Stack([copy]), footer], "card", "column", "m")])
    footer=Card([Stack([price]), Buttons([action], "row")], "clear", "row", "s", "center", "between", true)
    \(definitions)
    """
  }
  private var collection: String {
    """
    root=Stack([CompositeCardBlock([first, second], "grid", false)])
    first=CompositeCardItem("one", heading, [copy], {price:price, button:action})
    second=CompositeCardItem("two", heading, [copy], {price:price, button:action})
    \(definitions)
    """
  }

  @MainActor func testSingleAndCollectionUseTheSameHeaderInsetsAndFooterGeometry() throws {
    for width in [CGFloat(200), 344] {
      let one = try frames(single, width: width)
      let many = try frames(collection, width: width * 2 + 12)
      for name in ["ImageTextLarge", "BoldText", "Button"] {
        let a = try XCTUnwrap(one[name]), b = try XCTUnwrap(many[name])
        XCTAssertEqual(a.minX, b.minX, accuracy: 1, "\(name), card width \(width)")
        XCTAssertEqual(a.width, b.width, accuracy: 1, "\(name), card width \(width)")
        XCTAssertEqual(a.height, b.height, accuracy: 1, "\(name), card width \(width)")
        // Normalize to the header so a hosting window's vertical origin is irrelevant.
        XCTAssertEqual(a.minY - one["ImageTextLarge"]!.minY,
          b.minY - many["ImageTextLarge"]!.minY, accuracy: 1, name)
      }
      XCTAssertEqual(try XCTUnwrap(one["ImageTextLarge"]).minX, 16, accuracy: 1)
      XCTAssertEqual(try XCTUnwrap(one["ImageTextLarge"]).width, width - 32, accuracy: 1)
    }
  }

  @MainActor func testNarrowFootersWrapWithoutBreakingTheAmountOrLosingTheAction() throws {
    for source in [single, collection] {
      let narrow = try frames(source, width: source == single ? 200 : 412)
      let wide = try frames(source, width: source == single ? 344 : 700)
      let amount = try XCTUnwrap(narrow["BoldText"]), button = try XCTUnwrap(narrow["Button"])
      XCTAssertGreaterThanOrEqual(button.minY, amount.maxY + 7)
      XCTAssertEqual(amount.height, try XCTUnwrap(wide["BoldText"]).height, accuracy: 1)
      XCTAssertLessThanOrEqual(button.maxX, 184)
      XCTAssertGreaterThan(button.width, 40)
      XCTAssertLessThan(try XCTUnwrap(wide["Button"]).minY, try XCTUnwrap(wide["BoldText"]).maxY)
    }
  }

  @MainActor func testLeadingImagesFillCardEdgesWhileBodyImagesRetainTheirInset() throws {
    _ = NSApplication.shared
    let library = try OpenUIStandardComponents.library()
    var theme = OpenUIThemeValues()
    theme.sunk = .red; theme.foreground = .white
    func bitmap(_ source: String, width: CGFloat = 320) throws -> NSBitmapImageRep {
      let state = OpenUIState(schema: library.library.toSchema()); state.setSource(source)
      XCTAssertTrue(state.errors.isEmpty, "\(state.errors)")
      let renderer = ImageRenderer(content: OpenUIRenderer(state: state, registry: library.registry)
        .openUITheme(theme).frame(width: width).background(.white).environment(\.colorScheme, .light))
      renderer.scale = 1
      return NSBitmapImageRep(cgImage: try XCTUnwrap(renderer.cgImage))
    }
    func isRed(_ image: NSBitmapImageRep, x: Int, y: Int) throws -> Bool {
      let color = try XCTUnwrap(image.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB))
      return color.redComponent > 0.8 && color.greenComponent < 0.5 && color.blueComponent < 0.5
    }
    for source in [
      "root=Card([Image(\"photo\"),CardHeader(\"Title\")],\"card\")",
      "root=Card([Stack([ImageTextLarge(\"\",\"photo\",\"Title\")])],\"card\")",
      "root=CompositeCardBlock([CompositeCardItem(\"a\",ImageTextLarge(\"\",\"photo\",\"Title\"),[]),CompositeCardItem(\"b\",ImageTextLarge(\"\",\"photo\",\"Title\"),[])],\"grid\",false)"
    ] {
      let image = try bitmap(source, width: source.contains("CompositeCardBlock") ? 652 : 320)
      XCTAssertTrue(try isRed(image, x: 5, y: 60), "Leading image must reach the card's left edge")
      XCTAssertTrue(try isRed(image, x: 60, y: 5), "Leading image must reach the card's top edge")
    }
    let body = try bitmap("root=Card([CardHeader(\"Title\"),Image(\"body\")],\"card\")")
    XCTAssertFalse(try isRed(body, x: 5, y: 100), "Body image must not extend through its surrounding content inset")
    XCTAssertTrue(try isRed(body, x: 40, y: 100))
  }

  @MainActor func testWrappingCardsKeepReadingSpaceAndFillAnIncompleteRow() throws {
    let cases: [(CGFloat, [CGFloat])] = [(320, [320, 320, 320]),
      (350, [169, 169, 350]), (530, [506 / 3, 506 / 3, 506 / 3])]
    for (width, expected) in cases {
      let source = "root=Stack([Card([Image(\"a\")],\"clear\"),Card([Image(\"b\")],\"clear\"),Card([Image(\"c\")],\"clear\")],\"row\",\"m\",\"start\",\"start\",true)"
      // Individual Image names are recorded separately by their alt in a dedicated probe below.
      let measured = try imageFrames(source, width: width)
      for (index, key) in ["a", "b", "c"].enumerated() {
        XCTAssertEqual(try XCTUnwrap(measured[key]).width, expected[index], accuracy: 1)
      }
      if width == 350 {
        XCTAssertEqual(try XCTUnwrap(measured["a"]).minY, try XCTUnwrap(measured["b"]).minY, accuracy: 1)
        XCTAssertGreaterThan(try XCTUnwrap(measured["c"]).minY, try XCTUnwrap(measured["a"]).maxY)
      }
    }
  }

  @MainActor private func imageFrames(_ source: String, width: CGFloat) throws -> [String: CGRect] {
    let library = try OpenUIStandardComponents.library()
    let measured = ObjectCardFrames()
    var registry = library.registry
    let original = try XCTUnwrap(registry["Image"])
    registry["Image"] = { element, registry in
      AnyView(original(element, registry).background(GeometryReader { geometry in
        Color.clear.onAppear { measured.values[PropValue.string(element, "alt") ?? ""] = geometry.frame(in: .global) }
          .onChange(of: geometry.frame(in: .global)) { measured.values[PropValue.string(element, "alt") ?? ""] = $0 }
      }))
    }
    let state = OpenUIState(schema: library.library.toSchema()); state.setSource(source)
    let host = NSHostingView(rootView: OpenUIRenderer(state: state, registry: registry).frame(width: width))
    let window = NSWindow(contentRect: .init(x: -10000, y: -10000, width: width, height: 1600),
      styleMask: [.borderless], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false; window.contentView = host; window.orderFront(nil)
    defer { window.close() }
    host.layoutSubtreeIfNeeded(); RunLoop.main.run(until: Date().addingTimeInterval(0.12))
    return measured.values
  }

  @MainActor func testImagesWaitForUnknownRowContributorsThenStayFixedWhileCopyGrows() throws {
    _ = NSApplication.shared
    let library = try OpenUIStandardComponents.library()
    var registry = library.registry
    let original = try XCTUnwrap(registry["Image"])
    let measured = ObjectCardFrames()
    registry["Image"] = { element, registry in
      AnyView(original(element, registry).background(GeometryReader { geometry in
        Color.clear.onAppear { measured.values[PropValue.string(element, "alt") ?? ""] = geometry.frame(in: .global) }
          .onChange(of: geometry.frame(in: .global)) { measured.values[PropValue.string(element, "alt") ?? ""] = $0 }
      }))
    }
    let state = OpenUIState(schema: library.library.toSchema())
    state.push("root=Stack([a,b],\"row\",\"m\",\"start\",\"start\",true)\na=Card([Image(\"a\")],\"clear\")\n")
    let host = NSHostingView(rootView: OpenUIRenderer(state: state, registry: registry).frame(width: 350))
    let window = NSWindow(contentRect: .init(x: -10000, y: -10000, width: 350, height: 1400),
      styleMask: [.borderless], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false; window.contentView = host; window.orderFront(nil)
    defer { window.close() }
    func settle() { host.layoutSubtreeIfNeeded(); RunLoop.main.run(until: Date().addingTimeInterval(0.12)) }
    settle()
    XCTAssertLessThan(try XCTUnwrap(measured.values["a"]).height, 40,
      "Only compact pending feedback, not a full-width picture, may appear while a sibling's role is unknown")
    state.push("b=Card([Image(\"b\"),copy],\"clear\")\ncopy=TextContent(\"Short")
    settle()
    let before = try XCTUnwrap(measured.values["a"])
    XCTAssertEqual(before.width, 169, accuracy: 1)
    XCTAssertEqual(before.height, 169 * 9 / 16, accuracy: 1)
    state.push(" copy that grows across many lines inside the same reading column.")
    settle()
    XCTAssertEqual(try XCTUnwrap(measured.values["a"]).width, before.width, accuracy: 1)
    XCTAssertEqual(try XCTUnwrap(measured.values["a"]).height, before.height, accuracy: 1)
    state.push("\")"); state.complete(); settle()
    XCTAssertEqual(try XCTUnwrap(measured.values["a"]).width, before.width, accuracy: 1)
  }
}

@MainActor private final class ObjectCardFrames {
  var values: [String: CGRect] = [:]
  func record(_ name: String, _ frame: CGRect) {
    if values[name] == nil || frame.minX <= values[name]!.minX { values[name] = frame }
  }
}
#endif
