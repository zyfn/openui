import UIKit
import XCTest

final class ReviewTaskShowcaseTests: ReviewTestCase {
  @objc func testTwoDayOverviewAndDailyViewsKeepTheMapIndependent() {
    let app = launch("scene-two-day-trip", language: "en")
    XCTAssertTrue(app.staticTexts["The two-day route"].exists)
    XCTAssertTrue(app.staticTexts["Louvre → Saint-Germain"].exists)
    app.buttons["Day 2"].tap()
    XCTAssertFalse(app.staticTexts["The two-day route"].exists)
    XCTAssertTrue(app.staticTexts["Day 2 · Tower and Seine"].exists)
    XCTAssertTrue(app.staticTexts["€47"].exists)
    let map = app.descendants(matching: .any).matching(identifier: "openui.map.canvas").firstMatch
    reveal(map, in: app)
    XCTAssertTrue(map.exists, "The map remains its own section after the day view changes")
    let overview = app.buttons["Overview"]
    reveal(overview, in: app)
    overview.tap()
    XCTAssertTrue(app.staticTexts["The two-day route"].exists)
    XCTAssertFalse(app.staticTexts["Day 2 · Tower and Seine"].exists)
    XCTAssertFalse(app.staticTexts["review.errors"].exists)
    app.terminate()
  }

  func testSpendingRangeChangesChartAndTotalTogether() {
    let app = launch("scene-spending", language: "en")
    XCTAssertTrue(app.staticTexts["¥6600"].exists)
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
