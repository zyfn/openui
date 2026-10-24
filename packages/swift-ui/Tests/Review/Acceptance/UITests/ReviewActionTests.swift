import UIKit
import XCTest

final class ReviewActionTests: ReviewTestCase {
  func testNativeProgressiveReadingKeepsSummaryAndLocalState() {
    let app = launch("progressive-reading", inspect: true)
    // This is an actionable ListItem: accessibility exposes the whole row as
    // a button with combined title/summary, rather than separate static text.
    let title = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "石刻的结构与光影")).firstMatch
    XCTAssertTrue(title.waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["review.images"].label.contains("1"))
    XCTAssertFalse(app.staticTexts["完整观察说明"].exists, "Initial view must show the supplied summary, with details closed")
    XCTAssertFalse(app.staticTexts["更完整的阅读空间"].exists)
    capture(app, name: "progressive-summary")
    let mark = app.buttons["标记线索"]
    reveal(mark, in: app); mark.tap()
    XCTAssertTrue(app.staticTexts["已标记"].exists)
    let expand = app.buttons["展开细节"]
    reveal(expand, in: app); expand.tap()
    let heading = app.staticTexts["完整观察说明"]
    XCTAssertTrue(heading.waitForExistence(timeout: 3))
    let paragraph = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "先从人物轮廓与空间关系看整体")).firstMatch
    XCTAssertTrue(paragraph.exists)
    XCTAssertGreaterThan(paragraph.frame.width, app.windows.firstMatch.frame.width * 0.75,
      "Long detail belongs in a reading-width section, not the thumbnail column")
    reveal(paragraph, in: app)
    capture(app, name: "progressive-expanded")
    let collapse = app.buttons["收起细节"]
    reveal(collapse, in: app); collapse.tap()
    XCTAssertFalse(heading.exists)
    XCTAssertTrue(app.staticTexts["已标记"].exists)
    let reader = app.buttons["打开阅读视图"]
    reveal(reader, in: app)
    let before = reader.frame.minY
    reader.tap()
    XCTAssertTrue(app.staticTexts["更完整的阅读空间"].waitForExistence(timeout: 3))
    capture(app, name: "progressive-reader")
    app.buttons["Close"].tap()
    XCTAssertFalse(app.staticTexts["更完整的阅读空间"].exists)
    XCTAssertEqual(reader.frame.minY, before, accuracy: 3)
    XCTAssertTrue(app.staticTexts["已标记"].exists)
    let source = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "石刻的结构与光影")).firstMatch
    reveal(source, in: app); source.tap()
    let action = app.staticTexts["review.lastAction"]
    let opened = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", "open_url"), object: action)
    XCTAssertEqual(XCTWaiter.wait(for: [opened], timeout: 3), .completed)
    XCTAssertFalse(app.staticTexts["review.errors"].exists)
    capture(app, name: "progressive-returned")
    app.terminate()
  }

  func testActionDensityAndExplicitSizeStayConsistent() {
    for dark in [false, true] {
      let app = launch("action-sizes", dark: dark, inspect: true)
      let embedded = app.buttons["内嵌操作"]
      let regular = app.buttons["独立操作"]
      let explicitMedium = app.buttons["中号操作"]
      let explicitLarge = app.buttons["大号操作"]
      XCTAssertLessThan(embedded.frame.width, regular.frame.width - 8,
        "Default embedded actions must be quieter than page actions")
      XCTAssertEqual(explicitMedium.frame.width, regular.frame.width, accuracy: 3,
        "An explicit medium size overrides compact card context")
      XCTAssertGreaterThan(explicitLarge.frame.height, embedded.frame.height)
      for label in ["内嵌操作", "中号操作", "大号操作", "独立操作", "最小操作", "小号操作"] {
        let button = app.buttons[label]
        assertHitTarget(button)
      }
      capture(app, name: dark ? "action-density-dark" : "action-density-light")
      embedded.tap()
      let snapshot = app.staticTexts["review.state"]
      XCTAssertTrue(snapshot.waitForExistence(timeout: 3))
      XCTAssertTrue(snapshot.label.contains("内嵌"))
      let submit = app.buttons["提交表单"]
      reveal(submit, in: app)
      XCTAssertGreaterThan(submit.frame.width, regular.frame.width * 1.5,
        "A form retains its full-width submit action inside a card")
      submit.tap()
      XCTAssertTrue(snapshot.label.contains("提交"))
      XCTAssertFalse(app.staticTexts["review.errors"].exists)
      app.terminate()
    }
  }

  func testCardActionsUseSharedScaleAndPreserveDynamicType() {
    for large in textSizes {
      let app = launch("action-layout", large: large)
      let action = app.buttons["阅读介绍"]
      XCTAssertTrue(action.waitForExistence(timeout: 5))
      reveal(action, in: app)
      XCTAssertGreaterThanOrEqual(action.frame.height, 44)
      XCTAssertLessThan(action.frame.width, app.windows.firstMatch.frame.width * 0.7)
      capture(app, name: large ? "card-action-accessibility" : "card-action-compact")
      action.tap()
      let detail = app.staticTexts["从整体到局部"]
      XCTAssertTrue(detail.waitForExistence(timeout: 5))
      let save = app.buttons["留待以后"]
      reveal(save, in: app)
      save.tap()
      XCTAssertTrue(app.buttons["已收藏"].exists)
      capture(app, name: large ? "card-action-expanded-accessibility" : "card-action-expanded")
      XCTAssertFalse(app.staticTexts["review.errors"].exists)
      app.terminate()
    }
  }

  func testNativeModalClosesAndShowsFeedback() {
    let app = launch("dialogs")
    app.buttons["打开详情"].tap()
    let done = app.buttons["完成操作"]
    XCTAssertTrue(done.waitForExistence(timeout: 5))
    let modal = XCTAttachment(screenshot: app.screenshot())
    modal.name = "modal-open"
    modal.lifetime = .keepAlways
    add(modal)
    done.tap()
    XCTAssertTrue(app.staticTexts["已完成"].waitForExistence(timeout: 3))
    capture(app, name: "callout-visible")
    let gone = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "exists == false"), object: app.staticTexts["已完成"])
    XCTAssertEqual(XCTWaiter.wait(for: [gone], timeout: 6), .completed)
    app.terminate()
  }

  @objc func testNativeImageCardActionUsesTheWholeSurface() {
    let app = launch("image-cards", inspect: true)
    XCTAssertFalse(app.buttons["普通图文说明"].exists)
    let card = app.buttons["石刻与光影"]
    reveal(card, in: app)
    XCTAssertGreaterThan(
      card.frame.height, 160,
      "A simple actionable visual card must include its image in the hit surface")
    // Tap within the photo, not the caption or an accessory row.
    card.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25)).tap()
    let events = app.staticTexts["review.events"]
    reveal(events, in: app)
    let first = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "label == %@", "Events: 1"), object: events)
    XCTAssertEqual(XCTWaiter.wait(for: [first], timeout: 3), .completed)
    let footer = app.buttons["阅读介绍"]
    // The composite card is above the inspector after scrolling to the bottom.
    if !footer.isHittable { app.scrollViews.firstMatch.swipeDown() }
    reveal(footer, in: app)
    footer.tap()
    reveal(events, in: app)
    let second = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "label == %@", "Events: 2"), object: events)
    XCTAssertEqual(
      XCTWaiter.wait(for: [second], timeout: 3), .completed,
      "The composite card's own button must dispatch once independently")
    capture(app, name: "image-card-actions")
    app.terminate()
  }
}
