import UIKit
import XCTest

final class ReviewFullLibraryParityTests: ReviewTestCase {
  func testRichTextRendersBlocksMathCodeAndSourceContext() {
    let app = launch("complete-rich-text", inspect: true, language: "en")
    XCTAssertTrue(app.staticTexts["A complete answer"].waitForExistence(timeout: 8))
    XCTAssertTrue(app.staticTexts["First observation"].exists)
    XCTAssertTrue(app.staticTexts["Alpha"].exists)
    let equation = app.descendants(matching: .any).matching(identifier: "openui.math.rendered").firstMatch
    reveal(equation, in: app)
    XCTAssertTrue(equation.waitForExistence(timeout: 15))
    XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "openui.math.fallback").firstMatch.exists)
    XCTAssertTrue(hasInk(equation.screenshot().image), "The equation must contain rendered glyphs, not an empty snapshot")
    capture(app, name: "full-rich-text-table-inline-and-display-math")

    let copy = app.buttons.matching(identifier: "openui.code.copy").firstMatch
    reveal(copy, in: app)
    copy.tap()
    assertCopiedCode("let answer = 42\nprint(answer)", in: app)

    let citation = app.links.matching(NSPredicate(format: "label CONTAINS %@", "1, 2")).firstMatch
    reveal(citation, in: app)
    citation.tap()
    let sources = app.descendants(matching: .any).matching(identifier: "openui.citation.sources").firstMatch
    XCTAssertTrue(sources.waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["Reference one"].exists)
    XCTAssertTrue(app.staticTexts["Reference two"].exists)
    capture(app, name: "full-rich-text-source-context")
    app.buttons["openui.citation.source.1"].tap()
    let opened = app.staticTexts["review.opened-url"]
    let routed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", "https://sdk-fixture.invalid/reference-one"), object: opened)
    XCTAssertEqual(XCTWaiter.wait(for: [routed], timeout: 5), .completed)
    XCTAssertFalse(app.staticTexts["review.errors"].exists)
    app.terminate()
  }

  func testChartLegendChangesVisibleDataAndKeepsTheLastSeries() {
    let app = launch("complete-chart-interaction", language: "en")
    let alpha = app.buttons["openui.chart.legend.Alpha"]
    let beta = app.buttons["openui.chart.legend.Beta"]
    reveal(beta, in: app)
    XCTAssertEqual(beta.value as? String, "Visible")
    beta.tap()
    XCTAssertEqual(beta.value as? String, "Hidden")
    alpha.tap()
    XCTAssertEqual(alpha.value as? String, "Visible", "The final visible series cannot be hidden")
    beta.tap()
    XCTAssertEqual(beta.value as? String, "Visible")
    capture(app, name: "full-chart-legend-visibility")

    let large = app.buttons["openui.chart.legend.Large"]
    reveal(large, in: app)
    large.tap()
    XCTAssertEqual(large.value as? String, "Hidden")
    capture(app, name: "full-polar-sorted-legend-and-selection")
    XCTAssertFalse(app.staticTexts["review.errors"].exists)
    app.terminate()
  }

  func testSliderSupportsTypedValuesAndDiscreteChoices() {
    let app = launch("complete-input-controls", inspect: true, language: "en")
    let lower = app.textFields.matching(NSPredicate(format: "identifier == %@ OR label == %@", "openui.slider.input.range.0", "Range")).firstMatch
    reveal(lower, in: app)
    lower.tap()
    let old = lower.value as? String ?? ""
    lower.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: old.count) + "45")
    waitForSlider("range", values: [45, 80], in: app)
    if app.keyboards.buttons["Return"].exists { app.keyboards.buttons["Return"].tap() }
    let choice = app.buttons.matching(NSPredicate(format: "identifier == %@ OR identifier == %@", "openui.slider.choice.steps.0", "openui.field.steps")).firstMatch
    reveal(choice, in: app)
    choice.tap()
    let option = app.buttons["openui.slider.option.60"]
    for _ in 0..<5 where !option.isHittable { app.swipeUp() }
    XCTAssertTrue(option.exists)
    option.tap()
    waitForSlider("steps", values: [60], in: app)
    XCTAssertFalse(app.staticTexts["review.errors"].exists)
    capture(app, name: "full-slider-range-input-and-discrete-choice")
    app.terminate()
  }

  func testQueriesDistinguishLoadingEmptyDataAndRefetch() {
    let app = launchStreamMode("queries")
    let tableLoading = app.descendants(matching: .any).matching(identifier: "openui.table.loading").firstMatch
    let pieLoading = app.descendants(matching: .any).matching(identifier: "openui.chart.loading").firstMatch
    XCTAssertTrue(tableLoading.waitForExistence(timeout: 5))
    XCTAssertTrue(pieLoading.exists)
    capture(app, name: "full-query-loading-skeletons")
    app.buttons["query.empty"].tap()
    waitForQueryReady(in: app)
    XCTAssertFalse(tableLoading.exists)
    XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "openui-chart-PieChart").firstMatch.exists)
    XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "openui-chart-BarChart").firstMatch.exists)
    XCTAssertLessThan(app.staticTexts["After the data"].frame.maxY, app.windows.firstMatch.frame.height / 2)
    capture(app, name: "full-query-empty-without-blank-charts")
    app.buttons["query.refresh"].tap()
    XCTAssertTrue(tableLoading.waitForExistence(timeout: 5))
    app.buttons["query.resolve"].tap()
    waitForQueryReady(in: app)
    XCTAssertTrue(app.staticTexts["Alpha"].exists)
    app.buttons["query.refresh"].tap()
    XCTAssertTrue(app.staticTexts["Alpha"].exists, "Refetch keeps existing data visible")
    XCTAssertFalse(tableLoading.exists)
    app.buttons["query.resolve"].tap()
    waitForQueryReady(in: app)
    XCTAssertFalse(app.staticTexts["review.errors"].exists)
    capture(app, name: "full-query-resolved-data")
    app.terminate()
  }

  func testModalCanCloseBeforeTheStreamCompletes() {
    let app = launchStreamMode("modal")
    XCTAssertTrue(app.staticTexts["Streaming details"].waitForExistence(timeout: 8))
    let close = app.buttons["Close"]
    XCTAssertTrue(close.isEnabled)
    close.tap()
    let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: app.staticTexts["Streaming details"])
    XCTAssertEqual(XCTWaiter.wait(for: [gone], timeout: 5), .completed)
    XCTAssertEqual(app.staticTexts["stream.phase"].label, "partial")
    XCTAssertTrue(app.staticTexts["review.state-current"].label.contains("false"))
    app.buttons["stream.complete"].tap()
    XCTAssertFalse(app.staticTexts["Streaming details"].exists)
    XCTAssertFalse(app.staticTexts["review.errors"].exists)
    capture(app, name: "full-modal-dismissed-during-stream")
    app.terminate()
  }

  private func launchStreamMode(_ mode: String) -> XCUIApplication {
    continueAfterFailure = false
    let app = XCUIApplication(bundleIdentifier: "dev.swiftui.component-review")
    app.launchArguments = ["--stream-case", mode, "--language", "en", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
    app.launch()
    return app
  }
  private func waitForQueryReady(in app: XCUIApplication) {
    let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", "ready"), object: app.staticTexts["query.phase"])
    XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 5), .completed)
  }
  private func waitForSlider(_ name: String, values: [Double], in app: XCUIApplication) {
    let snapshot = app.staticTexts["review.state-current"]
    let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
      guard let data = snapshot.label.data(using: .utf8), let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
        let form = root["controls"] as? [String: Any], let field = form[name] as? [String: Any],
        let actual = field["value"] as? [Double] else { return false }
      return actual == values
    }, object: nil)
    XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 5), .completed)
  }
  private func hasInk(_ image: UIImage) -> Bool {
    guard let bitmap = image.cgImage else { return false }
    var pixels = [UInt8](repeating: 0, count: bitmap.width * bitmap.height * 4)
    pixels.withUnsafeMutableBytes { bytes in
      let canvas = CGContext(data: bytes.baseAddress, width: bitmap.width, height: bitmap.height, bitsPerComponent: 8,
        bytesPerRow: bitmap.width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
      canvas.draw(bitmap, in: CGRect(x: 0, y: 0, width: CGFloat(bitmap.width), height: CGFloat(bitmap.height)))
    }
    var inkPixels = 0
    for offset in stride(from: 0, to: pixels.count, by: 4) {
      let alpha = pixels[offset + 3]
      let darkest = min(pixels[offset], min(pixels[offset + 1], pixels[offset + 2]))
      if alpha > 128 && darkest < 170 { inkPixels += 1 }
      if inkPixels > 12 { return true }
    }
    return false
  }
}
