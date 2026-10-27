import UIKit
import XCTest

class ReviewTestCase: XCTestCase {
  func launch(
    _ name: String, dark: Bool = false, large: Bool = false, inspect: Bool = false, media: String? = nil,
    width: String = "available", theme: String = "default", bubble: Bool = false,
    language: String = "zh-Hans"
  ) -> XCUIApplication {
    continueAfterFailure = false
    let app = XCUIApplication(bundleIdentifier: "dev.swiftui.component-review")
    app.launchArguments = [
      "--case", name, "--appearance", dark ? "dark" : "light", "-AppleLanguages", "(en)",
      "-AppleLocale", "en_US",
      "--width", width, "--theme", theme, "--language", language,
      "--tps", "320",
    ]
    if large { app.launchArguments.append("--large-text") }
    if inspect { app.launchArguments.append("--inspect") }
    if bubble { app.launchArguments.append("--bubble") }
    if let media { app.launchArguments += ["--media-response", media] }
    app.launch()
    XCTAssertTrue(app.scrollViews.firstMatch.waitForExistence(timeout: 10))
    let ready = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "value == %@", language == "en" ? "Ready to replay" : "可重新播放"),
      object: app.buttons["review.replay"])
    XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 60), .completed, name)
    XCTAssertFalse(app.staticTexts["review.transport-error"].exists)
    XCTAssertFalse(app.staticTexts["review.errors"].exists)
    return app
  }

  func reveal(_ element: XCUIElement, in app: XCUIApplication) {
    let scroll = app.scrollViews["review.surface"]
    let viewport = scroll.frame.intersection(app.windows.firstMatch.frame).insetBy(dx: 4, dy: 8)
    for _ in 0..<10 {
      if element.isHittable && viewport.contains(element.frame) { return }
      let frame = element.exists ? element.frame : .zero
      let downward = frame != .zero && frame.minY < viewport.minY
      let needed =
        frame == .zero
        ? viewport.height
        : downward
          ? viewport.minY - frame.minY : frame.maxY - viewport.maxY
      let distance = min(viewport.height * 0.55, max(40, needed + 16))
      let fraction = distance / max(1, scroll.frame.height)
      let startY = downward ? 0.3 : 0.7
      let endY = downward ? startY + fraction : startY - fraction
      // Use the document gutter: a drag starting inside a map intentionally
      // pans the map, rather than revealing the next document section.
      scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: startY))
        .press(
          forDuration: 0.05,
          thenDragTo: scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: endY)))
    }
    XCTAssertTrue(
      element.isHittable && viewport.contains(element.frame),
      "The complete hit target must be inside the visible viewport: \(element)")
  }

  func canvas(in app: XCUIApplication) -> XCUIElement {
    app.descendants(matching: .any).matching(identifier: "review.canvas").firstMatch
  }

  func assertHitTarget(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
    let size = element.frame.size
    // Normalize subpixel floating-point noise; do not enlarge SDK controls.
    XCTAssertGreaterThanOrEqual((size.width * 1000).rounded() / 1000, 44, file: file, line: line)
    XCTAssertGreaterThanOrEqual((size.height * 1000).rounded() / 1000, 44, file: file, line: line)
  }

  func capture(_ app: XCUIApplication, name: String) {
    // Capture only pixels actually visible on the native screen. Asking for
    // an offscreen ScrollView content element can produce padded black areas.
    let screenshot = app.screenshot()
    let attachment = XCTAttachment(screenshot: screenshot)
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }

  func matrixReport() throws -> [String: Any] {
    continueAfterFailure = false
    let app = XCUIApplication(bundleIdentifier: "dev.swiftui.component-review")
    app.launchArguments = ["--audit-matrix", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
    app.launch()
    let result = app.staticTexts["review.matrix-audit"]
    let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label BEGINSWITH %@", "{"), object: result)
    XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 20), .completed)
    let data = Data(result.label.utf8)
    let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
    attachment.name = "sdk-composition-matrix-audit.json"
    attachment.lifetime = .keepAlways
    add(attachment)
    let report = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    app.terminate()
    return report
  }
}
