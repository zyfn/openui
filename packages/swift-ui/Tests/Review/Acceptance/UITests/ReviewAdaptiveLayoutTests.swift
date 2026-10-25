import XCTest

/// Default acceptance: one phone, available width, normal text and the SDK theme.
/// Optional review controls remain available for manual exploration.
final class ReviewAdaptiveLayoutTests: ReviewTestCase {
  func testRepresentativeCompositionsAtAvailableWidth() throws {
    let scenarios = try XCTUnwrap(try matrixReport()["scenarios"] as? [[String: Any]])
    for scenario in scenarios {
      let name = try XCTUnwrap((scenario["variants"] as? [String])?.first)
      let app = launch(name)
      let content = canvas(in: app)
      XCTAssertTrue(content.waitForExistence(timeout: 5))
      XCTAssertGreaterThan(content.frame.height, 0)
      XCTAssertEqual(content.frame.width, app.windows.firstMatch.frame.width - 40, accuracy: 2)
      XCTAssertFalse(app.staticTexts["review.errors"].exists)
      capture(app, name: "adaptive-" + name)
      app.terminate()
    }
  }
}
