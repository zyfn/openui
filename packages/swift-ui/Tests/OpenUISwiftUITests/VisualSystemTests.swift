import SwiftUI
import XCTest
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

    #if os(macOS)
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
