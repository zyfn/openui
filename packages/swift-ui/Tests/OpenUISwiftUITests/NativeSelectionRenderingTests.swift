#if os(macOS)
import AppKit
import OpenUILang
import SwiftUI
import XCTest

@testable import OpenUISwiftUI

final class NativeSelectionRenderingTests: XCTestCase {
    @MainActor func testDefaultTabsContentRefreshesWithAStandardFieldBinding() throws {
        _ = NSApplication.shared
        let marker = OpenUIComponent(
            name: "LocationMarker", description: "A native marker for the visible tab content",
            params: [OpenUIParameter.string("location")]
        ) { TabLocationMarker(location: $0.string("location") ?? "") }
        let library = try OpenUIStandardComponents.library().extending(adding: [marker])
        let state = OpenUIState(schema: library.library.toSchema())
        state.setSource("""
        $day="ferry"
        panels=[TabItem("day1","Day one",[LocationMarker($day)]),TabItem("day2","Day two",[LocationMarker("academy")])]
        root=Stack([Tabs(panels),Input("selection",null,null,null,$day)])
        """)
        XCTAssertTrue(state.errors.isEmpty, "\(state.errors)")

        func mount() -> (NSWindow, NSView) {
            let hosting = NSHostingView(rootView: OpenUIRenderer(state: state, registry: library.registry))
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 420, height: 180), styleMask: [.borderless],
                backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.contentView = hosting
            window.setFrameOrigin(NSPoint(x: -10000, y: -10000))
            window.orderFront(nil)
            return (window, hosting)
        }
        func locations(in view: NSView) -> [String] {
            let own = (view as? NSTextField).flatMap {
                $0.identifier?.rawValue == "openui.test.tab-location" ? $0.stringValue : nil
            }
            return own.map { [$0] } ?? view.subviews.flatMap { locations(in: $0) }
        }
        func settle(_ view: NSView) {
            view.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.1))
            view.layoutSubtreeIfNeeded()
        }

        let (inlineWindow, inline) = mount()
        defer { inlineWindow.close() }
        settle(inline)
        XCTAssertEqual(locations(in: inline), ["ferry"])
        let selection = try XCTUnwrap(state.binding(for: try XCTUnwrap(PropValue.children(try XCTUnwrap(state.root)).last), prop: "value"))

        selection.wrappedValue = .string("academy")
        XCTAssertEqual(state.stateValue("$day"), .string("academy"))
        settle(inline)
        XCTAssertEqual(locations(in: inline), ["academy"], "Inline Tabs must render day2 after a shared Binding write")

        // An expanded presentation reads the same state, without reconstructing inline.
        let (expandedWindow, expanded) = mount()
        defer { expandedWindow.close() }
        settle(expanded)
        XCTAssertEqual(locations(in: expanded), ["academy"])
        selection.wrappedValue = .string("ferry")
        XCTAssertEqual(state.stateValue("$day"), .string("ferry"))
        settle(inline)
        settle(expanded)
        XCTAssertEqual(locations(in: inline), ["ferry"])
        XCTAssertEqual(locations(in: expanded), ["ferry"], "Existing presentations must follow subsequent shared writes")
    }
}

private struct TabLocationMarker: NSViewRepresentable {
    let location: String
    func makeNSView(context: Context) -> NSTextField {
        let label = NSTextField(labelWithString: location)
        label.identifier = NSUserInterfaceItemIdentifier("openui.test.tab-location")
        return label
    }
    func updateNSView(_ view: NSTextField, context: Context) { view.stringValue = location }
}
#endif
