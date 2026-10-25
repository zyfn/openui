import UIKit
import XCTest

final class ReviewStandardPresentationTests: ReviewTestCase {
  func testTagSizesRichEntityRowsAndIconBadgesRenderTogether() {
    let app = launch("standard-presentation", language: "en")
    func tag(_ label: String) -> XCUIElement {
      app.descendants(matching: .any).matching(NSPredicate(
        format: "identifier == %@ AND label == %@", "openui.tag", label)).firstMatch
    }
    let small = tag("Small")
    let medium = tag("Medium")
    let large = tag("Large")
    XCTAssertTrue(small.waitForExistence(timeout: 5))
    XCTAssertGreaterThan(medium.frame.height, small.frame.height)
    XCTAssertGreaterThan(large.frame.height, medium.frame.height)
    XCTAssertTrue(app.staticTexts["Inverted icon badge"].exists)
    XCTAssertTrue(app.staticTexts["Museum"].exists)
    XCTAssertTrue(app.staticTexts["Total"].exists)
    XCTAssertFalse(app.staticTexts["**Museum**"].exists)
    XCTAssertFalse(app.staticTexts["*Admission*"].exists)
    XCTAssertFalse(app.staticTexts["review.errors"].exists)
    capture(app, name: "standard-tag-entity-icon-composition")
    app.terminate()
  }

  func testCodeBlockCopiesTheCurrentSourceWithoutFormattingChanges() {
    let app = launch("standard-presentation", language: "en")
    let copy = app.buttons.matching(identifier: "openui.code.copy").firstMatch
    reveal(copy, in: app)
    assertHitTarget(copy)
    copy.tap()
    assertCopiedCode("let city = \"Kyoto\"\nprint(city)\n", in: app)
    let update = app.buttons["Use updated code"]
    reveal(update, in: app)
    update.tap()
    reveal(copy, in: app)
    copy.tap()
    assertCopiedCode("let city = \"Osaka\"\nprint(city.uppercased())\n", in: app)
    XCTAssertFalse(app.staticTexts["review.errors"].exists)
    capture(app, name: "standard-code-highlighting-and-copy")
    app.terminate()
  }
}
