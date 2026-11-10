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

  #if os(macOS)
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
