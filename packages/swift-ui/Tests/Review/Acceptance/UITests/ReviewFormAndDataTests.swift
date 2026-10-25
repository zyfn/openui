import UIKit
import XCTest

final class ReviewFormAndDataTests: ReviewTestCase {
  func testSavedProgramTableHeightContainsLastRow() throws {
    guard Bundle(for: Self.self).url(forResource: "ReviewProgram", withExtension: "openui") != nil else {
      throw XCTSkip("Prepare with --review-program for unchanged-source table isolation")
    }
    for mode in ["review-table", "review-table-card", "review"] {
      let app = launch(mode, inspect: true)
      continueAfterFailure = true
      let table = app.descendants(matching: .any).matching(identifier: "openui.table").firstMatch
      XCTAssertTrue(table.waitForExistence(timeout: 3))
      if table.frame.height < app.scrollViews["review.surface"].frame.height * 0.85 {
        reveal(table, in: app)
      }
      let content = table.children(matching: .other).firstMatch
      let labels = try JSONDecoder().decode([String].self, from: Data(app.staticTexts["review.tableLastRow"].label.utf8))
      XCTAssertEqual(labels.count, 5)
      let cells = labels.map { table.staticTexts[$0].firstMatch }
      let contentFrame = content.exists ? content.frame : .zero
      let lastFrame = cells.filter(\.exists).map(\.frame).reduce(CGRect.null) { $0.union($1) }
      let card = app.descendants(matching: .any).matching(identifier: "review.tableCard").firstMatch
      let cardFrame = card.exists ? card.frame : .zero
      let dump = XCTAttachment(string: "mode=\(mode) window=\(app.windows.firstMatch.frame) table=\(table.frame) content=\(contentFrame) last=\(lastFrame) card=\(cardFrame)")
      dump.name = "table-geometry-" + mode
      dump.lifetime = .keepAlways
      add(dump)
      capture(app, name: "table-height-" + mode)
      XCTAssertTrue(cells.allSatisfy(\.exists), "All five cells of the final evaluated row must exist")
      if cells.allSatisfy(\.exists) {
        XCTAssertGreaterThan(lastFrame.height, 0)
        XCTAssertGreaterThanOrEqual(lastFrame.minY, table.frame.minY - 2)
        XCTAssertLessThanOrEqual(lastFrame.maxY, contentFrame.maxY + 2, "Grid must include its last row")
        XCTAssertLessThanOrEqual(lastFrame.maxY, table.frame.maxY + 2, "Horizontal viewport must not clip the last row")
        if card.exists { XCTAssertLessThanOrEqual(lastFrame.maxY, cardFrame.maxY + 2, "Card must include its last row") }
      }
      app.terminate()
    }
  }

  func testTablePaginatesMixedCellsAndKeepsRowsReachable() {
    let app = launch("tables")
    let next = app.buttons["openui.table.next"]
    reveal(next, in: app)
    XCTAssertTrue(next.isHittable)
    XCTAssertFalse(app.staticTexts["记录 11"].exists)
    next.tap()
    XCTAssertTrue(app.staticTexts["记录 11"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.staticTexts["记录 01"].exists)
    XCTAssertEqual(app.staticTexts["openui.table.page"].label, "2 / 2")
    capture(app, name: "table-second-page-component-cell")
    let previous = app.buttons["openui.table.previous"]
    reveal(previous, in: app)
    previous.tap()
    XCTAssertTrue(app.staticTexts["记录 01"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.staticTexts["记录 11"].exists)
    app.terminate()
  }

  func testNativeChoicesSubmitThroughHostEvents() {
    let app = launch("choices", inspect: true)
    let topic = app.buttons["科学与技术"]
    reveal(topic, in: app)
    topic.tap()
    let full = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "完整细节")).firstMatch
    reveal(full, in: app)
    full.tap()
    let submit = app.buttons["保存偏好"]
    reveal(submit, in: app)
    submit.tap()
    let events = app.staticTexts["review.events"]
    reveal(events, in: app)
    let delivered = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "label == %@", "Events: 1"), object: events)
    XCTAssertEqual(XCTWaiter.wait(for: [delivered], timeout: 3), .completed)
    let state = app.staticTexts["review.state"].label
    XCTAssertTrue(state.contains("technology"))
    XCTAssertTrue(state.contains("full"))
    capture(app, name: "choices-submitted")
    app.terminate()
  }

  func testNativeEditableTablePersistsOnlyOnSave() {
    let app = launch("editing", inspect: true)
    let field = app.textFields["名称"].firstMatch
    XCTAssertTrue(field.waitForExistence(timeout: 5))
    field.tap()
    field.typeText("-changed")
    let save = app.buttons["Save Changes"]
    reveal(save, in: app)
    save.tap()
    let events = app.staticTexts["review.events"]
    reveal(events, in: app)
    let delivered = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "label == %@", "Events: 1"), object: events)
    XCTAssertEqual(XCTWaiter.wait(for: [delivered], timeout: 3), .completed)
    XCTAssertTrue(app.staticTexts["review.state"].label.contains("-changed"))
    capture(app, name: "editable-table-saved")
    app.terminate()
  }

  @objc func testNativeShortTableFitsAndWideTableScrolls() {
    let app = launch("tables")
    let window = app.windows.firstMatch.frame
    let first = app.staticTexts["方案"]
    let third = app.staticTexts["建议"]
    XCTAssertTrue(first.waitForExistence(timeout: 5))
    XCTAssertTrue(third.isHittable)
    XCTAssertGreaterThanOrEqual(first.frame.minX, window.minX + 18)
    XCTAssertLessThanOrEqual(
      third.frame.maxX, window.maxX - 18,
      "The third short column must fit without horizontal scrolling")
    XCTAssertLessThan(abs(first.frame.minY - third.frame.minY), 3)
    capture(app, name: "table-short-fits")
    let wide = app.scrollViews.containing(.staticText, identifier: "内容")
      .matching(NSPredicate(format: "identifier != %@", "review.surface")).firstMatch
    XCTAssertTrue(wide.exists)
    reveal(wide, in: app)
    let last = app.staticTexts["备注"]
    let before = last.frame.minX
    wide.swipeLeft()
    XCTAssertLessThan(
      last.frame.minX, before - 20,
      "A genuinely wide table must retain horizontal scrolling")
    XCTAssertTrue(last.isHittable)
    for label in ["归档与回顾：整理完以后再继续", "把新发现整理成可以继续阅读的线索，较长的说明应完整显示。"] {
      let cell = wide.staticTexts[label]
      XCTAssertTrue(cell.exists)
      XCTAssertGreaterThanOrEqual(cell.frame.minY, wide.frame.minY - 2)
      XCTAssertLessThanOrEqual(cell.frame.maxY, wide.frame.maxY + 2,
        "The final row's wrapped title and detail must fit inside the horizontal viewport")
    }
    capture(app, name: "table-wide-scrolled")
    app.terminate()
  }

  @objc func testNativeRichTableKeepsComposedCellsAlignedAndInteractive() {
    let app = launch("rich-table", inspect: true)
    let table = app.scrollViews.containing(.staticText, identifier: "类别")
      .matching(NSPredicate(format: "identifier != %@", "review.surface")).firstMatch
    let first = app.buttons["图文信息说明"]
    XCTAssertTrue(first.waitForExistence(timeout: 5))
    let second = app.buttons["数值摘要说明"]
    XCTAssertTrue(second.exists)
    XCTAssertLessThan(second.frame.minY - first.frame.minY, 320,
      "Rows follow their measured content instead of reserving a viewport-sized blank band")
    let before = table.frame
    first.tap()
    let detail = app.descendants(matching: .any).matching(identifier: "openui.popover.content").firstMatch
    XCTAssertTrue(detail.waitForExistence(timeout: 5))
    capture(app, name: "rich-table-contextual-detail")
    // Dismiss the anchored presentation without altering the document tree.
    app.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.17)).tap()
    XCTAssertEqual(table.frame.height, before.height, accuracy: 2)
    XCTAssertEqual(table.textFields.count, 0)
    XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "openui.map.canvas").firstMatch.exists)
    let preview = app.staticTexts["从整体读到细节"]
    for _ in 0..<3 where !preview.isHittable { table.swipeLeft() }
    XCTAssertTrue(preview.isHittable)
    capture(app, name: "rich-table-read-only-first-row")
    // The table assigns the outer cell its diagnostic identifier. Inspect the
    // preview cell, rather than assuming a child's identifier survives that modifier.
    let graphic = app.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "openui.table.cell.3.")).element(boundBy: 2)
    reveal(graphic, in: app)
    XCTAssertGreaterThan(graphic.frame.height, 20)
    XCTAssertTrue(app.staticTexts["轻量内容可自由组合；地图与完整详情放在表格之外。"].exists)
    capture(app, name: "rich-table-svg-cell")
    app.terminate()
  }

  func testTableCellBoundaryRejectsNestedInputsAndActions() throws {
    guard let url = Bundle(for: Self.self).url(forResource: "ReviewExamples", withExtension: "json"),
      let data = try? Data(contentsOf: url),
      let examples = try? JSONDecoder().decode([[String: String]].self, from: data),
      examples.contains(where: { $0["id"] == "table-cell-boundary" }) else {
      throw XCTSkip("Prepare the review project with its built-in boundary fixtures")
    }
    let app = launch("table-cell-boundary", inspect: true)
    let table = app.descendants(matching: .any).matching(identifier: "openui.table").firstMatch
    XCTAssertTrue(table.waitForExistence(timeout: 5))
    XCTAssertTrue(table.staticTexts["Visible direct"].exists)
    XCTAssertTrue(table.staticTexts["Visible nested"].exists)
    XCTAssertEqual(table.textFields.count, 0)
    XCTAssertEqual(table.textViews.count, 0)
    for label in ["Blocked direct submit", "Blocked nested submit", "Blocked form submit"] {
      XCTAssertFalse(app.buttons[label].exists, label)
    }
    let explanation = app.buttons["Open table detail"]
    reveal(explanation, in: app)
    explanation.tap()
    let popover = app.descendants(matching: .any).matching(identifier: "openui.popover.content").firstMatch
    XCTAssertTrue(popover.waitForExistence(timeout: 5))
    XCTAssertTrue(popover.staticTexts["Allowed explanation"].exists)
    XCTAssertEqual(popover.textFields.count, 0)
    XCTAssertFalse(app.buttons["Blocked popover submit"].exists)
    capture(app, name: "table-popover-keeps-read-only-boundary")
    app.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.17)).tap()
    let outsideInput = app.textFields["openui.field.outside"]
    reveal(outsideInput, in: app)
    XCTAssertTrue(outsideInput.isHittable, "The restriction belongs to Table, not the whole registry")
    let outsideAction = app.buttons["Outside action"]
    reveal(outsideAction, in: app)
    outsideAction.tap()
    XCTAssertTrue(app.staticTexts["Outside 1"].waitForExistence(timeout: 3))
    XCTAssertEqual(app.staticTexts["review.events"].label, "Events: 0")
    capture(app, name: "table-boundary-preserves-outside-interaction")
    app.terminate()
  }
}
