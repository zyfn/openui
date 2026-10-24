import XCTest

final class ReviewSurfaceTests: ReviewTestCase {
  func testCardSurfaceVariantsPreserveDisclosureAndTabState() {
    let app = launch("content")
    let source = """
      $variant="card"
      root=Stack([
        Buttons([
          Button("Card",@Set($variant,"card"),"secondary"),
          Button("Clear",@Set($variant,"clear"),"secondary"),
          Button("Sunk",@Set($variant,"sunk"),"secondary")
        ]),
        Card([Stack([
          Accordion([AccordionItem("detail","Local detail",[TextContent("Detail remains expanded")])]),
          Tabs([
            TabItem("first","First pane",[TextContent("First pane content")]),
            TabItem("second","Second pane",[TextContent("Second pane content")])
          ])
        ],"column","m")],$variant),
        TextContent($variant)
      ],"column","m")
      """
    app.buttons["review.editor"].tap()
    let editor = app.textViews["review.lang-input"]
    XCTAssertTrue(editor.waitForExistence(timeout: 3))
    app.buttons["review.editor-clear"].tap()
    editor.tap()
    editor.typeText(source)
    XCTAssertEqual(editor.value as? String, source)
    app.buttons["review.editor-run"].tap()
    let closed = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "exists == false"), object: app.buttons["review.editor-run"])
    XCTAssertEqual(XCTWaiter.wait(for: [closed], timeout: 5), .completed)

    let disclosure = app.buttons.matching(
      NSPredicate(format: "label CONTAINS %@", "Local detail")).firstMatch
    let detail = app.staticTexts["Detail remains expanded"]
    reveal(disclosure, in: app)
    if detail.exists { disclosure.tap() }
    XCTAssertFalse(detail.exists)
    app.buttons["First pane"].tap()
    XCTAssertTrue(app.staticTexts["First pane content"].waitForExistence(timeout: 3))

    for (label, variant) in [("Clear", "clear"), ("Sunk", "sunk"), ("Card", "card")] {
      let button = app.buttons[label]
      reveal(button, in: app)
      button.tap()
      XCTAssertTrue(app.staticTexts[variant].waitForExistence(timeout: 3))
      XCTAssertFalse(detail.exists, "Changing only the Card surface must not reopen its Accordion")
      XCTAssertTrue(app.staticTexts["First pane content"].exists,
        "Changing only the Card surface must not reset the selected native tab")
      XCTAssertFalse(app.staticTexts["Second pane content"].exists)
    }

    reveal(disclosure, in: app)
    disclosure.tap()
    XCTAssertTrue(detail.waitForExistence(timeout: 3))
    for (label, variant) in [("Clear", "clear"), ("Sunk", "sunk"), ("Card", "card")] {
      let button = app.buttons[label]
      reveal(button, in: app)
      button.tap()
      XCTAssertTrue(app.staticTexts[variant].waitForExistence(timeout: 3))
      XCTAssertTrue(detail.exists, "The expanded state must also survive every surface variant")
      XCTAssertTrue(app.staticTexts["First pane content"].exists)
    }
    XCTAssertFalse(app.staticTexts["review.errors"].exists)
    capture(app, name: "card-surface-variants-preserve-local-state")
    app.terminate()
  }
}
