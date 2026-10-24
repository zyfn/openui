import UIKit
import XCTest

class ReviewTestCase: XCTestCase {
  var acceptsLargeText: Bool {
    #if SDK_PHONE_ACCEPTANCE
    return false
    #else
    return true
    #endif
  }
  var textSizes: [Bool] { acceptsLargeText ? [false, true] : [false] }
  func launch(
    _ name: String, dark: Bool = false, large: Bool = false, inspect: Bool = false, media: String? = nil,
    width: String = "available", theme: String = "default", bubble: Bool = false
  ) -> XCUIApplication {
    continueAfterFailure = false
    let app = XCUIApplication(bundleIdentifier: "dev.swiftui.component-review")
    app.launchArguments = [
      "--case", name, "--appearance", dark ? "dark" : "light", "-AppleLanguages", "(en)",
      "-AppleLocale", "en_US",
      "--width", width, "--theme", theme,
    ]
    if large { app.launchArguments.append("--large-text") }
    if inspect { app.launchArguments.append("--inspect") }
    if bubble { app.launchArguments.append("--bubble") }
    if let media { app.launchArguments += ["--media-response", media] }
    app.launch()
    XCTAssertTrue(app.scrollViews.firstMatch.waitForExistence(timeout: 10))
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
      scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: startY))
        .press(
          forDuration: 0.05,
          thenDragTo: scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: endY)))
    }
    XCTAssertTrue(
      element.isHittable && viewport.contains(element.frame),
      "The complete hit target must be inside the visible viewport: \(element)")
  }

  func setDisplaySwitch(_ identifier: String, enabled: Bool, in app: XCUIApplication) {
    let row = app.switches[identifier]
    // SwiftUI Form exposes both the labelled row and its native switch as
    // switches. Tap the leaf control, then assert the actual resulting value.
    let leaf = row.switches.firstMatch
    let control = leaf.exists ? leaf : row
    let expected = enabled ? "1" : "0"
    if control.value as? String != expected { control.tap() }
    let updated = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", expected), object: control)
    XCTAssertEqual(XCTWaiter.wait(for: [updated], timeout: 5), .completed)
  }

  func waitForPanelToClose(in app: XCUIApplication) {
    let closed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: app.buttons["review.panel-done"])
    XCTAssertEqual(XCTWaiter.wait(for: [closed], timeout: 5), .completed)
    let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: app.buttons["review.next"])
    XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 5), .completed)
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
    if let url = Bundle(for: Self.self).url(
      forResource: name, withExtension: "png", subdirectory: "Baselines"),
      let expected = UIImage(contentsOfFile: url.path)
    {
      let difference = pixelDifference(expected, screenshot.image)
      XCTAssertLessThanOrEqual(
        difference, 0.002,
        "Visual regression \(name): changed fraction \(difference). Review before updating a baseline."
      )
    } else {
      let note = XCTAttachment(
        string:
          "No approved baseline for \(name). This run captures a native image for review; it does not establish pixel-regression acceptance."
      )
      note.name = "baseline-status-" + name
      note.lifetime = .keepAlways
      add(note)
    }
  }

  func pixelDifference(_ lhs: UIImage, _ rhs: UIImage) -> Double {
    guard let a = lhs.cgImage, let b = rhs.cgImage, a.width == b.width, a.height == b.height else {
      return 1
    }
    let count = a.width * a.height
    func pixels(_ image: CGImage) -> [UInt8] {
      var bytes = [UInt8](repeating: 0, count: count * 4)
      bytes.withUnsafeMutableBytes { pointer in
        let context = CGContext(
          data: pointer.baseAddress, width: image.width, height: image.height, bitsPerComponent: 8,
          bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(
          image, in: CGRect(x: 0, y: 0, width: CGFloat(image.width), height: CGFloat(image.height)))
      }
      return bytes
    }
    let left = pixels(a)
    let right = pixels(b)
    var changed = 0
    for index in 0..<count
    where (0..<4).contains(where: {
      abs(Int(left[index * 4 + $0]) - Int(right[index * 4 + $0])) > 8
    }) { changed += 1 }
    return Double(changed) / Double(count)
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
