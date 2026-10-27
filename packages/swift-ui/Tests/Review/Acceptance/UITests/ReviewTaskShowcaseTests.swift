import UIKit
import XCTest

final class ReviewTaskShowcaseTests: ReviewTestCase {
  @objc func testTwoDayOverviewAndDailyViewsKeepTheMapIndependent() {
    let app = launch("scene-two-day-trip", language: "en")
    let heading = app.staticTexts["Your two-day itinerary"]
    let summary = app.staticTexts["Day 1 · Art and the Left Bank"]
    XCTAssertTrue(app.images["openui.icon.move-right"].firstMatch.exists,
      "Flight cards should expose a direction between departure and arrival")
    reveal(heading, in: app)
    XCTAssertTrue(summary.exists)
    XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@",
      "10:20 arrival, the Louvre in the afternoon")).firstMatch.exists)
    XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@",
      "18:30 return from CDG")).firstMatch.exists)
    XCTAssertLessThan(app.staticTexts["Flights, each way"].frame.minY, heading.frame.minY)
    XCTAssertLessThan(heading.frame.maxY, app.buttons["Overview"].frame.minY,
      "The itinerary title should introduce the view switcher")
    let firstDay = app.buttons["Day 1"]
    reveal(firstDay, in: app)
    firstDay.tap()
    XCTAssertFalse(summary.exists)
    XCTAssertTrue(heading.exists)
    XCTAssertTrue(app.staticTexts["5 November · Art and the Left Bank"].exists)
    XCTAssertTrue(app.staticTexts["10:20 arrival at CDG. Transfer to the Left Bank, leave bags and have lunch."].exists)
    XCTAssertTrue(app.staticTexts["After dinner, check in: Left Bank · garden double"].exists)
    XCTAssertTrue(app.staticTexts["Food & a pause"].exists)
    capture(app, name: "trip-day-one-reading-hierarchy")
    let secondDay = app.buttons["Day 2"]
    reveal(secondDay, in: app)
    secondDay.tap()
    XCTAssertFalse(summary.exists)
    XCTAssertTrue(app.staticTexts["6 November · Tower and Seine"].exists)
    XCTAssertTrue(app.staticTexts["08:30 check out, arrange bag storage and head to the tower."].exists)
    XCTAssertTrue(app.staticTexts["After lunch, collect bags and leave for CDG at 15:00 for the 18:30 flight."].exists)
    XCTAssertTrue(app.staticTexts["€47"].exists)
    let map = app.descendants(matching: .any).matching(identifier: "openui.map.canvas").firstMatch
    reveal(map, in: app)
    XCTAssertTrue(map.exists, "The map remains its own section after the day view changes")
    let overview = app.buttons["Overview"]
    reveal(overview, in: app)
    overview.tap()
    XCTAssertTrue(summary.exists)
    XCTAssertFalse(app.staticTexts["6 November · Tower and Seine"].exists)
    XCTAssertEqual(app.descendants(matching: .any)
      .matching(identifier: "openui.card-block.composite.pager").count, 3,
      "Two flight groups and one stay group remain shared across all day views")
    XCTAssertFalse(app.staticTexts["review.errors"].exists)
    app.terminate()
  }

  func testSpendingRangeChangesChartAndTotalTogether() {
    let app = launch("scene-spending", language: "en")
    XCTAssertTrue(app.staticTexts["¥6600"].exists)
    let chart = app.descendants(matching: .any)
      .matching(identifier: "openui-chart-BarChart").firstMatch
    reveal(chart, in: app)
    let documentHeight = canvas(in: app).frame.height
    chart.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.45)).tap()
    let tooltip = app.descendants(matching: .any)
      .matching(identifier: "openui-chart-inspection").firstMatch
    XCTAssertTrue(tooltip.waitForExistence(timeout: 5))
    XCTAssertEqual(canvas(in: app).frame.height, documentHeight, accuracy: 2,
      "Chart details stay anchored instead of inserting another document row")
    capture(app, name: "spending-anchored-chart-details")
    let donut = app.descendants(matching: .any)
      .matching(identifier: "openui-chart-PieChart").firstMatch
    chart.swipeUp()
    reveal(donut, in: app)
    XCTAssertTrue(donut.isHittable, "Chart inspection must not trap document scrolling")
    let quarter = app.buttons["Three-month total"]
    reveal(quarter, in: app)
    quarter.tap()
    XCTAssertTrue(app.staticTexts["¥18000"].exists)
    app.buttons["October only"].tap()
    XCTAssertTrue(app.staticTexts["¥6600"].exists)
    XCTAssertFalse(app.staticTexts["review.errors"].exists)
    capture(app, name: "spending-period-and-budget")
    app.terminate()
  }

  func testProductLinkUsesTheSdkAction() {
    let app = launch("scene-shopping", inspect: true, language: "en")
    let button = app.buttons["View product"].firstMatch
    reveal(button, in: app)
    button.tap()
    XCTAssertEqual(app.staticTexts["review.opened-url"].label,
      "https://www.nikonusa.com/p/z-50/1632")
    XCTAssertFalse(app.staticTexts["review.errors"].exists)
    app.terminate()
  }

  func testGatheringChoiceUpdatesTheSharedBudget() {
    let app = launch("scene-gathering", language: "en")
    let pager = app.descendants(matching: .any)
      .matching(identifier: "openui.card-block.composite.pager").firstMatch
    let title = app.staticTexts["Window-side shared table"]
    reveal(title, in: app)
    pager.swipeLeft()
    let selected = app.staticTexts["Quiet private room"]
    XCTAssertTrue(selected.exists)
    let book = pager.buttons.matching(identifier: "Book").allElementsBoundByIndex.first {
      $0.isHittable && pager.frame.contains($0.frame)
    }
    XCTAssertNotNil(book)
    book?.tap()
    let preview = app.alerts.firstMatch
    XCTAssertTrue(preview.waitForExistence(timeout: 5))
    preview.buttons["Done"].tap()
    XCTAssertTrue(app.staticTexts["¥260"].exists)
    XCTAssertFalse(app.staticTexts["review.errors"].exists)
    app.terminate()
  }
}
