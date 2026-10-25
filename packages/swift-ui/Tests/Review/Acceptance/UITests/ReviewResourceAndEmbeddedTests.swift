import UIKit
import XCTest

final class ReviewResourceAndEmbeddedTests: ReviewTestCase {
  func testRepeatedNativeContentUpdatesRecordTimeAndMemory() {
    let app = launch("adaptive-images")
    let options = XCTMeasureOptions()
    options.iterationCount = 3
    measure(metrics: [XCTClockMetric(), XCTMemoryMetric(application: app)], options: options) {
      app.buttons["展开文字"].tap()
      XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "留意人物的姿态、凿刻的痕迹")).firstMatch.exists)
      app.buttons["收起文字"].tap()
      XCTAssertTrue(app.staticTexts["看一处细节。"].exists)
    }
    XCTAssertFalse(app.staticTexts["review.errors"].exists)
    app.terminate()
  }

  func testRelativeImagesInListsGalleryAndMarkdownUseOneContext() {
    let app = launch("images", inspect: true)
    let first = app.images["石刻照片"]
    XCTAssertTrue(first.waitForExistence(timeout: 8))
    let markdown = app.descendants(matching: .any).matching(identifier: "openui.markdown.image.loaded").firstMatch
    XCTAssertTrue(markdown.waitForExistence(timeout: 10), "Markdown must use the same relative resource base as structured images")
    reveal(markdown, in: app)
    XCTAssertGreaterThan(markdown.frame.height, 100)
    capture(app, name: "resource-context-markdown-relative-image")
    let gallery = app.buttons["openui.gallery.image.0"]
    reveal(gallery, in: app)
    let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: gallery)
    XCTAssertEqual(XCTWaiter.wait(for: [enabled], timeout: 8), .completed)
    gallery.tap()
    XCTAssertTrue(app.buttons["openui.gallery.close"].waitForExistence(timeout: 5))
    capture(app, name: "resource-context-gallery-preview")
    app.buttons["openui.gallery.close"].tap()
    XCTAssertFalse(app.staticTexts["review.errors"].exists)
    app.terminate()
  }

  func testSVGAndWebContentRenderInTheExistingMediaComposition() {
    let app = launch("media-text")
    let svg = app.descendants(matching: .any).matching(identifier: "openui.svg").firstMatch
    XCTAssertTrue(svg.waitForExistence(timeout: 8))
    reveal(svg, in: app)
    let sized = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in svg.frame.height > 70 }, object: nil)
    XCTAssertEqual(XCTWaiter.wait(for: [sized], timeout: 8), .completed)
    XCTAssertLessThanOrEqual(svg.frame.maxX, canvas(in: app).frame.maxX + 2)
    capture(app, name: "embedded-svg-native-webkit")
    let web = app.descendants(matching: .any).matching(identifier: "openui.web").firstMatch
    XCTAssertTrue(web.exists)
    reveal(web, in: app)
    let content = app.webViews.staticTexts["Explore another perspective"]
    XCTAssertTrue(content.waitForExistence(timeout: 8))
    XCTAssertGreaterThan(web.frame.height, 44)
    capture(app, name: "embedded-html-native-webkit")
    XCTAssertFalse(app.staticTexts["review.errors"].exists)
    app.terminate()
  }

  func testChartTapShowsAnAnchoredTooltipWithoutChangingDocumentHeight() {
    let app = launch("data")
    let chart = app.descendants(matching: .any).matching(identifier: "openui-chart-BarChart").firstMatch
    XCTAssertTrue(chart.waitForExistence(timeout: 5))
    reveal(chart, in: app)
    let before = chart.frame
    let documentHeight = canvas(in: app).frame.height
    let point = chart.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
    point.tap()
    let tooltip = app.staticTexts["openui-chart-inspection"]
    XCTAssertTrue(tooltip.waitForExistence(timeout: 5))
    XCTAssertTrue(chart.frame.insetBy(dx: -1, dy: -1).contains(tooltip.frame), "Inspection must be inside the chart")
    XCTAssertEqual(chart.frame, before)
    XCTAssertEqual(canvas(in: app).frame.height, documentHeight, accuracy: 1)
    capture(app, name: "chart-anchored-tap-tooltip")
    point.tap()
    XCTAssertFalse(tooltip.exists)
    XCTAssertEqual(canvas(in: app).frame.height, documentHeight, accuracy: 1)
    app.terminate()
  }
}
