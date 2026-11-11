import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif
import XCTest
@testable import OpenUISwiftUI

final class ChartPaletteTests: XCTestCase {
  func testRankedPolarChartsKeepCategoryColorsAcrossChartTypesAndValueChanges() {
    let categories = ["Home", "Food", "Transport", "Other"]
    let expected = ["Home": 0, "Food": 1, "Transport": 2, "Other": 3]
    for values in [[3000.0, 1800, 600, 1200], [300.0, 10, 500, 400]] {
      var input = NativeChartData()
      input.labels = categories
      input.slices = values
      for name in ["PieChart", "RadialChart", "SingleStackedBarChart"] {
        let prepared = input.prepared(for: name)
        let colors = Dictionary(uniqueKeysWithValues: zip(prepared.legendNames(for: name), prepared.colorIndices))
        XCTAssertEqual(colors, expected, "The category owns its color even when ranked polar order changes")
        let visible = prepared.excluding(["Food"], for: name)
        let remaining = Dictionary(uniqueKeysWithValues: zip(visible.legendNames(for: name), visible.colorIndices))
        XCTAssertEqual(remaining, expected.filter { $0.key != "Food" }, "Hiding a category cannot recolor the rest")
        if name != "SingleStackedBarChart" {
          XCTAssertEqual(prepared.slices, values.sorted(by: >), "Keep the existing ranked polar presentation")
        }
      }
      var bar = NativeChartData()
      bar.labels = ["Month"]
      bar.series = zip(categories, values).map { .init(name: $0.0, values: [$0.1]) }
      let prepared = bar.prepared(for: "BarChart")
      XCTAssertEqual(Dictionary(uniqueKeysWithValues: zip(prepared.legendNames(for: "BarChart"), prepared.colorIndices)), expected)
    }
  }

  func testIncreasingCountsPreservesExistingSeriesColors() {
    for count in 1...24 {
      let colors = NativeChartPalette.swatches(count: count)
      XCTAssertEqual(colors.count, count)
      XCTAssertEqual(Array(NativeChartPalette.swatches(count: count + 1).prefix(count)), colors)
      if count > 8 { XCTAssertEqual(colors[0], colors[8], "Reuse the platform palette without inventing tinted extensions") }
    }
    XCTAssertEqual(NativeChartPalette.swatches(count: 0).count, 1)
  }

  func testDefaultUsesNativeSystemColorsRatherThanCuratedRGBTones() {
    #if os(macOS)
    let expected = [NSColor.systemBlue, .systemOrange, .systemGreen, .systemPurple,
      .systemPink, .systemTeal, .systemIndigo, .systemCyan].map { Color(nsColor: $0) }
    #else
    let expected = [UIColor.systemBlue, .systemOrange, .systemGreen, .systemPurple,
      .systemPink, .systemTeal, .systemIndigo, .systemCyan].map { Color(uiColor: $0) }
    #endif
    XCTAssertEqual(NativeChartPalette.swatches(count: 8).map(\.color), expected)
  }

  func testExplicitHostOverridesAndEmptyFallbackRemainSupported() {
    var theme = OpenUIThemeValues()
    XCTAssertEqual(theme.chartColors(forSeriesCount: 12).count, 12)
    theme.defaultChartPalette = [.red, .blue]
    XCTAssertEqual(theme.chartColors(forSeriesCount: 12), [.red, .blue])
    theme.barChartPalette = [.green]
    XCTAssertEqual(theme.chartColors(forSeriesCount: 12, chartType: "BarChart"), [.green])
    XCTAssertEqual(theme.chartColors(forSeriesCount: 12, chartType: "LineChart"), [.red, .blue])
    theme.defaultChartPalette = []
    XCTAssertEqual(theme.chartColors(forSeriesCount: 12), [theme.interactiveAccentDefault])
  }
}
