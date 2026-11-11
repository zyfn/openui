import SwiftUI
import XCTest
@testable import OpenUISwiftUI

final class NativeAffordanceTests: XCTestCase {
    func testHeadersShareTheObjectTitleRoleRatherThanDisplayHeading() {
        let theme = OpenUIThemeValues.defaults
        let title = NativeHeadingStyle.titleFont(compact: false, theme: theme)
        XCTAssertEqual(title, theme.textHeadingXs)
        XCTAssertEqual(title, NativeHeadingStyle.titleFont(compact: true, theme: theme))
        XCTAssertEqual(title.size, 18)
        XCTAssertLessThan(title.size, theme.textHeadingMd.size)
        XCTAssertEqual(theme.textBodyDefaultHeavy.size, 17)
    }

    func testReadingScaleKeepsNumericAndControlSizesIndependent() {
        var theme = OpenUIThemeValues.defaults
        XCTAssertEqual(theme.textStyle(.body).font.size, 17)
        XCTAssertEqual(theme.textStyle(.supporting).font.size, 15)
        XCTAssertEqual(theme.textStyle(.caption).font.size, 13)
        XCTAssertEqual(theme.textStyle(.compactAction).font.size, 14)
        XCTAssertEqual(theme.textStyle(.action).font.size, 16)
        for (size, expected) in [("xs", 14.0), ("sm", 16.0), ("md", 16.0), ("lg", 18.0)] {
            XCTAssertEqual(theme.inlineFont(size, emphasized: true, numeric: true).size, expected)
        }
        theme.textBodyDefault = OpenUIFont(size: 24, weight: .regular)
        XCTAssertEqual(theme.inlineFont("sm").size, 24)
        XCTAssertEqual(theme.inlineFont("sm", numeric: true).size, 16)
        theme.textNumbersDefaultHeavy = OpenUIFont(size: 23, family: "HostNumeric", lineHeight: 1.8)
        XCTAssertEqual(theme.inlineFont("sm", emphasized: true, numeric: true).size, 23)
        XCTAssertEqual(theme.inlineFont("sm", numeric: true).family, "HostNumeric")
        XCTAssertEqual(theme.inlineFont("sm", numeric: true).lineHeight, 1.8)
        theme.textHeadingXs = OpenUIFont(size: 22, weight: .bold, lineHeight: 1.6)
        XCTAssertEqual(NativeHeadingStyle.titleFont(compact: false, theme: theme), theme.textHeadingXs)
        XCTAssertEqual(NativeHeadingStyle.titleFont(compact: true, theme: theme), theme.textHeadingXs)
    }

    func testCardBorderUsesSurfaceDefaultAndSupportsIndependentOverride() {
        let theme = OpenUIThemeValues.defaults
        let presentation = OpenUIPresentation()
        XCTAssertEqual(presentation.resolvedCardBorderColor(with: theme), theme.borderDefault)

        var customized = presentation
        customized.cardBorderColor = .red
        XCTAssertEqual(customized.resolvedCardBorderColor(with: theme), .red)
    }

    func testTabsOverflowHintRequiresActualOverflow() {
        XCTAssertFalse(NativeTabsOverflow.shouldShowHint(contentWidth: 200, viewportWidth: 240))
        XCTAssertFalse(NativeTabsOverflow.shouldShowHint(contentWidth: 240, viewportWidth: 240))
        XCTAssertFalse(NativeTabsOverflow.shouldShowHint(contentWidth: 241, viewportWidth: 240))
        XCTAssertTrue(NativeTabsOverflow.shouldShowHint(contentWidth: 242, viewportWidth: 240))
        XCTAssertTrue(NativeTabsOverflow.shouldShowHint(contentWidth: 100, viewportWidth: 0))
    }
}
