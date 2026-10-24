import UIKit
import XCTest

final class ReviewEditorTests: ReviewTestCase {
  func testSelectedTabStaysVisibleAfterFontAndContainerChanges() {
    let app = launch("content")
    let source = """
      root=Tabs([TabItem("a","方案一",[TextContent("Pane A")]),TabItem("b","方案二",[TextContent("Pane B")]),TabItem("c","方案三",[TextContent("Pane C")])])
      """
    replaceDraft(with: source, in: app)
    runDraft(in: app)
    let third = app.buttons["openui.tab.c"]
    XCTAssertTrue(third.waitForExistence(timeout: 3))
    third.tap()
    XCTAssertTrue(third.isSelected)
    app.buttons["review.conditions-menu"].tap()
    app.segmentedControls["review.width-picker"].buttons["240"].tap()
    setDisplaySwitch("review.toggle-text", enabled: true, in: app)
    app.buttons["review.panel-done"].tap()
    waitForPanelToClose(in: app)
    let visible = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: third)
    XCTAssertEqual(XCTWaiter.wait(for: [visible], timeout: 3), .completed)
    XCTAssertTrue(third.isSelected)
    XCTAssertTrue(app.staticTexts["Pane C"].exists)
    let navigation = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "openui.tabs.")).firstMatch
    XCTAssertGreaterThanOrEqual(third.frame.minX, navigation.frame.minX - 2)
    XCTAssertLessThanOrEqual(third.frame.maxX, navigation.frame.maxX + 2)
    capture(app, name: "selected-tab-visible-after-font-and-width-change")
    app.terminate()
  }

  func testRepeatedOriginalReplacementWithThemeAndContainerChanges() throws {
    for round in 1...6 {
      try XCTContext.runActivity(named: "Original arithmetic reproduction \(round)") { _ in
        try testEditorRunsAndRerunsLangWithLiveBindings()
      }
    }
  }

  func testManualRerunsKeepDistinctArithmetic() throws {
    let app = launch("content", inspect: true)
    let programs: [(seed: Int, delta: Int)] = [(10, 2), (100, 3), (1000, 4)]
    for (index, program) in programs.enumerated() {
      let round = index + 1
      let label = "Add \(program.delta)"
      let source = """
        $count=\(program.seed)
        root=Stack([TextContent("Round \(round): "+$count),Button("\(label)",@Set($count,$count+\(program.delta)),"secondary")])
        """
      replaceDraft(with: source, in: app)
      runDraft(in: app)
      let initialized = app.staticTexts["Round \(round): \(program.seed)"].waitForExistence(timeout: 5)
      let before = try recordExecutionEvidence(in: app, phase: "arithmetic-\(round)-before")
      XCTAssertTrue(initialized,
        "Round \(round) must initialize to \(program.seed); state=\(before["review.state-current"] ?? "missing")")
      XCTAssertEqual(before["review.executed-source"], source)
      XCTAssertEqual(try decodedState(before["review.state-current"])["$count"] as? Int, program.seed)
      XCTAssertEqual(before["review.state-update-count"], "0")
      XCTAssertTrue(try decodedHistory(before["review.state-history"]).isEmpty)

      app.buttons[label].tap()
      let expected = program.seed + program.delta
      let reachedExpected = app.staticTexts["Round \(round): \(expected)"].waitForExistence(timeout: 3)
      let after = try recordExecutionEvidence(in: app, phase: "arithmetic-\(round)-after")
      capture(app, name: "editor-distinct-arithmetic-\(round)")
      XCTAssertTrue(reachedExpected,
        "Round \(round) requires \(program.seed) + \(program.delta) = \(expected); state=\(after["review.state-current"] ?? "missing"), history=\(after["review.state-history"] ?? "missing")")
      XCTAssertEqual(after["review.executed-source"], source)
      XCTAssertEqual(after["review.source-revision"], before["review.source-revision"])
      XCTAssertEqual(try decodedState(after["review.state-current"])["$count"] as? Int, expected)
      XCTAssertEqual(after["review.state-update-count"], "1")
      let history = try decodedHistory(after["review.state-history"])
      XCTAssertEqual(history.count, 1, "Round \(round): one click must cause exactly one state update")
      let update = try XCTUnwrap(history.last)
      XCTAssertEqual(try decodedState(update["before"] as? String)["$count"] as? Int, program.seed)
      XCTAssertEqual(try decodedState(update["after"] as? String)["$count"] as? Int, expected)
      XCTAssertFalse(app.staticTexts["review.errors"].exists)
    }
    app.terminate()
  }

  func testEditorRunsAndRerunsLangWithLiveBindings() throws {
    let app = launch("content", inspect: true)
    let first = """
      $count=0
      root=Stack([TextContent("First "+$count),Button("Add one",@Set($count,$count+1),"secondary")])
      """
    replaceDraft(with: first, in: app)
    capture(app, name: "editor-source-entry")
    runDraft(in: app)
    XCTAssertTrue(app.staticTexts["First 0"].waitForExistence(timeout: 5))
    XCTAssertEqual(app.staticTexts["review.scene-title"].label, "手动 Lang")
    app.buttons["Add one"].tap()
    XCTAssertTrue(app.staticTexts["First 1"].waitForExistence(timeout: 3))
    app.buttons["review.theme-toggle"].tap()
    app.buttons["review.toggle-bubble"].tap()
    XCTAssertTrue(app.staticTexts["First 1"].exists,
      "Theme and host surface changes retain the running manual program")
    app.buttons["review.conditions-menu"].tap()
    app.segmentedControls["review.width-picker"].buttons["240"].tap()
    app.buttons["review.panel-done"].tap()
    let conditionsClosed = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "exists == false"), object: app.buttons["review.panel-done"])
    XCTAssertEqual(XCTWaiter.wait(for: [conditionsClosed], timeout: 5), .completed)
    waitForEditorToClose(in: app)
    XCTAssertEqual(canvas(in: app).frame.width, 240, accuracy: 2)
    XCTAssertTrue(app.staticTexts["First 1"].exists,
      "Changing the manual program's available width must preserve its bound state")
    capture(app, name: "editor-manual-program-interaction")

    app.buttons["review.editor"].tap()
    let input = app.textViews["review.lang-input"]
    XCTAssertTrue(input.waitForExistence(timeout: 3))
    XCTAssertEqual(input.value as? String, first)
    let second = """
      $count=10
      root=Stack([TextContent("Second "+$count),Button("Add two",@Set($count,$count+2),"secondary")])
      """
    replaceOpenDraft(with: second, in: app)
    runDraft(in: app)
    XCTAssertTrue(app.staticTexts["Second 10"].waitForExistence(timeout: 5),
      "Explicit Run starts with the new program's initial state")
    XCTAssertFalse(app.staticTexts["First 1"].exists)
    let before = try recordExecutionEvidence(in: app, phase: "before-add-two")
    XCTAssertEqual(before["review.executed-source"], second,
      "Verify the exact source passed to SDK setSource, not just the editor's visible text")
    XCTAssertEqual(try decodedState(before["review.state-current"])["$count"] as? Int, 10)
    XCTAssertEqual(before["review.state-update-count"], "0")
    XCTAssertEqual(try decodedHistory(before["review.state-history"]).count, 0,
      "An explicit new execution must clear the preceding program's evidence")
    app.buttons["Add two"].tap()
    let reachedTwelve = app.staticTexts["Second 12"].waitForExistence(timeout: 3)
    // Save evidence before the assertion so a failed wait still records the
    // executed source, current action AST and every bounded state transition.
    let after = try recordExecutionEvidence(in: app, phase: "after-add-two")
    capture(app, name: "editor-rerun-after-add-two")
    XCTAssertTrue(reachedTwelve,
      "Expected Second 12; state=\(after["review.state-current"] ?? "missing"), history=\(after["review.state-history"] ?? "missing")")
    XCTAssertEqual(after["review.source-revision"], before["review.source-revision"])
    XCTAssertEqual(after["review.executed-source"], second)
    XCTAssertEqual(after["review.state-update-count"], "1")
    let history = try decodedHistory(after["review.state-history"])
    XCTAssertEqual(history.count, 1, "One tap must not publish additional intermediate state updates")
    let transition = try XCTUnwrap(history.last)
    XCTAssertEqual(try decodedState(transition["before"] as? String)["$count"] as? Int, 10)
    XCTAssertEqual(try decodedState(transition["after"] as? String)["$count"] as? Int, 12)
    XCTAssertFalse(app.staticTexts["review.errors"].exists)
    app.terminate()
  }

  func testCancelledDraftRetainsInputAndRunningSelection() {
    let app = launch("action-layout")
    let read = app.buttons["阅读介绍"]
    reveal(read, in: app)
    read.tap()
    let detail = app.staticTexts["从整体到局部"]
    XCTAssertTrue(detail.waitForExistence(timeout: 3))
    let save = app.buttons["留待以后"]
    reveal(save, in: app)
    save.tap()
    XCTAssertTrue(app.buttons["已收藏"].waitForExistence(timeout: 3))

    let draft = "root=Stack([TextContent(\"Unrun draft\")])"
    // Exercise the explicit tools-menu entry as well as the visible code button.
    app.buttons["review.tools"].tap()
    app.buttons["review.open-editor"].tap()
    XCTAssertTrue(app.textViews["review.lang-input"].waitForExistence(timeout: 3))
    replaceOpenDraft(with: draft, in: app)
    app.buttons["review.editor-cancel"].tap()
    waitForEditorToClose(in: app)
    XCTAssertTrue(detail.exists)
    XCTAssertTrue(app.buttons["已收藏"].exists)
    XCTAssertFalse(app.staticTexts["Unrun draft"].exists)

    app.buttons["review.editor"].tap()
    let input = app.textViews["review.lang-input"]
    XCTAssertTrue(input.waitForExistence(timeout: 3))
    XCTAssertEqual(input.value as? String, draft, "Closing the editor must not discard its draft")
    app.buttons["review.editor-cancel"].tap()
    waitForEditorToClose(in: app)
    XCTAssertTrue(detail.exists)
    XCTAssertTrue(app.buttons["已收藏"].exists)
    app.terminate()
  }

  func testCoreDiagnosticsAllowCorrectionAndSampleRestore() {
    let app = launch("content")
    let invalid = "root=MissingReviewComponent(\"Broken\")"
    replaceDraft(with: invalid, in: app)
    runDraft(in: app)
    let error = app.staticTexts["review.errors"]
    XCTAssertTrue(error.waitForExistence(timeout: 5))
    XCTAssertFalse(error.label.isEmpty)
    XCTAssertFalse(app.staticTexts["本周，留一点时间给自己"].exists,
      "An invalid manual program must not silently fall back to a sample")
    let diagnostic = error.label
    capture(app, name: "editor-core-diagnostic")

    app.buttons["review.editor"].tap()
    let input = app.textViews["review.lang-input"]
    XCTAssertTrue(input.waitForExistence(timeout: 3))
    XCTAssertEqual(input.value as? String, invalid)
    XCTAssertEqual(app.staticTexts["review.editor-diagnostics"].label, diagnostic,
      "The editor displays the same core diagnostic without replacement or suppression")
    let recovered = """
      ```openui-lang
      root=Stack([TextContent("Recovered program")])
      ```
      """
    replaceOpenDraft(with: recovered, in: app)
    runDraft(in: app)
    XCTAssertTrue(app.staticTexts["Recovered program"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.staticTexts["review.errors"].exists)

    app.buttons["review.tools"].tap()
    app.buttons["review.restore-sample"].tap()
    XCTAssertTrue(app.staticTexts["本周，留一点时间给自己"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.staticTexts["Recovered program"].exists)
    XCTAssertFalse(app.staticTexts["review.errors"].exists)
    app.buttons["review.editor"].tap()
    XCTAssertTrue(input.waitForExistence(timeout: 3))
    XCTAssertEqual(input.value as? String, recovered,
      "Restoring a sample does not delete the user's manual draft")
    app.buttons["review.editor-cancel"].tap()
    waitForEditorToClose(in: app)
    app.terminate()
  }

  private func replaceDraft(with source: String, in app: XCUIApplication) {
    app.buttons["review.editor"].tap()
    XCTAssertTrue(app.textViews["review.lang-input"].waitForExistence(timeout: 3))
    replaceOpenDraft(with: source, in: app)
  }

  private func replaceOpenDraft(with source: String, in app: XCUIApplication) {
    app.buttons["review.editor-clear"].tap()
    let input = app.textViews["review.lang-input"]
    input.tap()
    input.typeText(source)
    XCTAssertEqual(input.value as? String, source,
      "Native editing must retain literal quotes, punctuation and line breaks")
  }

  private func runDraft(in app: XCUIApplication) {
    app.buttons["review.editor-run"].tap()
    waitForEditorToClose(in: app)
  }

  private func waitForEditorToClose(in app: XCUIApplication) {
    let closed = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "exists == false"), object: app.buttons["review.editor-run"])
    XCTAssertEqual(XCTWaiter.wait(for: [closed], timeout: 5), .completed)
    let ready = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "hittable == true"), object: app.buttons["review.editor"])
    XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 5), .completed)
  }

  private func recordExecutionEvidence(in app: XCUIApplication, phase: String) throws -> [String: String] {
    let identifiers = ["review.executed-source", "review.source-revision", "review.state-current",
      "review.state-history", "review.state-update-count", "review.button-plans", "review.action-evaluations"]
    var report: [String: String] = ["phase": phase]
    for identifier in identifiers {
      let value = app.staticTexts[identifier]
      XCTAssertTrue(value.waitForExistence(timeout: 3), "Missing inspect evidence: \(identifier)")
      report[identifier] = value.label
    }
    let data = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
    let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
    attachment.name = "editor-execution-\(phase).json"
    attachment.lifetime = .keepAlways
    add(attachment)
    return report
  }

  private func decodedState(_ source: String?) throws -> [String: Any] {
    let source = try XCTUnwrap(source)
    return try XCTUnwrap(JSONSerialization.jsonObject(with: Data(source.utf8)) as? [String: Any])
  }

  private func decodedHistory(_ source: String?) throws -> [[String: Any]] {
    let source = try XCTUnwrap(source)
    return try XCTUnwrap(JSONSerialization.jsonObject(with: Data(source.utf8)) as? [[String: Any]])
  }
}
