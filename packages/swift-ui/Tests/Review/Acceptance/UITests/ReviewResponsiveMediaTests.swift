import UIKit
import XCTest

final class ReviewResponsiveMediaTests: ReviewTestCase {
  func testCardBlockPagingFollowsTheContainerAndPreservesItsAction() {
    let app = launch("image-cards", inspect: true, width: "narrow")
    let first = app.buttons["石刻与光影"]
    reveal(first, in: app)
    let narrowWidth = first.frame.width
    XCTAssertLessThanOrEqual(narrowWidth, canvas(in: app).frame.width)
    let next = app.buttons["openui.card-block.visual.next"]
    reveal(next, in: app)
    next.tap()
    let selected = app.buttons["器物与纹理"]
    XCTAssertTrue(selected.waitForExistence(timeout: 5))

    app.buttons["review.conditions-menu"].tap()
    app.segmentedControls["review.width-picker"].buttons["自适应"].tap()
    app.buttons["review.panel-done"].tap()
    waitForPanelToClose(in: app)
    reveal(selected, in: app)
    XCTAssertGreaterThan(selected.frame.width, narrowWidth + 20,
      "A CardBlock page must follow the new viewport instead of retaining a private fixed width")
    XCTAssertLessThanOrEqual(selected.frame.width, canvas(in: app).frame.width)
    XCTAssertEqual(app.staticTexts["openui.card-block.visual.page"].label, "2 / 2")
    capture(app, name: "responsive-card-block-selected-page")
    selected.tap()
    let events = app.staticTexts["review.events"]
    reveal(events, in: app)
    XCTAssertEqual(events.label, "Events: 1", "Paging must preserve the item's original group action")
    XCTAssertFalse(app.staticTexts["review.errors"].exists)
    app.terminate()
  }

  func testHorizontalImageTextKeepsExplicitImageSizeWhenTextGrows() {
    let app = launch("map", width: "narrow")
    let photo = app.images["石刻照片"].firstMatch
    XCTAssertTrue(photo.waitForExistence(timeout: 8))
    reveal(photo, in: app)
    let title = app.staticTexts["地点一详情"]
    XCTAssertEqual(photo.frame.width, 64, accuracy: 2)
    XCTAssertEqual(photo.frame.height, 64, accuracy: 2)
    XCTAssertGreaterThanOrEqual(title.frame.minX, photo.frame.maxX + 8)

    app.buttons["review.conditions-menu"].tap()
    setDisplaySwitch("review.toggle-text", enabled: acceptsLargeText, in: app)
    app.buttons["review.panel-done"].tap()
    waitForPanelToClose(in: app)
    let row = app.scrollViews["openui.media-row"].firstMatch
    reveal(row, in: app)
    XCTAssertEqual(photo.frame.width, 64, accuracy: 2)
    XCTAssertEqual(photo.frame.height, 64, accuracy: 2)
    XCTAssertGreaterThanOrEqual(title.frame.minX, photo.frame.maxX + 8,
      "Explicit horizontal layout must retain its direction at accessibility text sizes")
    if title.frame.maxX > row.frame.maxX + 2 { row.swipeLeft() }
    XCTAssertTrue(title.isHittable)
    XCTAssertLessThanOrEqual(title.frame.maxX, row.frame.maxX + 2,
      "Copy fits naturally or remains reachable by scrolling when it actually overflows")
    capture(app, name: "responsive-explicit-horizontal-media")
    XCTAssertFalse(app.staticTexts["review.errors"].exists)
    app.terminate()
  }

  func testLargeMediaUsesItsNaturalRatioAtTwoContainerWidths() throws {
    let referenceSize = try fixtureImageSize("detail")
    let app = launch("media-text", width: "narrow")
    let image = app.images["横幅石刻照片"]
    XCTAssertTrue(image.waitForExistence(timeout: 8))
    reveal(image, in: app)
    let narrow = image.frame.size
    XCTAssertEqual(narrow.width / narrow.height, referenceSize.width / referenceSize.height, accuracy: 0.03,
      "ImageTextLarge must retain the bundled asset's natural ratio without an explicit height field")
    app.buttons["review.conditions-menu"].tap()
    app.segmentedControls["review.width-picker"].buttons["320"].tap()
    app.buttons["review.panel-done"].tap()
    waitForPanelToClose(in: app)
    reveal(image, in: app)
    XCTAssertGreaterThan(image.frame.height, narrow.height + 20)
    XCTAssertEqual(image.frame.width / image.frame.height, narrow.width / narrow.height, accuracy: 0.03)
    let title = app.staticTexts["从一处细节，读懂一件作品及其背后的故事"]
    XCTAssertGreaterThanOrEqual(title.frame.minY, image.frame.maxY + 8)
    capture(app, name: "responsive-natural-media-height")
    XCTAssertFalse(app.staticTexts["review.errors"].exists)
    app.terminate()
  }
}
