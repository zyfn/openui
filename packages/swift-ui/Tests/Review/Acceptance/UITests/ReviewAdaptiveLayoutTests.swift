import XCTest

/// Default acceptance: one phone, available width, normal text and the SDK theme.
/// Optional review controls remain available for manual exploration.
final class ReviewAdaptiveLayoutTests: ReviewTestCase {
  func testLearningGalleryRemainsCompactInTheChatBubble() {
    for bubble in [false, true] {
      let app = launch("scene-learning", bubble: bubble, language: "en")
      let first = app.buttons["openui.gallery.image.0"]
      let second = app.buttons["openui.gallery.image.1"]
      reveal(first, in: app)
      XCTAssertTrue(second.exists)
      XCTAssertEqual(first.frame.minY, second.frame.minY, accuracy: 2)
      XCTAssertEqual(first.frame.width, second.frame.width, accuracy: 2)
      let available = canvas(in: app).frame.width - (bubble ? 32 : 0)
      XCTAssertEqual(second.frame.maxX - first.frame.minX, available, accuracy: 2,
        "The same gallery should use its actual content width without leaving an empty column")
      XCTAssertLessThan(first.frame.height, 200)
      capture(app, name: bubble ? "learning-gallery-chat-bubble" : "learning-gallery-document")
      app.terminate()
    }
  }

  func testParisFewShotUsesTheSameSourceForCardsMapAndBudget() {
    let app = launch("paris-fewshot-source-change", language: "en")
    let description = app.staticTexts["Updated source record description"]
    XCTAssertTrue(description.firstMatch.waitForExistence(timeout: 5))
    let map = app.descendants(matching: .any).matching(identifier: "openui.map.canvas").firstMatch
    reveal(map, in: app)
    let place = app.buttons["openui.map.place.louvre"]
    XCTAssertTrue(place.waitForExistence(timeout: 5))
    XCTAssertTrue(place.label.contains("Updated source record description"))
    let price = app.staticTexts["€275"].firstMatch
    reveal(price, in: app)
    XCTAssertTrue(price.exists)
    let total = app.staticTexts["€1042"].firstMatch
    reveal(total, in: app)
    XCTAssertTrue(total.exists, "Changing only the input room price must update the card and recommended total")
    XCTAssertFalse(app.staticTexts["review.errors"].exists)
    capture(app, name: "paris-source-change-recomputed-budget")
    app.terminate()
  }

  func testLearningVisualCardsAreCompactAndOpenTheirOwnRecords() throws {
    let app = launch("scene-learning", inspect: true, language: "en")
    let cong = app.buttons["openui.gallery.image.0"]
    let bi = app.buttons["openui.gallery.image.1"]
    reveal(cong, in: app)
    XCTAssertTrue(bi.exists)
    XCTAssertEqual(cong.frame.minY, bi.frame.minY, accuracy: 2)
    XCTAssertEqual(cong.frame.width, bi.frame.width, accuracy: 2)
    XCTAssertEqual(cong.frame.height, bi.frame.height, accuracy: 2)
    XCTAssertLessThanOrEqual(cong.frame.height, 200)
    let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: cong)
    XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 8), .completed)
    capture(app, name: "learning-equal-gallery-previews")
    let position = cong.frame.minY
    cong.tap()
    let close = app.buttons["openui.gallery.close"]
    XCTAssertTrue(close.waitForExistence(timeout: 5))
    app.buttons["openui.gallery.thumbnail.1"].tap()
    XCTAssertTrue(app.staticTexts["2 / 2"].exists)
    capture(app, name: "learning-gallery-full-object")
    close.tap()
    XCTAssertEqual(cong.frame.minY, position, accuracy: 3)
    XCTAssertFalse(app.buttons["openui.gallery.options"].exists)
    for (label, target) in [("Cong", "72376"), ("Bi", "49371"), ("Same form, another era", "42751")] {
      let card = label == "Same form, another era"
        ? app.buttons[label].firstMatch : app.links[label].firstMatch
      reveal(card, in: app)
      XCTAssertLessThanOrEqual(card.frame.height, 300)
      card.tap()
      XCTAssertEqual(app.staticTexts["review.opened-url"].label,
        "https://www.metmuseum.org/art/collection/search/" + target)
    }
    capture(app, name: "learning-archaistic-card-and-conclusion")
    let firstSeries = app.buttons["openui.chart.legend.Liangzhu cong"]
    let secondSeries = app.buttons["openui.chart.legend.Qing archaistic cong"]
    reveal(firstSeries, in: app)
    XCTAssertTrue(secondSeries.exists)
    XCTAssertEqual(firstSeries.value as? String, "Visible")
    XCTAssertEqual(secondSeries.value as? String, "Visible")
    capture(app, name: "learning-two-series-height-chart")
    app.terminate()
  }

  func testOverviewFactsShareTheAvailableRowWidth() {
    let app = launch("scene-day-trip", language: "en")
    let labels = ["2 people", "1 day", "3 places"].map { app.staticTexts[$0].firstMatch }
    for label in labels { XCTAssertTrue(label.waitForExistence(timeout: 5)) }
    let available = app.windows.firstMatch.frame.width - 40
    let width = (available - 16) / 3
    for (index, label) in labels.enumerated() {
      XCTAssertEqual(label.frame.midX, 20 + width / 2 + CGFloat(index) * (width + 8), accuracy: 3)
      XCTAssertEqual(label.frame.midY, labels[0].frame.midY, accuracy: 2)
    }
    capture(app, name: "overview-equal-width-facts")
    app.terminate()
  }

  func testStayLinksLeaveTheRecommendedBudgetUnchanged() {
    let app = launch("scene-two-day-trip", inspect: true, language: "en")
    let title = app.staticTexts["Left Bank · garden double"].firstMatch
    reveal(title, in: app)
    let pagers = app.descendants(matching: .any)
      .matching(identifier: "openui.card-block.composite.pager")
    XCTAssertEqual(pagers.count, 3)
    let stays = pagers.element(boundBy: 2)
    stays.swipeLeft()
    let button = stays.buttons.matching(identifier: "Book").allElementsBoundByIndex.first { $0.isHittable && stays.frame.contains($0.frame) }
    XCTAssertNotNil(button)
    button?.tap()
    XCTAssertTrue(app.staticTexts["review.opened-url"].label.hasPrefix("https://www.booking.com/searchresults.html"))
    let total = app.staticTexts["€987"].firstMatch
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
    two.buttons["Day 2"].tap()
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

  func testComposedAttractionActionsReachTheSharedTrailingEdge() {
    let app = launch("scene-two-day-trip", language: "en")
    app.buttons["Day 2"].tap()
    let canvasEdge = canvas(in: app).frame.maxX
    let book = app.buttons["Book"].firstMatch
    reveal(book, in: app)
    let firstEdge = book.frame.maxX
    XCTAssertEqual(firstEdge, canvasEdge, accuracy: 24,
      "The text column should use the remaining row width, not its intrinsic title width")
    let secondBook = app.buttons.matching(identifier: "Book").element(boundBy: 1)
    reveal(secondBook, in: app)
    XCTAssertEqual(secondBook.frame.maxX, firstEdge, accuracy: 3,
      "Different copy lengths should keep the action on one trailing edge")
    XCTAssertFalse(app.staticTexts["review.errors"].exists)
    capture(app, name: "attraction-shared-trailing-edge")
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
