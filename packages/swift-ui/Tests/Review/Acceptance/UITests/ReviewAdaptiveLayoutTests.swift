import XCTest

/// Default acceptance: one phone, available width, normal text and the SDK theme.
/// Optional review controls remain available for manual exploration.
final class ReviewAdaptiveLayoutTests: ReviewTestCase {
  func testAttractionPlansExposePricesAndKeepBudgetTotalsConsistent() {
    let day = launch("scene-day-trip", language: "en")
    let museum = day.staticTexts["€64"].firstMatch
    reveal(museum, in: day)
    XCTAssertTrue(museum.exists)
    XCTAssertTrue(day.buttons["Book tickets"].firstMatch.exists)
    let cruise = day.staticTexts["€36"].firstMatch
    reveal(cruise, in: day)
    XCTAssertTrue(cruise.exists)
    let total = day.staticTexts["€240"].firstMatch
    reveal(total, in: day)
    XCTAssertTrue(total.exists)
    XCTAssertFalse(day.staticTexts["review.errors"].exists)
    capture(day, name: "one-day-attractions-budget")
    day.terminate()

    let two = launch("scene-two-day-trip", language: "en")
    two.buttons["Day 2 · Tower and Seine"].tap()
    let tower = two.staticTexts["€47"].firstMatch
    reveal(tower, in: two)
    XCTAssertTrue(tower.exists)
    capture(two, name: "two-day-attractions-second-day")
    XCTAssertFalse(two.staticTexts["review.errors"].exists)
    two.terminate()
  }

  func testBasicComposedStayKeepsAllCopyAndPriceToTheRightOfItsImage() {
    let app = launch("scene-two-day-trip", language: "en")
    let title = app.staticTexts["Left Bank · garden double"].firstMatch
    reveal(title, in: app)
    let price = app.staticTexts["€220"].firstMatch
    reveal(price, in: app)
    let photo = app.images["Left Bank · garden double"].firstMatch
    XCTAssertTrue(photo.exists)
    XCTAssertGreaterThan(photo.frame.width, 0)
    XCTAssertGreaterThanOrEqual(title.frame.minX, photo.frame.maxX + 8)
    XCTAssertGreaterThanOrEqual(price.frame.minX, photo.frame.maxX + 8)
    XCTAssertGreaterThanOrEqual(photo.frame.maxY + 2, price.frame.maxY)
    XCTAssertFalse(app.staticTexts["review.errors"].exists)
    capture(app, name: "basic-composition-stay-image-copy-footer")
    app.terminate()
  }

  func testRepresentativeCompositionsAtAvailableWidth() throws {
    let scenarios = try XCTUnwrap(try matrixReport()["scenarios"] as? [[String: Any]])
    for scenario in scenarios {
      let name = try XCTUnwrap((scenario["variants"] as? [String])?.first)
      let app = launch(name)
      let content = canvas(in: app)
      XCTAssertTrue(content.waitForExistence(timeout: 5))
      XCTAssertGreaterThan(content.frame.height, 0)
      XCTAssertEqual(content.frame.width, app.windows.firstMatch.frame.width - 40, accuracy: 2)
      XCTAssertFalse(app.staticTexts["review.errors"].exists)
      let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
        !app.descendants(matching: .any).matching(identifier: "openui.media.loading")
          .allElementsBoundByIndex.contains(where: { $0.isHittable })
      }, object: nil)
      XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 8), .completed)
      capture(app, name: "adaptive-" + name)
      app.terminate()
    }
  }
}
