import XCTest

/// Default acceptance: one phone, available width, normal text and the SDK theme.
/// Optional review controls remain available for manual exploration.
final class ReviewAdaptiveLayoutTests: ReviewTestCase {
  func testStayLinksLeaveTheRecommendedBudgetUnchanged() {
    let app = launch("scene-two-day-trip", inspect: true, language: "en")
    let title = app.staticTexts["Left Bank garden room · recommended"].firstMatch
    reveal(title, in: app)
    let pagers = app.descendants(matching: .any)
      .matching(identifier: "openui.card-block.composite.pager")
    XCTAssertEqual(pagers.count, 2)
    let stays = pagers.element(boundBy: 1)
    reveal(stays, in: app)
    stays.swipeLeft()
    let button = stays.buttons.matching(identifier: "Book").allElementsBoundByIndex.first { $0.isHittable && stays.frame.contains($0.frame) }
    XCTAssertNotNil(button)
    button?.tap()
    XCTAssertTrue(app.staticTexts["review.opened-url"].label.hasPrefix("https://www.booking.com/searchresults.html"))
    let total = app.staticTexts["€987"].firstMatch
    reveal(total, in: app)
    XCTAssertTrue(total.exists)
    capture(app, name: "trip-booking-link-fixed-budget")
    app.terminate()
  }

  func testAttractionPlansExposePricesAndKeepBudgetTotalsConsistent() {
    let day = launch("scene-day-trip", inspect: true, language: "en")
    let museum = day.staticTexts["€64"].firstMatch
    reveal(museum, in: day)
    XCTAssertTrue(museum.exists)
    XCTAssertTrue(day.buttons["Book"].firstMatch.exists)
    day.buttons["Book"].firstMatch.tap()
    XCTAssertEqual(day.staticTexts["review.opened-url"].label, "https://ticket.louvre.fr/en")
    let cruise = day.staticTexts["€36"].firstMatch
    reveal(cruise, in: day)
    XCTAssertTrue(cruise.exists)
    let total = day.staticTexts["€240"].firstMatch
    reveal(total, in: day)
    XCTAssertTrue(total.exists)
    let map = day.descendants(matching: .any).matching(identifier: "openui.map.canvas").firstMatch
    reveal(map, in: day)
    for id in ["louvre", "germain", "cruise", "deux-magots"] {
      XCTAssertTrue(day.descendants(matching: .any)
        .matching(identifier: "openui.map.marker." + id).firstMatch.waitForExistence(timeout: 5))
    }
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

  func testBasicComposedAttractionKeepsAllCopyAndPriceToTheRightOfItsImage() {
    let app = launch("scene-day-trip", language: "en")
    let title = app.staticTexts["The Louvre"].firstMatch
    reveal(title, in: app)
    let price = app.staticTexts["€64"].firstMatch
    reveal(price, in: app)
    let photo = app.images["The Louvre"].firstMatch
    XCTAssertTrue(photo.exists)
    XCTAssertGreaterThan(photo.frame.width, 0)
    XCTAssertGreaterThanOrEqual(title.frame.minX, photo.frame.maxX + 8)
    XCTAssertGreaterThanOrEqual(price.frame.minX, photo.frame.maxX + 8)
    XCTAssertGreaterThanOrEqual(photo.frame.maxY + 2, price.frame.maxY)
    XCTAssertFalse(app.staticTexts["review.errors"].exists)
    capture(app, name: "basic-composition-attraction-image-copy-footer")
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
