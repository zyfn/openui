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
      XCTAssertEqual(
        app.staticTexts[names[0]].frame.minY, app.staticTexts[names[1]].frame.minY, accuracy: 4,
        "Cards in the same row align at the top, despite different subtitle lengths")
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
      capture(app, name: "media-slot-" + mode)
      app.terminate()
    }
  }
}
