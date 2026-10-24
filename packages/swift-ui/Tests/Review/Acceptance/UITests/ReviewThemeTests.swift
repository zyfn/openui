import UIKit
import XCTest

final class ReviewThemeTests: ReviewTestCase {
  func testThemeChangesPreserveBindingsAndLocalDisclosure() {
    let app = launch("action-layout", inspect: true, theme: "default", bubble: true)
    XCTAssertEqual(app.buttons["review.toggle-bubble"].value as? String, "开启")
    let read = app.buttons["阅读介绍"]
    reveal(read, in: app)
    read.tap()
    let detail = app.staticTexts["从整体到局部"]
    XCTAssertTrue(detail.waitForExistence(timeout: 5))
    let save = app.buttons["留待以后"]
    reveal(save, in: app)
    save.tap()
    let saved = app.buttons["已收藏"]
    XCTAssertTrue(saved.waitForExistence(timeout: 3))
    let snapshot = app.staticTexts["review.state"]
    XCTAssertTrue(snapshot.waitForExistence(timeout: 3))
    let before = snapshot.label

    selectTheme("accent", in: app)
    XCTAssertTrue(detail.exists)
    XCTAssertTrue(saved.exists)
    XCTAssertEqual(snapshot.label, before, "Theme changes must not reparse or reset bound state")
    capture(app, name: "theme-accent-retained-actions")

    app.buttons["review.conditions-menu"].tap()
    app.segmentedControls["review.theme-picker"].buttons["SDK 默认"].tap()
    app.segmentedControls["review.width-picker"].buttons["240"].tap()
    setDisplaySwitch("review.toggle-appearance", enabled: true, in: app)
    setDisplaySwitch("review.toggle-text", enabled: acceptsLargeText, in: app)
    app.buttons["review.panel-done"].tap()
    waitForPanelToClose(in: app)
    XCTAssertEqual(app.buttons["review.theme-toggle"].value as? String, "default")
    XCTAssertEqual(canvas(in: app).frame.width, 240, accuracy: 2)
    XCTAssertTrue(detail.exists)
    XCTAssertTrue(saved.exists)
    XCTAssertEqual(snapshot.label, before)
    XCTAssertFalse(app.staticTexts["review.errors"].exists)
    capture(app, name: "theme-default-narrow-dark-retained-actions")
    app.terminate()

    // Accordion owns native disclosure state independently of the DSL's
    // bindings. It detects accidental renderer replacement on theme changes.
    let reading = launch("content", theme: "default")
    let disclosure = reading.buttons.matching(
      NSPredicate(format: "label CONTAINS %@", "安排之前，再看看这些")).firstMatch
    let expanded = reading.staticTexts.matching(
      NSPredicate(format: "label CONTAINS %@", "今天，什么让你换了一个角度")).firstMatch
    reveal(disclosure, in: reading)
    if expanded.exists { disclosure.tap() }
    XCTAssertFalse(expanded.exists)
    selectTheme("accent", in: reading)
    XCTAssertFalse(expanded.exists, "The same Accordion must remain collapsed")
    reveal(disclosure, in: reading)
    disclosure.tap()
    XCTAssertTrue(expanded.waitForExistence(timeout: 3))
    selectTheme("default", in: reading)
    XCTAssertTrue(expanded.exists, "The same Accordion must remain expanded")
    XCTAssertFalse(reading.staticTexts["review.errors"].exists)
    reading.terminate()
  }

  func testThemesShareRepresentativeContent() {
    let examples = [
      (id: "content", title: "本周，留一点时间给自己"),
      (id: "action-layout", title: "给一处细节，多一点时间"),
      (id: "data", title: "一周的专注时间"),
    ]
    for example in examples {
      let app = launch(example.id, theme: "default")
      let heading = app.staticTexts[example.title]
      XCTAssertTrue(heading.waitForExistence(timeout: 5))
      if example.id == "action-layout" {
        XCTAssertTrue(app.images["石刻参考照片"].waitForExistence(timeout: 5))
      }
      let canvasWidth = canvas(in: app).frame.width
      capture(app, name: "theme-default-\(example.id)")
      selectTheme("accent", in: app)
      XCTAssertTrue(heading.exists)
      XCTAssertEqual(canvas(in: app).frame.width, canvasWidth, accuracy: 1,
        "Both themes receive the same container and unchanged DSL")
      XCTAssertFalse(app.staticTexts["review.errors"].exists)
      capture(app, name: "theme-accent-\(example.id)")
      if example.id == "data" {
        let donut = app.descendants(matching: .any)
          .matching(NSPredicate(format: "label == %@", "PieChart")).firstMatch
        reveal(donut, in: app)
        for datum in ["阅读: 9.5", "创作: 9.5", "整理: 3"] {
          let value = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", datum)).firstMatch
          XCTAssertTrue(value.waitForExistence(timeout: 3),
            "The donut must expose real plotted data, not just an error-free empty Canvas")
        }
        capture(app, name: "theme-accent-data-distribution")
      }
      app.terminate()
    }
  }

  func testThemeRepresentativesAdaptToConstraints() {
    // Three intentional cross-sections, not every theme × scene × condition.
    // Run this method on the dedicated phone and wide simulator alike.
    let examples = [
      (id: "content", title: "本周，留一点时间给自己", theme: "default",
        width: "narrow", dark: false, large: true, bubble: false),
      (id: "action-layout", title: "给一处细节，多一点时间", theme: "accent",
        width: "standard", dark: true, large: false, bubble: true),
      (id: "data", title: "一周的专注时间", theme: "accent",
        width: "available", dark: true, large: true, bubble: false),
    ]
    for example in examples {
      let app = launch(example.id, dark: example.dark, large: acceptsLargeText && example.large,
        width: example.width, theme: example.theme, bubble: example.bubble)
      let preview = canvas(in: app)
      let heading = app.staticTexts[example.title]
      XCTAssertTrue(heading.waitForExistence(timeout: 5))
      XCTAssertGreaterThan(preview.frame.width, 0)
      if example.width == "narrow" {
        XCTAssertEqual(preview.frame.width, 240, accuracy: 2)
      } else if example.width == "standard" {
        XCTAssertEqual(preview.frame.width, 320, accuracy: 2)
      } else {
        XCTAssertLessThanOrEqual(preview.frame.width, app.windows.firstMatch.frame.width - 38)
      }
      XCTAssertGreaterThanOrEqual(heading.frame.minX, preview.frame.minX - 2)
      XCTAssertLessThanOrEqual(heading.frame.maxX, preview.frame.maxX + 2,
        "Dynamic Type must reflow inside the current container")
      assertHitTarget(app.buttons["review.theme-toggle"])
      XCTAssertFalse(app.staticTexts["review.errors"].exists)
      let device = app.windows.firstMatch.frame.width >= 700 ? "wide" : "phone"
      capture(app, name: "theme-\(example.theme)-\(example.id)-\(example.width)-\(device)")
      if example.id == "action-layout" {
        let action = app.buttons["阅读介绍"]
        reveal(action, in: app)
        assertHitTarget(action)
        action.tap()
        XCTAssertTrue(app.staticTexts["从整体到局部"].waitForExistence(timeout: 3))
      }
      app.terminate()
    }
  }

  func testDiscoverySelectionUpdatesSharedContentAcrossThemes() {
    let app = launch("composition", inspect: true)
    XCTAssertTrue(app.staticTexts["从一处细节，开始探索"].waitForExistence(timeout: 5))
    capture(app, name: "complex-discovery-top")
    let choose = app.buttons["看器物"]
    reveal(choose, in: app)
    choose.tap()
    let current = app.staticTexts["当前观察：材质与日常"]
    reveal(current, in: app)
    XCTAssertTrue(current.exists)
    let expand = app.buttons["展开观察笔记"]
    reveal(expand, in: app)
    expand.tap()
    let note = app.staticTexts.matching(
      NSPredicate(format: "label CONTAINS %@", "光滑的边缘、细小的缺口")).firstMatch
    XCTAssertTrue(note.waitForExistence(timeout: 3))
    let save = app.buttons["加入阅读清单"]
    reveal(save, in: app)
    save.tap()
    let saved = app.staticTexts["阅读清单已保留：器物上的纹理与时间"]
    XCTAssertTrue(saved.waitForExistence(timeout: 3))
    selectTheme("accent", in: app)
    XCTAssertTrue(current.exists)
    XCTAssertTrue(note.exists)
    XCTAssertTrue(saved.exists)
    XCTAssertTrue(app.buttons["已加入阅读清单"].exists)
    XCTAssertFalse(app.staticTexts["review.errors"].exists)
    capture(app, name: "complex-discovery-selected-and-saved")
    app.terminate()
  }

  func testComparisonDetailsStayReadOnlyAcrossThemes() {
    let app = launch("rich-table", inspect: true, theme: "accent")
    XCTAssertTrue(app.staticTexts["不同信息，清晰比较"].waitForExistence(timeout: 5))
    let detail = app.buttons["图文信息说明"]
    detail.tap()
    XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "openui.popover.content").firstMatch.waitForExistence(timeout: 3))
    capture(app, name: "complex-comparison-context")
    app.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.17)).tap()
    selectTheme("default", in: app)
    XCTAssertEqual(app.textFields.count, 0)
    XCTAssertTrue(detail.exists)
    XCTAssertTrue(app.staticTexts["不同信息，清晰比较"].exists)
    XCTAssertTrue(canvas(in: app).staticTexts["用缩略图辅助识别，短文字说明值得关注的细节。"].exists)
    capture(app, name: "complex-comparison-read-only-theme")
    app.terminate()
  }

  func testSpatialSelectionDrivesGroupedDetailsAndPlan() {
    let app = launch("map", inspect: true)
    XCTAssertTrue(app.staticTexts["地点一详情"].waitForExistence(timeout: 8))
    capture(app, name: "complex-spatial-map-top")
    let marker = app.descendants(matching: .any)
      .matching(identifier: "openui.map.marker.second").firstMatch
    XCTAssertTrue(marker.waitForExistence(timeout: 8))
    marker.tap()
    XCTAssertTrue(app.staticTexts["地点二详情"].waitForExistence(timeout: 5))
    let notes = app.buttons["观察线索"]
    reveal(notes, in: app)
    notes.tap()
    let current = app.staticTexts["正在查看：地点二"]
    XCTAssertTrue(current.waitForExistence(timeout: 3))
    selectTheme("accent", in: app)
    XCTAssertTrue(current.exists)
    let prepare = app.buttons["行前准备"]
    reveal(prepare, in: app)
    prepare.tap()
    let add = app.buttons["加入当前计划"]
    reveal(add, in: app)
    add.tap()
    XCTAssertTrue(app.staticTexts["计划已加入：地点二"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.buttons["已在当前计划中"].exists)
    XCTAssertFalse(app.staticTexts["review.errors"].exists)
    capture(app, name: "complex-spatial-selected-plan")
    app.terminate()
  }

  private func selectTheme(_ theme: String, in app: XCUIApplication) {
    let toggle = app.buttons["review.theme-toggle"]
    if toggle.value as? String != theme { toggle.tap() }
    let changed = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "value == %@", theme), object: toggle)
    XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 3), .completed)
  }
}
