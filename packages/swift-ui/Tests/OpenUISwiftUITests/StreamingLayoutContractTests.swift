import SwiftUI
import XCTest
import OpenUILang
@testable import OpenUISwiftUI
#if os(macOS)
import AppKit
#endif

final class StreamingLayoutContractTests: XCTestCase {
  @MainActor func testClosedLayoutCanStreamItsReferencedTextWithoutWaitingForWholeProgram() throws {
    let library = try OpenUIStandardComponents.library()
    let state = OpenUIState(schema: library.library.toSchema())
    state.push("root=Stack([copy],\"column\",\"s\")\ncopy=TextContent(\"正在逐字")
    let root = try XCTUnwrap(state.root)
    XCTAssertFalse(root.isSourceComplete)
    XCTAssertTrue(NativeLayoutContract.ready(root.sourceReadiness, fields: library.registry.presentationLayoutFields("Stack")))
  }

  @MainActor func testReplacingAStandardRendererDoesNotInheritItsLayoutGate() throws {
    let library = try OpenUIStandardComponents.library()
    var registry = library.registry
    XCTAssertFalse(registry.presentationLayoutFields("Stack").isEmpty)
    registry["Stack"] = { _, _ in AnyView(Text("Custom")) }
    XCTAssertTrue(registry.presentationLayoutFields("Stack").isEmpty)
  }

  @MainActor func testChartDoesNotCommitItsDefaultHeightBeforeATrailingHeightArrives() throws {
    let library = try OpenUIStandardComponents.library()
    let state = OpenUIState(schema: library.library.toSchema())
    state.push("root=LineChart([\"A\",\"B\"],[Series(\"S\",[1,2])],\"linear\",\"X\",\"Y\",")
    let fields = library.registry.presentationLayoutFields("LineChart")
    XCTAssertTrue(fields.contains("height"))
    XCTAssertFalse(NativeLayoutContract.ready(try XCTUnwrap(state.root).sourceReadiness, fields: fields))
    state.push("160)")
    XCTAssertTrue(NativeLayoutContract.ready(try XCTUnwrap(state.root).sourceReadiness, fields: fields))
  }

  #if os(macOS)
  @MainActor func testClearCardsShareColumnsWithoutAddingContentInsets() throws {
    _ = NSApplication.shared
    let library = try OpenUIStandardComponents.library()
    let state = OpenUIState(schema: library.library.toSchema())
    var registry = library.registry
    let original = try XCTUnwrap(registry["Image"])
    var frames: [String: CGRect] = [:]
    registry["Image"] = { element, registry in
      let key = PropValue.string(element, "alt") ?? "?"
      return AnyView(original(element, registry).background(GeometryReader { geometry in
        Color.clear.onAppear { frames[key] = geometry.frame(in: .global) }
          .onChange(of: geometry.frame(in: .global)) { frames[key] = $0 }
      }))
    }
    let host = NSHostingView(rootView: OpenUIRenderer(state: state, registry: registry).frame(width: 320))
    let window = NSWindow(contentRect: .init(x: 0, y: 0, width: 320, height: 600),
      styleMask: [.borderless], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false; window.contentView = host
    window.setFrameOrigin(.init(x: -10000, y: -10000)); window.orderFront(nil)
    defer { window.close() }
    func settle(_ source: String) {
      frames.removeAll(); state.setSource(source)
      host.layoutSubtreeIfNeeded(); RunLoop.main.run(until: Date().addingTimeInterval(0.10))
      host.layoutSubtreeIfNeeded()
    }
    for variant in ["clear", "card", "sunk"] {
      for count in [2, 3] {
        let children = (0..<count).map { "Card([Image(\"\($0)\",\"\")],\"\(variant)\")" }.joined(separator: ",")
        settle("root=Stack([\(children)],\"row\",\"m\",\"start\",\"start\",true)")
        let inset: CGFloat = variant == "clear" ? 0 : OpenUIThemeValues().componentStyle.panelInset
        let cell = (320 - CGFloat(count - 1) * 12) / CGFloat(count)
        for index in 0..<count {
          let rect = try XCTUnwrap(frames[String(index)])
          XCTAssertEqual(rect.width, cell - 2 * inset, accuracy: 1, "\(variant) \(count) columns")
          XCTAssertEqual(rect.minX, CGFloat(index) * (cell + 12) + inset, accuracy: 1)
        }
      }
    }
    settle("root=Card([Card([Image(\"nested\",\"\")],\"clear\")],\"clear\")")
    XCTAssertEqual(try XCTUnwrap(frames["nested"]).width, 320, accuracy: 1,
      "Nested transparent layout units must not accumulate gutters")
  }

  @MainActor func testLaterUnresolvedSiblingDoesNotRemoveOrRemountAnAlreadyVisibleText() throws {
    _ = NSApplication.shared
    let library = try OpenUIStandardComponents.library()
    let state = OpenUIState(schema: library.library.toSchema())
    let log = LayoutTextMountLog()
    var registry = library.registry
    let original = try XCTUnwrap(registry["TextContent"])
    registry["TextContent"] = { element, registry in
      AnyView(original(element, registry).background {
        if PropValue.string(element, "text") == "Stable" { LayoutTextMountMarker(log: log) }
      })
    }
    state.push("root=Stack([TextContent(\"Stable\")")
    let host = NSHostingView(rootView: OpenUIRenderer(state: state, registry: registry).frame(width: 320))
    let window = NSWindow(contentRect: .init(x:0,y:0,width:320,height:700), styleMask:[.borderless], backing:.buffered, defer:false)
    window.isReleasedWhenClosed=false; window.contentView=host
    window.setFrameOrigin(.init(x:-10000,y:-10000)); window.orderFront(nil)
    defer { window.close() }
    func settle() { host.layoutSubtreeIfNeeded(); RunLoop.main.run(until:Date().addingTimeInterval(0.10)) }
    settle()
    let first = try XCTUnwrap(log.view)
    state.push(",later")
    settle()
    XCTAssertEqual(log.removed, 0, "A later unresolved slot cannot erase the readable prefix")
    XCTAssertTrue(log.view === first)
    state.push("],\"column\",\"m\")\nlater=TextContent(\"Later\")")
    settle()
    XCTAssertTrue(log.view === first, "Settling layout must preserve the existing text view identity")
    XCTAssertEqual(log.created, 1)
    XCTAssertEqual(log.removed, 0)
  }

  @MainActor func testFluidMediaWaitsCompactlyButKnownThumbnailKeepsItsFixedSize() {
    _ = NSApplication.shared
    let fluid = NSHostingView(rootView: NativeRemoteImage(src: nil, layout: .cover,
      cachedImage: Image(systemName: "photo")).environment(\.openUIMediaWidthReady, false)
      .environment(\.openUIStreamActive, true).frame(width: 320))
    XCTAssertLessThan(fluid.fittingSize.height, 100)
    let resolved = NSHostingView(rootView: NativeRemoteImage(src: nil, layout: .cover,
      cachedImage: Image(systemName: "photo")).frame(width: 320))
    XCTAssertEqual(resolved.fittingSize.height, 180, accuracy: 1)
    let thumbnail = NSHostingView(rootView: NativeRemoteImage(src: nil,
      layout: .thumbnail(.init(width: 72, height: 72)), cachedImage: Image(systemName: "photo"))
      .environment(\.openUIMediaWidthReady, false))
    XCTAssertEqual(thumbnail.fittingSize, .init(width: 72, height: 72))
  }

  @MainActor func testLateWrapArgumentDoesNotRevealAnIntermediateTwoColumnImageLayout() throws {
    _ = NSApplication.shared
    let library = try OpenUIStandardComponents.library()
    let state = OpenUIState(schema: library.library.toSchema())
    var registry = library.registry
    let original = try XCTUnwrap(registry["Image"])
    var sizes: [String: CGSize] = [:]
    registry["Image"] = { element, registry in
      let key = PropValue.string(element,"alt") ?? "?"
      return AnyView(original(element,registry).background(GeometryReader { g in
        Color.clear.onAppear { sizes[key] = g.size }.onChange(of: g.size) { sizes[key] = $0 }
      }))
    }
    let host = NSHostingView(rootView: OpenUIRenderer(state: state,registry:registry).frame(width:320))
    let window = NSWindow(contentRect:.init(x:0,y:0,width:320,height:1000),styleMask:[.borderless],backing:.buffered,defer:false)
    window.isReleasedWhenClosed=false; window.contentView=host
    window.setFrameOrigin(.init(x:-10000,y:-10000)); window.orderFront(nil)
    defer { window.close() }
    state.push("root=Stack([pair])\na=Stack([Image(\"A\",\"\"),TextContent(\"第一块已经完整的内容\")])\nb=Stack([Image(\"B\",\"\"),TextContent(\"第二块已经完整并且较长的内容\")])\npair=Stack([a,")
    for chunk in ["b],", "\"row\",", "\"m\",\"start\",\"start\","] {
      state.push(chunk)
      host.layoutSubtreeIfNeeded(); RunLoop.main.run(until:Date().addingTimeInterval(0.06))
      XCTAssertTrue(sizes.isEmpty, "Do not reveal an image at a guessed intermediate width")
    }
    state.push("true)")
    host.layoutSubtreeIfNeeded(); RunLoop.main.run(until:Date().addingTimeInterval(0.06))
    XCTAssertNotNil(sizes["A"]); XCTAssertNotNil(sizes["B"])
    let committed = sizes
    state.complete()
    host.layoutSubtreeIfNeeded(); RunLoop.main.run(until:Date().addingTimeInterval(0.06))
    XCTAssertEqual(sizes, committed)
  }
  #endif
}

#if os(macOS)
@MainActor private final class LayoutTextMountLog {
  var view: NSView?
  var created = 0
  var removed = 0
}
private struct LayoutTextMountMarker: NSViewRepresentable {
  let log: LayoutTextMountLog
  func makeCoordinator() -> LayoutTextMountLog { log }
  func makeNSView(context: Context) -> NSView {
    let view = NSView(); log.view = view; log.created += 1; return view
  }
  func updateNSView(_ view: NSView, context: Context) {}
  static func dismantleNSView(_ view: NSView, coordinator: LayoutTextMountLog) { coordinator.removed += 1 }
}
#endif
