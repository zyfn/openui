import SwiftUI
import XCTest
import OpenUILang
@testable import OpenUISwiftUI
#if os(macOS)
import AppKit
#endif

final class VisualSystemTests: XCTestCase {
    func testReadingRolesOnlyFillUnspecifiedLeading() {
        var font = OpenUIFont(size: 19, weight: .light, family: "Custom", letterSpacing: 0.03)
        font.monospacedDigits = true
        let title = font.resolved(for: .title)
        let body = font.resolved(for: .body)
        XCTAssertLessThan(title.lineHeight!, body.lineHeight!)
        XCTAssertEqual(title.size, font.size)
        XCTAssertEqual(title.weight, font.weight)
        XCTAssertEqual(title.family, font.family)
        XCTAssertEqual(title.letterSpacing, font.letterSpacing)
        XCTAssertTrue(title.monospacedDigits)
        font.lineSpacing = 0.4
        XCTAssertEqual(font.resolved(for: .title), font)
        font.lineHeight = 2
        XCTAssertEqual(font.resolved(for: .control), font)
    }

    func testCapsuleUsesActualBoundsAndRadiusOverrideRemainsIndependent() {
        for height in [CGFloat(32), 64] {
            let rect = CGRect(x: 0, y: 0, width: 180, height: height)
            let capsule = NativeButtonShape(radius: nil).path(in: rect)
            XCTAssertFalse(capsule.contains(CGPoint(x: 1, y: 1)))
            XCTAssertTrue(capsule.contains(CGPoint(x: 1, y: height / 2)))
            XCTAssertEqual(capsule.boundingRect, rect)
            XCTAssertTrue(NativeButtonShape(radius: 0).path(in: rect).contains(CGPoint(x: 1, y: 1)))
        }
    }

    func testWrappedActionLabelRemainsInsidePaintedCorners() {
        for height in [CGFloat(40), 96, 160] {
            let rect = CGRect(x: 0, y: 0, width: 180, height: height)
            let shape = NativeButtonShape(radius: nil,
                maximumRadius: NativeButtonShape.readableRadius(horizontal: 16, vertical: 8)).path(in: rect)
            for point in [CGPoint(x: 16.5, y: 8.5), CGPoint(x: 163.5, y: 8.5),
                          CGPoint(x: 16.5, y: height - 8.5), CGPoint(x: 163.5, y: height - 8.5)] {
                XCTAssertTrue(shape.contains(point), "A wrapped label must not extend beyond its button fill")
            }
        }
    }

    #if os(macOS)
    @MainActor func testSwipeCollectionsDoNotReserveAButtonRow() throws {
        _ = NSApplication.shared
        let library = try OpenUIStandardComponents.library()
        func height(_ source: String) -> CGFloat {
            let state = OpenUIState(schema: library.library.toSchema())
            state.setSource(source)
            XCTAssertTrue(state.errors.isEmpty, "\(state.errors)")
            return NSHostingView(rootView: OpenUIRenderer(state: state, registry: library.registry)
                .frame(width: 320)).fittingSize.height
        }
        let page = "[TextContent(\"One page\")]"
        XCTAssertEqual(height("root=Carousel([\(page)],\"card\")"),
                       height("root=Carousel([\(page),\(page)],\"card\")"), accuracy: 1)
        let first = "CompositeCardItem(\"a\",Text(\"text\",\"Object\"),[Text(\"text\",\"Details\")])"
        let second = "CompositeCardItem(\"b\",Text(\"text\",\"Object\"),[Text(\"text\",\"Details\")])"
        XCTAssertEqual(height("root=CompositeCardBlock([\(first)],\"carousel\",true)"),
                       height("root=CompositeCardBlock([\(first),\(second)],\"carousel\",true)"), accuracy: 1)
    }

    @MainActor func testQuotedCalloutKeepsVisibilityBindingAndNaturalCopyHeight() throws {
        _ = NSApplication.shared
        let library = try OpenUIStandardComponents.library()
        let state = OpenUIState(schema: library.library.toSchema())
        let copy = String(repeating: "完整说明文字保持自然换行，不截断阅读内容。", count: 5)
        state.setSource("root=Stack([Callout(\"warning\",\"补充说明\",\"\(copy)\",$shown)])\n$shown=true")
        XCTAssertTrue(state.errors.isEmpty)
        let host = NSHostingView(rootView: OpenUIRenderer(state: state, registry: library.registry).frame(width: 320))
        let visibleHeight = host.fittingSize.height
        XCTAssertGreaterThan(visibleHeight, 100)
        state.setState("$shown", value: .boolean(false))
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.03))
        XCTAssertLessThan(host.fittingSize.height, 1)
        state.setState("$shown", value: .boolean(true))
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.03))
        XCTAssertEqual(host.fittingSize.height, visibleHeight, accuracy: 1)
    }

    @MainActor func testRenderedMarkdownHeadingsKeepTheirScaleAcrossBodyOverrides() {
        _ = NSApplication.shared
        func height(_ text: String, bodySize: CGFloat = 16) -> CGFloat {
            NSHostingView(rootView: NativeMarkdownText(text: text,
                style: .init(font: OpenUIFont(size: bodySize))).frame(width: 600)).fittingSize.height
        }
        let h1 = height("# Same heading")
        let h2 = height("## Same heading")
        let h3 = height("### Same heading")
        let body = height("Same heading")
        XCTAssertGreaterThan(h1, h2 + 3)
        XCTAssertGreaterThan(h2, h3 + 1)
        XCTAssertGreaterThan(h3, body + 1)
        XCTAssertEqual(height("# Same heading", bodySize: 32), h1, accuracy: 1,
            "A body-font override must not change the heading's resolved point size")
    }

    @MainActor func testReadableInkAndNecessaryControlBoundariesOnDefaultSurfaces() throws {
        let theme = OpenUIThemeValues.defaults
        for name in [NSAppearance.Name.aqua, .darkAqua, .accessibilityHighContrastAqua, .accessibilityHighContrastDarkAqua] {
            let appearance = try XCTUnwrap(NSAppearance(named: name))
            func rgb(_ color: Color) throws -> [Double] {
                var value: NSColor?
                appearance.performAsCurrentDrawingAppearance { value = NSColor(color).usingColorSpace(.sRGB) }
                let c = try XCTUnwrap(value)
                return [Double(c.redComponent), Double(c.greenComponent), Double(c.blueComponent)]
            }
            func luminance(_ color: [Double]) -> Double {
                zip(color, [0.2126, 0.7152, 0.0722]).reduce(0) { result, pair in
                    let channel = pair.0 <= 0.04045 ? pair.0 / 12.92 : pow((pair.0 + 0.055) / 1.055, 2.4)
                    return result + channel * pair.1
                }
            }
            func contrast(_ foreground: Color, _ background: Color) throws -> Double {
                let a = luminance(try rgb(foreground)), b = luminance(try rgb(background))
                return (max(a, b) + 0.05) / (min(a, b) + 0.05)
            }
            for surface in [theme.background, theme.foreground, theme.sunk, theme.sunkLight, theme.highlight, theme.popoverBackground] {
                XCTAssertGreaterThanOrEqual(try contrast(theme.textNeutralSecondary, surface), 4.5)
                XCTAssertGreaterThanOrEqual(try contrast(theme.borderInteractive, surface), 3)
            }
        }
    }
    #endif
}
