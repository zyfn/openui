import SwiftUI
import XCTest
@testable import OpenUISwiftUI

final class ChartPaletteTests: XCTestCase {
  func testIncreasingCountsPreservesExistingSeriesColors() {
    for count in 1...16 {
      let colors = NativeChartPalette.swatches(count: count)
      XCTAssertEqual(colors.count, count)
      XCTAssertEqual(Array(NativeChartPalette.swatches(count: count + 1).prefix(count)), colors)
      XCTAssertEqual(Set(colors.map(\.light)).count, count)
      XCTAssertEqual(Set(colors.map(\.dark)).count, count)
    }
    XCTAssertEqual(NativeChartPalette.swatches(count: 0).count, 1)
  }

  func testDefaultColorsRemainVisibleAgainstTheirChartBackgrounds() {
    func luminance(_ hex: UInt32) -> Double {
      let channels = [Double((hex >> 16) & 255), Double((hex >> 8) & 255), Double(hex & 255)].map { value -> Double in
        let c = value / 255
        return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
      }
      return channels[0] * 0.2126 + channels[1] * 0.7152 + channels[2] * 0.0722
    }
    for swatch in NativeChartPalette.swatches(count: 16) {
      XCTAssertGreaterThanOrEqual(1.05 / (luminance(swatch.light) + 0.05), 3)
      XCTAssertGreaterThanOrEqual((luminance(swatch.dark) + 0.05) / (luminance(0x111214) + 0.05), 4.5)
    }
  }

  func testExplicitHostOverridesAndEmptyFallbackRemainSupported() {
    var theme = OpenUITheme()
    XCTAssertEqual(theme.chartColors(forSeriesCount: 12).count, 12)
    theme.dataColors = [.red, .blue]
    XCTAssertEqual(theme.chartColors(forSeriesCount: 12), [.red, .blue])
    theme.dataColors = []
    XCTAssertEqual(theme.chartColors(forSeriesCount: 12), [theme.accent])
  }
}
