import UIKit
import XCTest

final class ReviewChartVisualTests: ReviewTestCase {
  func testChartAxisStaysReadableAtNarrowWidthsAndLargeText() {
    let conditions = [
      (width: "narrow", large: false, dark: false, name: "chart-axis-240-light"),
      (width: "available", large: true, dark: true, name: "chart-axis-large-dark"),
      (width: "narrow", large: true, dark: true, name: "chart-axis-240-large-dark"),
    ]
    for condition in conditions where acceptsLargeText || !condition.large {
      let app = launch("data", dark: condition.dark, large: condition.large,
        width: condition.width, theme: "accent")
      let chart = app.descendants(matching: .any)
        .matching(identifier: "openui-chart-BarChart").firstMatch
      XCTAssertTrue(chart.waitForExistence(timeout: 5))
      reveal(chart, in: app)
      let content = canvas(in: app)
      if condition.width == "narrow" {
        XCTAssertEqual(content.frame.width, 240, accuracy: 2)
      }
      XCTAssertGreaterThan(chart.frame.width, 0)
      XCTAssertGreaterThanOrEqual(chart.frame.minX, content.frame.minX - 2)
      XCTAssertLessThanOrEqual(chart.frame.maxX, content.frame.maxX + 2)
      // Axis thinning changes visible labels only, never the complete dataset
      // offered by Canvas to VoiceOver.
      let firstDay = app.staticTexts.matching(
        NSPredicate(format: "label BEGINSWITH %@", "周一:")).firstMatch
      let finalDay = app.staticTexts.matching(
        NSPredicate(format: "label BEGINSWITH %@", "周五:")).firstMatch
      XCTAssertTrue(firstDay.exists)
      XCTAssertTrue(finalDay.exists)
      XCTAssertFalse(app.staticTexts["review.errors"].exists)
      capture(app, name: condition.name)
      app.terminate()
    }
  }

  func testVerticalSwipeStartingInsideChartRevealsTheCompleteDonut() {
    let app = launch("data", theme: "accent")
    let bar = app.descendants(matching: .any)
      .matching(identifier: "openui-chart-BarChart").firstMatch
    XCTAssertTrue(bar.waitForExistence(timeout: 5))
    reveal(bar, in: app)
    let before = bar.frame.minY
    // The original failure started in a chart: its zero-distance exclusive
    // drag consumed every parent-scroll attempt without moving the page.
    bar.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
      .press(forDuration: 0.05,
        thenDragTo: bar.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.15)))
    let hierarchy = XCTAttachment(string: app.debugDescription)
    hierarchy.name = "chart-scroll-hierarchy"
    hierarchy.lifetime = .keepAlways
    add(hierarchy)
    XCTAssertLessThan(bar.frame.minY, before - 40,
      "A vertical swipe originating in plotted content must scroll its containing page")
    let donut = app.descendants(matching: .any)
      .matching(identifier: "openui-chart-PieChart").firstMatch
    XCTAssertTrue(donut.exists)
    reveal(donut, in: app)
    let viewport = app.scrollViews["review.surface"].frame
      .intersection(app.windows.firstMatch.frame).insetBy(dx: 4, dy: 8)
    XCTAssertTrue(viewport.contains(donut.frame),
      "The complete unchanged-size donut must be reachable after scrolling through another chart")
    XCTAssertEqual(donut.frame.height, 250, accuracy: 2)
    XCTAssertFalse(app.staticTexts["review.errors"].exists)
    capture(app, name: "chart-scroll-reveals-complete-donut")
    app.terminate()
  }


  func testPressThenVerticalInspectionKeepsChartPositionAndClearsOnRelease() {
    let app = launch("data", theme: "accent")
    let chart = app.descendants(matching: .any)
      .matching(identifier: "openui-chart-BarChart").firstMatch
    XCTAssertTrue(chart.waitForExistence(timeout: 5))
    reveal(chart, in: app)
    let before = chart.frame.minY
    // A deliberate hold activates inspection before a vertical movement. The
    // existing fast-swipe test separately proves ordinary movement scrolls.
    // XCTest's recording retains the transient selection for visual review;
    // these assertions verify position and release cleanup, not tooltip text.
    chart.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
      .press(forDuration: 0.35,
        thenDragTo: chart.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3)))
    XCTAssertEqual(chart.frame.minY, before, accuracy: 2,
      "An activated inspection can move vertically without moving the containing page")
    XCTAssertFalse(app.staticTexts["openui-chart-inspection"].exists,
      "Releasing the inspection gesture clears its transient label")
    XCTAssertFalse(app.staticTexts["review.errors"].exists)
    capture(app, name: "chart-inspection-released")
    app.terminate()
  }

}
