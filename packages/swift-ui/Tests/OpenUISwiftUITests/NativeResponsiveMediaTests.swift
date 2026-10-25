import SwiftUI
import XCTest
@testable import OpenUISwiftUI

final class NativeResponsiveMediaTests: XCTestCase {
    func testPreviewGeometryRetainsEveryValidSourceAspectRatio() {
        for size in [CGSize(width: 1600, height: 900), CGSize(width: 1200, height: 1600),
                     CGSize(width: 1200, height: 1800), CGSize(width: 1200, height: 12000)] {
            XCTAssertEqual(NativeMediaPreview.aspectRatio(sourceSize: size), size.width / size.height, accuracy: 0.0001)
        }
        for size: CGSize? in [nil, .zero, CGSize(width: CGFloat.infinity, height: 100)] {
            XCTAssertTrue(NativeMediaPreview.aspectRatio(sourceSize: size).isFinite)
        }
    }

    private func text(advance: CGFloat, lineHeight: CGFloat = 20) -> (CGFloat) -> CGSize {
        { width in CGSize(width: min(width, advance), height: ceil(advance / max(1, width)) * lineHeight) }
    }

    func testLongCopyWrapsBesideHorizontalMediaWithoutCreatingWidthOverflow() {
        let result = NativeMediaRowPlacement.measure(width: 320, media: CGSize(width: 80, height: 80),
            gap: 12, axis: .horizontal, centered: true,
            text: text(advance: 12000))
        XCTAssertFalse(result.stacked)
        XCTAssertEqual(result.text.width, 228)
        XCTAssertEqual(result.size.width, 320)
        XCTAssertGreaterThan(result.size.height, 80)
    }

    func testExplicitHorizontalMediaKeepsItsDimensionsAndOverflowIsReachable() {
        let result = NativeMediaRowPlacement.measure(width: 120, media: CGSize(width: 180, height: 180),
            gap: 12, axis: .horizontal, centered: true,
            text: text(advance: 600))
        XCTAssertFalse(result.stacked)
        XCTAssertEqual(result.media.size, CGSize(width: 180, height: 180))
        XCTAssertGreaterThan(result.text.width, 0)
        XCTAssertGreaterThanOrEqual(result.text.minX, result.media.maxX + 12)
        XCTAssertGreaterThan(result.size.width, 120)
        XCTAssertGreaterThanOrEqual(result.size.width, result.text.maxX)
        XCTAssertGreaterThanOrEqual(result.size.height, result.text.maxY)
    }

    func testThumbnailAndTextColumnStayConsistentWhenCopyLengthChanges() {
        for width in [CGFloat(240), CGFloat(320)] {
            let results = [CGFloat(40), CGFloat(1200), CGFloat(12000)].map { advance in
                NativeMediaRowPlacement.measure(width: width, media: CGSize(width: 112, height: 112),
                    gap: 12, axis: .horizontal, centered: false, text: text(advance: advance))
            }
            for result in results {
                XCTAssertEqual(result.media.size, CGSize(width: 112, height: 112))
                XCTAssertEqual(result.text.minX, 124)
                XCTAssertEqual(result.text.width, width - 124)
                XCTAssertEqual(result.size.width, width)
                XCTAssertFalse(result.stacked)
            }
            XCTAssertGreaterThan(results[2].size.height, results[0].size.height)
        }
    }

    func testExplicitVerticalMediaDoesNotSilentlyShrinkToTheViewport() {
        let result = NativeMediaRowPlacement.measure(width: 120, media: CGSize(width: 180, height: 180),
            gap: 12, axis: .vertical, centered: false,
            text: text(advance: 300))
        XCTAssertTrue(result.stacked)
        XCTAssertEqual(result.media.size, CGSize(width: 180, height: 180))
        XCTAssertGreaterThanOrEqual(result.text.minY, result.media.maxY + 12)
        XCTAssertEqual(result.size.width, 180)
    }
}
