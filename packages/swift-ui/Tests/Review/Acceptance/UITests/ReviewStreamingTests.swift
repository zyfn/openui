import UIKit
import XCTest

final class ReviewStreamingTests: ReviewTestCase {
  private func stream(_ mode: String, language: String = "zh-Hans") -> XCUIApplication {
    continueAfterFailure = false
    let app = XCUIApplication(bundleIdentifier: "dev.swiftui.component-review")
    app.launchArguments = ["--stream-case", mode, "--language", language, "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
    app.launch()
    XCTAssertTrue(app.buttons["stream.next"].waitForExistence(timeout: 10))
    let errors = app.staticTexts["review.errors"]
    XCTAssertFalse(errors.exists, errors.exists ? errors.label : "")
    return app
  }

  func testTabsFollowArrivingContentAndAllowManualSelectionBeforeCompletion() {
    let app = stream("tabs", language: "en")
    let next = app.buttons["stream.next"]
    var manuallySelected = false
    while next.isEnabled {
      next.tap()
      let second = app.buttons["openui.tab.b"]
      if !manuallySelected, second.exists, second.isSelected {
        let first = app.buttons["openui.tab.a"]
        XCTAssertTrue(first.isEnabled)
        first.tap()
        manuallySelected = true
      }
      if manuallySelected { XCTAssertTrue(app.buttons["openui.tab.a"].isSelected) }
    }
    XCTAssertTrue(manuallySelected, "The arriving second item must have become active without a user action")
    app.buttons["stream.complete"].tap()
    XCTAssertTrue(app.buttons["openui.tab.a"].isSelected)
    XCTAssertFalse(app.staticTexts["review.errors"].exists)
    capture(app, name: "stream-tabs-manual-choice-stops-following")
    app.buttons["stream.replace"].tap()
    XCTAssertTrue(app.buttons["openui.tab.c"].isSelected,
      "Replacement starts a fresh upstream selection lifecycle")
    capture(app, name: "stream-tabs-complete-replay-follows-last-content")
    app.terminate()
  }

  func testUnattendedAppendFollowsNewTabsAndAccordionItems() {
    let app = stream("state", language: "en")
    XCTAssertTrue(app.buttons["openui.tab.b"].isSelected)
    XCTAssertTrue(app.staticTexts["Detail one content"].exists)
    app.buttons["stream.append"].tap()
    XCTAssertTrue(app.buttons["openui.tab.c"].isSelected)
    XCTAssertTrue(app.staticTexts["Detail two content"].exists)
    XCTAssertFalse(app.staticTexts["Detail one content"].exists)
    XCTAssertFalse(app.staticTexts["review.errors"].exists)
    capture(app, name: "stream-unattended-tabs-and-accordion-follow-arrivals")
    app.terminate()
  }

  func testSavedOriginalFollowsUpstreamTabsAndKeepsHorizontalNavigation() throws {
    guard Bundle(for: Self.self).url(forResource: "StreamProgram", withExtension: "openui") != nil else {
      throw XCTSkip("Supply --stream-program for the original-source streaming replay")
    }
    let app = stream("original")
    let next = app.buttons["stream.next"]
    var sawFirst = false
    while next.isEnabled {
      next.tap()
      let first = app.buttons["openui.tab.a"]
      if first.exists {
        sawFirst = true
        XCTAssertTrue(first.isEnabled, "Local tab browsing remains available during streaming, as upstream does")
        XCTAssertEqual(app.pickers.count, 0, "Tabs must never turn into a menu Picker")
      }
      let errors = app.staticTexts["stream.pending-diagnostics"]
      if errors.exists {
        let details = XCTAttachment(string: "offset=\(app.staticTexts["stream.offset"].label) diagnostics=\(errors.label)\n" + app.debugDescription)
        details.name = "stream-prefix-diagnostics"
        details.lifetime = .keepAlways
        add(details)
      }
    }
    XCTAssertTrue(sawFirst)
    capture(app, name: "stream-original-content-following")
    app.buttons["stream.complete"].tap()
    XCTAssertFalse(app.staticTexts["review.errors"].exists, "The unmodified complete source must validate without pending-field errors")
    XCTAssertTrue(app.buttons["openui.tab.c"].isSelected)
    XCTAssertTrue(app.buttons["openui.tab.a"].isEnabled,
      "A complete stream must refresh interaction eligibility even when tab props are unchanged")
    let navigation = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "openui.tabs.")).firstMatch
    let third = app.buttons["openui.tab.c"]
    for _ in 0..<4 where !third.isHittable { navigation.swipeLeft() }
    XCTAssertTrue(third.isHittable, "Long Chinese labels remain reachable by horizontal scrolling")
    third.tap()
    XCTAssertTrue(third.isSelected)
    let content = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "自然占比最高")).firstMatch
    XCTAssertTrue(content.exists)
    capture(app, name: "stream-original-long-label-horizontal-navigation")
    app.buttons["stream.replace"].tap()
    XCTAssertTrue(app.buttons["openui.tab.c"].isSelected, "A complete replay uses the upstream last-growing-item rule")
    capture(app, name: "stream-original-history-initial-selection")
    app.terminate()
  }

  func testAppendAndConditionalContentKeepTabsDisclosureAndCarouselPage() {
    let app = stream("state")
    let second = app.buttons["openui.tab.b"]
    let navigation = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "openui.tabs.")).firstMatch
    let first = app.buttons["openui.tab.a"]
    for _ in 0..<3 where !first.isHittable { navigation.swipeRight() }
    first.tap() // A real value change records manual interaction before choosing b.
    for _ in 0..<3 where !second.isHittable { navigation.swipeLeft() }
    second.tap()
    XCTAssertTrue(second.isSelected)
    let disclosure = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Stable details")).firstMatch
    reveal(disclosure, in: app)
    XCTAssertTrue(app.staticTexts["Detail one content"].exists)
    disclosure.tap()
    XCTAssertFalse(app.staticTexts["Detail one content"].exists)
    let next = app.buttons["openui.carousel.next"]
    reveal(next, in: app); next.tap()
    XCTAssertTrue(app.staticTexts["Page B"].exists)
    XCTAssertEqual(app.staticTexts["openui.carousel.page"].label, "2 / 2")
    let show = app.buttons["Show prefix"]
    reveal(show, in: app); show.tap()
    XCTAssertTrue(second.isSelected, "Filling an earlier null slot must not remount Tabs")
    let apply = app.buttons["Add two"]
    reveal(apply, in: app); apply.tap()
    XCTAssertTrue(app.staticTexts["Count: 12"].waitForExistence(timeout: 3))
    XCTAssertEqual(app.staticTexts["review.state-update-count"].label, "2", "Prefix and arithmetic each write once")
    app.buttons["stream.append"].tap()
    XCTAssertTrue(second.isSelected)
    XCTAssertFalse(app.staticTexts["Detail one content"].exists)
    XCTAssertFalse(app.staticTexts["Detail two content"].exists)
    XCTAssertTrue(app.staticTexts["Page B"].exists)
    XCTAssertEqual(app.staticTexts["openui.carousel.page"].label, "2 / 3", "Appending a page must retain the current page")
    XCTAssertTrue(app.staticTexts["Count: 12"].exists)
    capture(app, name: "stream-append-retains-native-selection-and-state")
    app.buttons["stream.replace"].tap()
    XCTAssertTrue(app.buttons["openui.tab.b"].isSelected)
    XCTAssertEqual(app.staticTexts["openui.carousel.page"].label, "1 / 2")
    XCTAssertTrue(app.staticTexts["Count: 10"].exists)
    app.terminate()
  }

  func testTableSafePagePreservesTheUpstreamPageStateWhenRowsReturn() {
    let app = stream("state")
    let next = app.buttons["openui.table.next"]
    reveal(next, in: app); next.tap()
    XCTAssertEqual(app.staticTexts["openui.table.page"].label, "2 / 2")
    app.buttons["stream.append"].tap()
    XCTAssertEqual(app.staticTexts["openui.table.page"].label, "2 / 4")
    app.buttons["stream.append"].tap()
    XCTAssertFalse(app.staticTexts["openui.table.page"].exists)
    app.buttons["stream.append"].tap()
    XCTAssertEqual(app.staticTexts["openui.table.page"].label, "2 / 4", "The safe visible page must not overwrite upstream currentPage state")
    capture(app, name: "stream-table-removal-and-regrowth")
    app.terminate()
  }

  func testGalleryFirstMountAppendAndReopenNeedNoRetryAndKeepLoadedPhotos() {
    let app = stream("gallery")
    let first = app.buttons["openui.gallery.image.0"]
    let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: first)
    XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 10), .completed)
    let initialLoads = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", "Images: 2"), object: app.staticTexts["review.images"])
    XCTAssertEqual(XCTWaiter.wait(for: [initialLoads], timeout: 8), .completed)
    XCTAssertEqual(app.staticTexts["review.images"].label, "Images: 2")
    XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "openui.gallery.unavailable").firstMatch.exists)
    let second = app.buttons["openui.gallery.image.1"]
    second.tap()
    XCTAssertTrue(app.staticTexts["Photo B"].waitForExistence(timeout: 5))
    app.buttons["openui.gallery.close"].tap()
    app.buttons["stream.append"].tap()
    let loaded = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", "Images: 3"), object: app.staticTexts["review.images"])
    XCTAssertEqual(XCTWaiter.wait(for: [loaded], timeout: 8), .completed)
    XCTAssertEqual(app.staticTexts["review.images"].label, "Images: 3", "Appending one photo must not reload the two existing resources")
    second.tap()
    XCTAssertTrue(app.staticTexts["2 / 3"].waitForExistence(timeout: 5))
    app.buttons["openui.gallery.close"].tap()
    capture(app, name: "stream-gallery-append-keeps-resources")
    app.buttons["stream.replace"].tap()
    let reopened = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: first)
    XCTAssertEqual(XCTWaiter.wait(for: [reopened], timeout: 10), .completed)
    XCTAssertFalse(app.buttons["openui.gallery.retry"].exists)
    capture(app, name: "stream-gallery-history-fresh-first-load")
    app.terminate()
  }
}
