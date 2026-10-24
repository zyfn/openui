import SwiftUI
import XCTest
@testable import OpenUISwiftUI

final class NativeResponsiveMediaTests: XCTestCase {
    private func text(advance: CGFloat, lineHeight: CGFloat = 20) -> (CGFloat) -> CGSize {
        { width in CGSize(width: min(width, advance), height: ceil(advance / max(1, width)) * lineHeight) }
    }

    func testExplicitHorizontalMediaKeepsItsDimensionsAndOverflowIsReachable() {
        let result = NativeMediaRowPlacement.measure(width: 120, media: CGSize(width: 180, height: 180),
            gap: 12, axis: .horizontal, resizesMedia: false, minimumMediaSide: 44, centered: true,
            text: text(advance: 600))
        XCTAssertFalse(result.stacked)
        XCTAssertEqual(result.media.size, CGSize(width: 180, height: 180))
        XCTAssertGreaterThan(result.text.width, 0)
        XCTAssertGreaterThanOrEqual(result.text.minX, result.media.maxX + 12)
        XCTAssertGreaterThan(result.size.width, 120)
        XCTAssertGreaterThanOrEqual(result.size.width, result.text.maxX)
        XCTAssertGreaterThanOrEqual(result.size.height, result.text.maxY)
    }

    func testFlexibleThumbnailGrowsAndShrinksWithTheRenderedCopy() {
        func layout(_ advance: CGFloat) -> NativeMediaRowPlacement.Result {
            NativeMediaRowPlacement.measure(width: 320, media: CGSize(width: 112, height: 112),
                gap: 12, axis: .adaptive, resizesMedia: true, minimumMediaSide: 44, centered: false,
                text: text(advance: advance))
        }
        let short = layout(40)
        let long = layout(1200)
        XCTAssertGreaterThan(long.media.height, short.media.height)
        XCTAssertEqual(short.media.width, short.media.height)
        XCTAssertEqual(long.media.width, long.media.height)
        XCTAssertLessThanOrEqual(long.media.width, 112)
        XCTAssertFalse(short.stacked)
        XCTAssertFalse(long.stacked)
        XCTAssertEqual(layout(40).media, short.media)
    }

    func testAdaptiveDirectionDependsOnMeasuredContentAtTheSameWidth() {
        func layout(_ advance: CGFloat) -> NativeMediaRowPlacement.Result {
            NativeMediaRowPlacement.measure(width: 240, media: CGSize(width: 112, height: 112),
                gap: 12, axis: .adaptive, resizesMedia: true, minimumMediaSide: 44, centered: false,
                text: text(advance: advance))
        }
        let short = layout(40)
        let long = layout(12000)
        XCTAssertFalse(short.stacked)
        XCTAssertTrue(long.stacked, "Content measurements, not a 240-point breakpoint, determine reflow")
        XCTAssertGreaterThanOrEqual(long.text.minY, long.media.maxY + 12)
        XCTAssertEqual(long.text.width, 240)
        XCTAssertEqual(long.size.width, 240)
    }

    func testExplicitVerticalMediaDoesNotSilentlyShrinkToTheViewport() {
        let result = NativeMediaRowPlacement.measure(width: 120, media: CGSize(width: 180, height: 180),
            gap: 12, axis: .vertical, resizesMedia: false, minimumMediaSide: 44, centered: false,
            text: text(advance: 300))
        XCTAssertTrue(result.stacked)
        XCTAssertEqual(result.media.size, CGSize(width: 180, height: 180))
        XCTAssertGreaterThanOrEqual(result.text.minY, result.media.maxY + 12)
        XCTAssertEqual(result.size.width, 180)
    }
}
