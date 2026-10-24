import SwiftUI
import XCTest
@testable import OpenUISwiftUI

final class NativeLayoutSemanticsTests: XCTestCase {
  func testAroundAndEvenlyHaveDifferentEdgeSpaceWithoutChangingContentSize() {
    let sizes = [CGSize(width: 40, height: 20), CGSize(width: 40, height: 20)]
    let around = OpenUIFlowPlacement.frames(sizes: sizes, width: 200, gap: 8, align: "start", justify: "around", wrap: false)
    let evenly = OpenUIFlowPlacement.frames(sizes: sizes, width: 200, gap: 8, align: "start", justify: "evenly", wrap: false)
    XCTAssertNotEqual(around[0].minX, evenly[0].minX)
    XCTAssertEqual(around[0].minX * 2, around[1].minX - around[0].maxX - 8, accuracy: 0.001)
    XCTAssertEqual(evenly[0].minX, evenly[1].minX - evenly[0].maxX - 8, accuracy: 0.001)
    for row in [around, evenly] {
      XCTAssertEqual(row[0].minX, 200 - row[1].maxX, accuracy: 0.001)
      XCTAssertEqual(row.map(\.size), sizes)
    }
  }
  func testMixedFontBaselinesAlignWithinEachWrappedLine() {
    let sizes = [CGSize(width: 80, height: 28), CGSize(width: 80, height: 50), CGSize(width: 100, height: 32)]
    let baselines: [CGFloat] = [21, 37, 24]
    for width in [CGFloat(180), CGFloat(500)] {
      let frames = OpenUIFlowPlacement.frames(sizes: sizes, width: width, gap: 12, align: "baseline", justify: "start", baselines: baselines)
      XCTAssertEqual(frames[0].minY + baselines[0], frames[1].minY + baselines[1], accuracy: 0.001)
      if width == 180 { XCTAssertGreaterThanOrEqual(frames[2].minY, max(frames[0].maxY, frames[1].maxY) + 12) }
      else { XCTAssertEqual(frames[2].minY + baselines[2], frames[0].minY + baselines[0], accuracy: 0.001) }
    }
  }
  func testStretchFollowsMeasuredLineHeightAndParentCrossExtent() {
    let sizes = [CGSize(width: 60, height: 20), CGSize(width: 90, height: 70)]
    let row = OpenUIFlowPlacement.frames(sizes: sizes, width: 300, gap: 12, align: "stretch", justify: "start", wrap: false, crossExtent: 100)
    XCTAssertEqual(row.map(\.height), [100, 100])
    let narrow = OpenUIFlowPlacement.frames(sizes: sizes, width: 100, gap: 12, align: "stretch", justify: "start")
    XCTAssertEqual(narrow.map(\.height), [20, 70])
    XCTAssertEqual(narrow[1].minY, 32)
  }
  func testPinnedLucideNamesAndCategoryFallbacksHaveDrawablePaths() {
    XCTAssertEqual(NativeIconCatalog.catalog.version, "0.562.0")
    XCTAssertEqual(NativeIconCatalog.catalog.icons.count, 1912)
    for name in ["utensils-crossed", "soup", "wheat"] {
      XCTAssertEqual(NativeIconCatalog.resolvedName(name, category: nil), name)
    }
    XCTAssertEqual(NativeIconCatalog.resolvedName("not-an-icon", category: " FOOD-BEVERAGE "), "cooking-pot")
    XCTAssertEqual(NativeIconCatalog.resolvedName("not-an-icon", category: nil), "circle-dot")
    for (name, primitives) in NativeIconCatalog.catalog.icons {
      XCTAssertFalse(primitives.isEmpty, name)
      XCTAssertTrue(primitives.allSatisfy { !$0.path.isEmpty && !$0.path.boundingRect.isInfinite }, name)
    }
  }
}
