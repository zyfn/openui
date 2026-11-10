#if os(macOS)
import AppKit
import OpenUILang
import SwiftUI
import XCTest
@testable import OpenUISwiftUI

final class StreamingVisualStateTests: XCTestCase {
  @MainActor func testPieReservesItsLegendRegionBeforeLabelsAndValuesArrive() throws {
    _ = NSApplication.shared
    let library = try OpenUIStandardComponents.library()
    let state = OpenUIState(schema: library.library.toSchema())
    state.push("root=PieChart(labels,values)\n")
    let host = NSHostingView(rootView: OpenUIRenderer(state: state, registry: library.registry).frame(width: 320))
    let initial = host.fittingSize.height
    XCTAssertGreaterThan(initial, 234)
    state.push("labels=[\"A\",\"B\",\"C\"]\nvalues=[2,4,3]\n"); state.complete()
    host.layoutSubtreeIfNeeded(); RunLoop.main.run(until: Date().addingTimeInterval(0.06))
    XCTAssertEqual(host.fittingSize.height, initial, accuracy: 1)
  }

  @MainActor func testRootChartReservesSpaceWhileRequiredReferencesAreStillAbsent() throws {
    _ = NSApplication.shared
    let library = try OpenUIStandardComponents.library()
    let state = OpenUIState(schema: library.library.toSchema())
    state.push("root=LineChart(labels,series)\n")
    XCTAssertNil(state.root)
    XCTAssertEqual(state.presentationRoot?.placeholder?.typeName, "LineChart")
    let host = NSHostingView(rootView: OpenUIRenderer(state: state, registry: library.registry).frame(width: 320))
    let initial = host.fittingSize.height
    XCTAssertGreaterThanOrEqual(initial, 250)
    state.push("labels=[\"A\",\"B\"]\nseries=[Series(\"S\",[1,2])]\n"); state.complete()
    host.layoutSubtreeIfNeeded(); RunLoop.main.run(until: Date().addingTimeInterval(0.06))
    XCTAssertEqual(host.fittingSize.height, initial, accuracy: 1)
  }

  @MainActor func testTableAddsOnlyCommittedRowsWithoutInventedSkeletonRows() throws {
    _ = NSApplication.shared
    let library = try OpenUIStandardComponents.library()
    let state = OpenUIState(schema: library.library.toSchema())
    state.push("root=Table([column])\ncolumn=Col(\"Value\",values,\"number\")\nvalues=[1")
    let host = NSHostingView(rootView: OpenUIRenderer(state: state, registry: library.registry).frame(width: 320))
    let window = NSWindow(contentRect: .init(x: 0, y: 0, width: 320, height: 400),
      styleMask: [.borderless], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false; window.contentView = host
    window.setFrameOrigin(.init(x: -10000, y: -10000)); window.orderFront(nil)
    defer { window.close() }
    func height() -> CGFloat {
      host.layoutSubtreeIfNeeded(); RunLoop.main.run(until: Date().addingTimeInterval(0.06))
      return host.fittingSize.height
    }
    let empty = height()
    state.push(","); let first = height()
    XCTAssertGreaterThan(first, empty + 20)
    state.push("2"); XCTAssertEqual(height(), first, accuracy: 1)
    state.push("0,"); let second = height()
    XCTAssertGreaterThan(second, first + 20)
    state.push("]"); state.complete()
    XCTAssertEqual(height(), second, accuracy: 1)
  }

  @MainActor private func pixels(_ source: String, streaming: Bool, disabled: Bool = false) throws -> (dark: Double, gray: Double) {
    _ = NSApplication.shared
    let library = try OpenUIStandardComponents.library()
    let state = OpenUIState(schema: library.library.toSchema())
    state.setSource(source, streaming: streaming)
    let host = NSHostingView(rootView: OpenUIRenderer(state: state, registry: library.registry)
      .disabled(disabled).environment(\.colorScheme, .light)
      .frame(width: 180, height: 70).background(Color.white))
    let window = NSWindow(contentRect: .init(x: 0, y: 0, width: 180, height: 70),
      styleMask: [.borderless], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false; window.contentView = host
    window.appearance = NSAppearance(named: .aqua)
    window.setFrameOrigin(.init(x: -10000, y: -10000)); window.orderFront(nil)
    defer { window.close() }
    host.layoutSubtreeIfNeeded(); RunLoop.main.run(until: Date().addingTimeInterval(0.08))
    let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
    host.cacheDisplay(in: host.bounds, to: bitmap)
    var dark = 0, gray = 0
    for y in 0..<bitmap.pixelsHigh {
      for x in 0..<bitmap.pixelsWide {
        guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { continue }
        let value = max(color.redComponent, color.greenComponent, color.blueComponent)
        if value < 0.25 { dark += 1 }
        if value > 0.55 && value < 0.82 { gray += 1 }
      }
    }
    let total = Double(bitmap.pixelsWide * bitmap.pixelsHigh)
    return (Double(dark) / total, Double(gray) / total)
  }

  @MainActor func testGeneratedPrimaryDoesNotUseBusinessDisabledGrayAndUnknownStyleIsHidden() throws {
    let open = try pixels("root=Button(\"Continue\"", streaming: true)
    XCTAssertLessThan(open.dark + open.gray, 0.01, "Unknown style must not paint a provisional capsule")
    let source = "root=Button(\"Continue\",@ToAssistant(\"continue\"),\"primary\")"
    let pending = try pixels(source, streaming: true)
    let ready = try pixels(source, streaming: false)
    XCTAssertGreaterThan(pending.dark, 0.1)
    XCTAssertEqual(pending.dark, ready.dark, accuracy: 0.015)
    XCTAssertLessThan(pending.gray, 0.02)
    let disabled = try pixels(source, streaming: false, disabled: true)
    XCTAssertGreaterThan(disabled.gray, 0.1, "Actual host-disabled state keeps its distinct appearance")
  }

  @MainActor func testChartReservesItsPlotBeforeAnyValueIsCommitted() throws {
    _ = NSApplication.shared
    let library = try OpenUIStandardComponents.library()
    let state = OpenUIState(schema: library.library.toSchema())
    state.push("root=LineChart([\"A\",\"B\"],[Series(\"S\",[")
    let host = NSHostingView(rootView: OpenUIRenderer(state: state, registry: library.registry).frame(width: 320))
    let pendingHeight = host.fittingSize.height
    XCTAssertGreaterThanOrEqual(pendingHeight, 250)
    state.push("1,20])])"); state.complete()
    host.layoutSubtreeIfNeeded(); RunLoop.main.run(until: Date().addingTimeInterval(0.05))
    XCTAssertEqual(host.fittingSize.height, pendingHeight, accuracy: 1)
  }
}
#endif
