import UIKit
import XCTest

/// Geometry assertions complement screenshots; they do not bless visual taste.
final class ReviewCompositionGeometryTests: ReviewTestCase {
  private func check(_ app: XCUIApplication, following label: String, prices: [String]) {
    let pager = app.descendants(matching: .any)
      .matching(identifier: "openui.card-block.composite.pager").firstMatch
    let following = app.staticTexts[label].firstMatch
    XCTAssertTrue(pager.waitForExistence(timeout: 6))
    XCTAssertTrue(following.exists)
    let settled = XCTNSPredicateExpectation(
      predicate: NSPredicate { _, _ in
        let footerBottom =
          prices.compactMap { price -> CGFloat? in
            let item = app.staticTexts[price].firstMatch
            return item.exists ? item.frame.maxY : nil
          }.max() ?? pager.frame.maxY
        return following.frame.minY >= max(pager.frame.maxY, footerBottom) + 22
      }, object: nil)
    XCTAssertEqual(
      XCTWaiter.wait(for: [settled], timeout: 5), .completed,
      "The following section must remain below the viewport and every page footer plus the declared gap")
  }

  func testMountedCarouselGrowthAndPageChangesKeepFollowingSectionClear() {
    let app = XCUIApplication(bundleIdentifier: "dev.swiftui.component-review")
    app.launchArguments = ["--stream-case", "resizing-carousel", "--language", "en"]
    app.launch()
    check(app, following: "Following section", prices: ["100", "200", "300"])
    let following = app.staticTexts["Following section"]
    let before = following.frame.minY
    let toggle = app.buttons["Grow details"]
    reveal(toggle, in: app)
    toggle.tap()
    let grown = XCTNSPredicateExpectation(
      predicate: NSPredicate { _, _ in
        following.frame.minY > before + 40
      }, object: nil)
    XCTAssertEqual(XCTWaiter.wait(for: [grown], timeout: 5), .completed)
    let pager = app.descendants(matching: .any)
      .matching(identifier: "openui.card-block.composite.pager").firstMatch
    for index in 0..<3 {
      check(app, following: "Following section", prices: ["100", "200", "300"])
      capture(app, name: "composition-grown-page-\(index)")
      if index < 2 { pager.swipeLeft() }
    }
    app.terminate()
  }

  func testUnchangedSavedCarouselAfterStreamingCompletion() throws {
    guard Bundle(for: Self.self).url(forResource: "StreamProgram", withExtension: "openui") != nil else {
      throw XCTSkip("Provide a saved source through --stream-program")
    }
    let app = XCUIApplication(bundleIdentifier: "dev.swiftui.component-review")
    app.launchArguments = ["--stream-case", "original", "--stream-auto", "--language", "zh-Hans"]
    app.launch()
    let next = app.buttons["stream.next"]
    XCTAssertTrue(next.waitForExistence(timeout: 8))
    let finished = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == false"), object: next)
    XCTAssertEqual(XCTWaiter.wait(for: [finished], timeout: 45), .completed)
    app.buttons["stream.complete"].tap()
    XCTAssertFalse(app.staticTexts["review.errors"].exists)
    let pager = app.descendants(matching: .any)
      .matching(identifier: "openui.card-block.composite.pager").firstMatch
    for index in 0..<3 {
      check(app, following: "明晚住宿 · 10月27日入住1晚", prices: ["545 元", "490 元", "680 元"])
      capture(app, name: "composition-original-page-\(index)")
      if index < 2 { pager.swipeLeft() }
    }
    app.terminate()
  }
}

extension ReviewCompositionGeometryTests {
  func testCompactSnippetReplaysKeepNamesReadable() throws {
    guard Bundle(for: Self.self).url(forResource: "ReviewExamples", withExtension: "json") != nil else {
      throw XCTSkip("Provide the saved snippet examples")
    }
    for (id, names) in [("snippet-media", ["湖畔小住", "城中旅店"]), ("snippet-values", ["时长", "景点"])] {
      let app = launch(id)
      for name in names {
        let label = app.staticTexts[name].firstMatch
        XCTAssertTrue(label.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(
          label.frame.width, label.frame.height,
          "Short labels must not collapse into vertical character strips")
      }
      let values = id == "snippet-media" ? ["¥128", "双床房"] : ["2小时", "3处"]
      for (name, value) in zip(names, values) {
        let lhs = app.staticTexts[name].firstMatch
        let rhs = app.staticTexts[value].firstMatch
        XCTAssertGreaterThan(
          rhs.frame.minX, lhs.frame.maxX,
          "Snippet preserves its left-label/right-value relationship")
      }
      capture(app, name: id + "-readable")
      app.terminate()
    }
  }

  func testMediaSlotGeometrySurvivesLoadingAndFailure() throws {
    guard Bundle(for: Self.self).url(forResource: "ReviewExamples", withExtension: "json") != nil else {
      throw XCTSkip("Provide the media slot fixture")
    }
    var loaded: [String: CGSize] = [:]
    for mode in ["loaded", "loading", "unavailable"] {
      let app = launch("media-slot-geometry", media: mode)
      if mode == "loaded" {
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
          !app.descendants(matching: .any).matching(identifier: "openui.media.loading")
            .allElementsBoundByIndex.contains(where: { $0.isHittable })
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 8), .completed)
      }
      for name in ["Thumbnail slot", "Cover slot", "Backdrop slot"] {
        let image = app.images[name].firstMatch
        XCTAssertTrue(image.waitForExistence(timeout: 8))
        if mode == "loaded" {
          loaded[name] = image.frame.size
        } else {
          let reference = try XCTUnwrap(loaded[name])
          XCTAssertEqual(image.frame.width, reference.width, accuracy: 2)
          XCTAssertEqual(
            image.frame.height, reference.height, accuracy: 2,
            "Resource state must not replace the declared image slot with a text block")
        }
      }
      XCTAssertFalse(app.buttons["openui.media.retry"].exists)
      XCTAssertFalse(app.staticTexts["Image unavailable"].exists)
      capture(app, name: "media-slot-" + mode)
      app.terminate()
    }
  }
}

extension ReviewCompositionGeometryTests {
  func testSavedBudgetUsesAlignedValuesAndCompactMetrics() throws {
    guard Bundle(for: Self.self).url(forResource: "ReviewExamples", withExtension: "json") != nil else {
      throw XCTSkip("Provide the unchanged budget program")
    }
    let app = launch("budget-original")
    let amounts = ["¥490", "¥148", "¥0", "¥70–110", "¥150–250", "¥858 – 1,048"]
    let first = app.staticTexts[amounts[0]].firstMatch
    XCTAssertTrue(first.waitForExistence(timeout: 6))
    for amount in amounts {
      let value = app.staticTexts[amount].firstMatch
      XCTAssertTrue(value.exists)
      XCTAssertEqual(
        value.frame.maxX, first.frame.maxX, accuracy: 2,
        "A value's length must not move the right edge of the list")
    }
    let label = app.staticTexts["机票 KN5985（实查）"].firstMatch
    XCTAssertLessThan(
      label.frame.height, first.frame.height * 1.5,
      "A short value should leave the label enough room instead of reserving half the row")
    let low = app.staticTexts["经济走法"].firstMatch
    let high = app.staticTexts["舒适走法"].firstMatch
    reveal(high, in: app)
    XCTAssertEqual(low.frame.minY, high.frame.minY, accuracy: 3)
    XCTAssertFalse(app.staticTexts["review.errors"].exists)
    capture(app, name: "budget-original-aligned")
    app.terminate()
  }
}