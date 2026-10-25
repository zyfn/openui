import XCTest

final class ReviewLanguageTests: ReviewTestCase {
  func testEnglishCompositionsFillAvailableWidth() {
    for (id, heading) in [
      ("choices", "Make it your own"),
      ("data", "A week of focused time"),
      ("action-layout", "Give a detail a little more time"),
    ] {
      let app = launch(id, language: "en")
      XCTAssertTrue(app.staticTexts[heading].waitForExistence(timeout: 5))
      XCTAssertEqual(app.buttons["review.language-toggle"].value as? String, "en")
      XCTAssertEqual(app.buttons["review.conditions-menu"].value as? String, "Available")
      let preview = canvas(in: app)
      XCTAssertEqual(preview.frame.width, app.scrollViews["review.surface"].frame.width - 40, accuracy: 1,
        "The default uses available width, with only the host's reading margins")
      assertVisibleEnglish(in: app)
      capture(app, name: "english-full-width-" + id)
      if id == "choices" {
        let radio = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Full detail")).firstMatch
        reveal(radio, in: app)
        radio.tap()
        assertVisibleEnglish(in: app)
        capture(app, name: "english-form-options-and-feedback")
      }
      app.terminate()
    }
  }

  func testLanguageSwitchUpdatesHostAndSample() {
    let app = launch("choices")
    XCTAssertTrue(app.staticTexts["让内容更适合你"].waitForExistence(timeout: 5))
    let width = canvas(in: app).frame.width
    app.buttons["review.language-toggle"].tap()
    XCTAssertTrue(app.staticTexts["Make it your own"].waitForExistence(timeout: 5))
    XCTAssertEqual(app.staticTexts["review.scene-title"].label, "Choices & forms")
    XCTAssertFalse(app.staticTexts["让内容更适合你"].exists)
    XCTAssertEqual(canvas(in: app).frame.width, width, accuracy: 1)
    app.buttons["review.conditions-menu"].tap()
    XCTAssertTrue(app.segmentedControls["review.language-picker"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.staticTexts["Container width"].exists)
    app.segmentedControls["review.width-picker"].buttons["240"].tap()
    app.buttons["review.panel-done"].tap()
    waitForPanelToClose(in: app)
    XCTAssertEqual(canvas(in: app).frame.width, 240, accuracy: 1)
    XCTAssertEqual(app.buttons["review.conditions-menu"].value as? String, "240")
    assertVisibleEnglish(in: app)
    capture(app, name: "english-explicit-240-container")
    app.buttons["review.language-toggle"].tap()
    XCTAssertTrue(app.staticTexts["让内容更适合你"].waitForExistence(timeout: 5))
    XCTAssertEqual(canvas(in: app).frame.width, 240, accuracy: 1,
      "Language does not install a different layout or container policy")
    XCTAssertFalse(app.staticTexts["review.errors"].exists)
    app.terminate()
  }

  func testLanguageSwitchKeepsManualSourceAndDraftLiteral() {
    let app = launch("adaptive-card", inspect: true)
    let source = """
      $n=1
      root=Stack([TextContent("Caller-owned content"),Button("Increment",@Set($n,$n+1)),TextContent(""+$n)])
      """
    app.buttons["review.editor"].tap()
    let editor = app.textViews["review.lang-input"]
    XCTAssertTrue(editor.waitForExistence(timeout: 3))
    app.buttons["review.editor-clear"].tap()
    editor.tap()
    editor.typeText(source)
    app.buttons["review.editor-run"].tap()
    let increment = app.buttons["Increment"]
    XCTAssertTrue(increment.waitForExistence(timeout: 5))
    increment.tap()
    let state = app.staticTexts["review.state-current"]
    let before = state.label
    let revision = app.staticTexts["review.source-revision"].label
    app.buttons["review.language-toggle"].tap()
    XCTAssertEqual(app.buttons["review.language-toggle"].value as? String, "en")
    XCTAssertEqual(app.staticTexts["review.executed-source"].label, source)
    XCTAssertEqual(state.label, before)
    XCTAssertEqual(app.staticTexts["review.source-revision"].label, revision)
    app.buttons["review.editor"].tap()
    XCTAssertTrue(editor.waitForExistence(timeout: 3))
    XCTAssertEqual(editor.value as? String, source)
    XCTAssertTrue(app.buttons["Cancel"].exists)
    app.buttons["review.editor-cancel"].tap()
    XCTAssertFalse(app.staticTexts["review.errors"].exists)
    app.terminate()
  }

  private func assertVisibleEnglish(in app: XCUIApplication) {
    for text in app.staticTexts.allElementsBoundByIndex where text.isHittable {
      XCTAssertFalse(text.label.unicodeScalars.contains { (0x3400...0x9FFF).contains(Int($0.value)) },
        "An English preview contains untranslated visible text: \(text.label)")
    }
  }
}
