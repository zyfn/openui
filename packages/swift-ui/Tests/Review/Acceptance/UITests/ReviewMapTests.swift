import UIKit
import XCTest

final class ReviewMapTests: ReviewTestCase {
  func testDefaultPlaceCardsUseSuppliedFactsAndSynchronizeWithIconMarkers() {
    let app = launch("map-places", inspect: true)
    let map = app.descendants(matching: .any).matching(identifier: "openui.map.canvas").firstMatch
    let pager = app.descendants(matching: .any).matching(identifier: "openui.map.pager").firstMatch
    XCTAssertTrue(map.waitForExistence(timeout: 5))
    XCTAssertTrue(pager.waitForExistence(timeout: 5))
    reveal(pager, in: app)
    XCTAssertGreaterThan(pager.frame.height, 60)
    XCTAssertGreaterThanOrEqual(pager.frame.minY, map.frame.minY)
    XCTAssertLessThanOrEqual(pager.frame.maxY, map.frame.maxY + 2)
    XCTAssertFalse(app.staticTexts["openui.map.page"].exists)
    XCTAssertFalse(app.buttons["openui.map.next"].exists)
    capture(app, name: "map-default-icon-markers-and-place-card")
    pager.swipeLeft()
    XCTAssertTrue(app.staticTexts["当前地点：b"].waitForExistence(timeout: 3))
    capture(app, name: "map-default-card-swipe-selects-marker")
    let marker = app.descendants(matching: .any).matching(identifier: "openui.map.marker.a").firstMatch
    reveal(marker, in: app)
    marker.tap()
    XCTAssertTrue(app.staticTexts["当前地点：a"].waitForExistence(timeout: 3))
    XCTAssertFalse(app.staticTexts["review.errors"].exists)
    app.terminate()
  }

  @objc func testNativeMapMarkerSelectionAndExpansion() {
    let app = launch("map", inspect: true)
    let map = app.descendants(matching: .any).matching(identifier: "openui.map.canvas").firstMatch
    XCTAssertTrue(map.waitForExistence(timeout: 8))
    XCTAssertTrue(app.staticTexts["地点一详情"].waitForExistence(timeout: 5))
    XCTAssertLessThan(app.staticTexts["地点一详情"].frame.maxY, map.frame.maxY,
      "Composed cards belong inside the bottom of the map viewport")
    XCTAssertFalse(app.buttons["openui.map.next"].exists)
    XCTAssertFalse(app.staticTexts["openui.map.page"].exists)
    capture(app, name: "map-initial")
    let marker = app.descendants(matching: .any)
      .matching(identifier: "openui.map.marker.second").firstMatch
    if !marker.waitForExistence(timeout: 8) {
      let tree = XCTAttachment(string: app.debugDescription)
      tree.name = "map-marker-accessibility"
      tree.lifetime = .keepAlways
      add(tree)
      XCTFail("The second map marker must be a native accessibility target")
      return
    }
    marker.tap()
    XCTAssertTrue(app.staticTexts["地点二详情"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["review.state"].label.contains("second"))
    capture(app, name: "map-selected")
    let expand = app.buttons.matching(NSPredicate(format: "label IN %@", ["Expand map", "展开地图"])).firstMatch
    XCTAssertTrue(expand.exists)
    expand.tap()
    let close = app.buttons.matching(NSPredicate(format: "label IN %@", ["Close", "关闭"])).firstMatch
    XCTAssertTrue(close.waitForExistence(timeout: 5))
    let expanded = app.descendants(matching: .any).matching(identifier: "openui.map.expanded").firstMatch
    XCTAssertTrue(expanded.staticTexts["地点二详情"].exists)
    capture(app, name: "map-fullscreen")
    close.tap()
    XCTAssertTrue(expand.waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["地点二详情"].exists)
    app.terminate()
  }

  @objc func testNativeMapContentUsesGenericComponentsAndSharedSelection() {
    let app = launch("map", inspect: true)
    let first = app.staticTexts["地点一详情"]
    let second = app.staticTexts["地点二详情"]
    XCTAssertTrue(first.waitForExistence(timeout: 8))
    let pager = app.descendants(matching: .any).matching(identifier: "openui.map.pager").firstMatch
    reveal(pager, in: app)
    pager.swipeLeft()
    XCTAssertTrue(second.waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["review.state"].label.contains("second"))
    let firstMarker = app.descendants(matching: .any).matching(identifier: "openui.map.marker.first").firstMatch
    firstMarker.tap()
    XCTAssertTrue(first.waitForExistence(timeout: 5))
    let map = app.descendants(matching: .any).matching(identifier: "openui.map.canvas").firstMatch
    let inlineY = map.frame.minY
    app.buttons.matching(NSPredicate(format: "label IN %@", ["Expand map", "展开地图"])).firstMatch.tap()
    XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label IN %@", ["Close", "关闭"])).firstMatch.waitForExistence(timeout: 5))
    let expanded = app.descendants(matching: .any).matching(identifier: "openui.map.expanded").firstMatch
    expanded.descendants(matching: .any).matching(identifier: "openui.map.pager").firstMatch.swipeLeft()
    XCTAssertTrue(expanded.staticTexts["地点二详情"].waitForExistence(timeout: 5))
    capture(app, name: "map-composed-content-fullscreen")
    app.buttons.matching(NSPredicate(format: "label IN %@", ["Close", "关闭"])).firstMatch.tap()
    XCTAssertTrue(second.waitForExistence(timeout: 5))
    XCTAssertEqual(map.frame.minY, inlineY, accuracy: 3)
    capture(app, name: "map-composed-content-inline")
    app.terminate()
  }

  @objc func testNativeMapAccessibleTextKeepsMarkersVisible() {
    let app = launch("map", large: true)
    let map = app.descendants(matching: .any).matching(identifier: "openui.map.canvas").firstMatch
    let card = app.staticTexts["地点一详情"].firstMatch
    XCTAssertTrue(map.waitForExistence(timeout: 8))
    XCTAssertTrue(card.waitForExistence(timeout: 5))
    XCTAssertGreaterThan(map.frame.height, 180)
    XCTAssertLessThan(card.frame.maxY, map.frame.maxY)
    reveal(card, in: app)
    XCTAssertTrue(card.isHittable, "The selected card must actually be visible and readable")
    capture(app, name: "map-accessibility")
    app.terminate()
  }

  @objc func testNativeMapComposesInTabs() {
    let app = launch("map-tabs")
    let first = app.buttons["第一组"]
    XCTAssertTrue(first.waitForExistence(timeout: 5))
    first.tap()
    XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "openui.map.marker.one").firstMatch.waitForExistence(timeout: 5))
    capture(app, name: "map-tabs-first")
    let second = app.buttons["第二组"]
    second.tap()
    XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "openui.map.marker.two").firstMatch.waitForExistence(timeout: 5))
    capture(app, name: "map-tabs-second")
    app.terminate()
  }
}
