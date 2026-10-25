import UIKit
import XCTest

final class ReviewCatalogTests: ReviewTestCase {
  func testReviewBrowserFindsComponentsInRealCombinations() {
    let app = launch("adaptive-card")
    app.buttons["review.tools"].tap()
    app.buttons["review.open-components"].tap()
    let search = app.searchFields.firstMatch
    if !search.isHittable { app.swipeDown() }
    search.tap()
    search.typeText("ImageTextLarge")
    app.buttons["review.component.ImageTextLarge"].tap()
    XCTAssertTrue(app.navigationBars["ImageTextLarge"].waitForExistence(timeout: 3))
    app.buttons["review.example.media-text"].tap()
    XCTAssertTrue(app.images["横幅石刻照片"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.navigationBars["ImageTextLarge"].exists, "Selecting a program dismisses the directory")
    capture(app, name: "workspace-component-to-preview")
    app.terminate()
  }

  func testScenarioNavigationAndVariants() {
    let app = launch("adaptive-card")
    app.buttons["review.scenarios"].tap()
    XCTAssertTrue(app.buttons["review.scenario.layout"].exists)
    capture(app, name: "workspace-scenario-directory")
    let panel = app.descendants(matching: .any).matching(identifier: "review.panel").firstMatch
    panel.buttons["review.scenario.layout"].tap()
    waitForPanelToClose(in: app)
    let title = app.staticTexts["review.scene-title"]
    XCTAssertEqual(title.label, "卡片动态布局")
    XCTAssertTrue(app.staticTexts["review.scene-position"].label.hasPrefix("1 / 8"))
    app.buttons["review.variants"].tap()
    app.buttons["review.variant.composition"].tap()
    XCTAssertEqual(title.label, "发现内容与图文阅读")
    let next = app.buttons["review.next"]
    let previous = app.buttons["review.previous"]
    app.scrollViews["review.surface"].swipeUp()
    XCTAssertTrue(next.isHittable)
    XCTAssertTrue(previous.isHittable)
    next.tap()
    XCTAssertEqual(title.label, "摘要、展开与来源")
    XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "石刻的结构与光影")).firstMatch.isHittable,
                  "A new scene starts at its top, including its actionable summary row")
    previous.tap()
    XCTAssertEqual(title.label, "卡片动态布局")
    previous.tap()
    XCTAssertEqual(title.label, "地图与地点选择", "Wrap to the last showcase, not a boundary fixture")
    next.tap()
    XCTAssertEqual(title.label, "卡片动态布局")
    capture(app, name: "scene-navigation-content")
    app.terminate()
  }

  func testCatalogAndEngineIntegrity() throws {
    let report = try matrixReport()
    XCTAssertEqual((report["scenarios"] as? [[String: Any]])?.count, 8,
      "Review the bounded matrix before adding another scenario family")
    XCTAssertLessThanOrEqual(try XCTUnwrap(report["variants"] as? Int), 25,
      "The bounded matrix includes separate default, custom and tab-contained Map compositions")
    XCTAssertEqual((report["missing"] as? [String])?.count, 0,
      "Every installed registration needs a real containing fixture, including data helpers")
    XCTAssertEqual((report["duplicateProgramIDs"] as? [String])?.count, 0)
    XCTAssertEqual(report["localizedVariants"] as? Int, report["variants"] as? Int)
    XCTAssertEqual((report["localizationFailures"] as? [String: String])?.count, 0,
      "English fixtures must change only localized string literals: \(report["localizationFailures"] ?? "")")
    XCTAssertEqual((report["failures"] as? [String: Any])?.count, 0,
      "All variants must have valid complete roots and identical final batch/streaming trees: \(report["failures"] ?? "")")
  }

  func testRepresentativeAdaptiveCompositions() throws {
    let report = try matrixReport()
    let scenarios = try XCTUnwrap(report["scenarios"] as? [[String: Any]])
    for (index, scenario) in scenarios.enumerated() {
      let id = try XCTUnwrap(scenario["id"] as? String)
      let example = try XCTUnwrap((scenario["variants"] as? [String])?.first)
      let narrow = index % 2 == 1
      let app = launch(example, dark: index % 3 == 2, large: acceptsLargeText && index % 4 == 3,
        width: narrow ? "narrow" : "available")
      let canvas = canvas(in: app)
      XCTAssertTrue(canvas.waitForExistence(timeout: 5))
      XCTAssertGreaterThan(canvas.frame.width, 0)
      XCTAssertLessThanOrEqual(canvas.frame.width, narrow ? 242 : app.windows.firstMatch.frame.width - 38)
      XCTAssertFalse(app.staticTexts["review.errors"].exists)
      XCTAssertTrue(app.buttons["review.next"].isHittable)
      capture(app, name: "matrix-\(id)-\(narrow ? "240" : "available")")
      app.terminate()
    }
  }

  func testAllVariantsRender() throws {
    let report = try matrixReport()
    let scenarios = try XCTUnwrap(report["scenarios"] as? [[String: Any]])
    var index = 0
    for scenario in scenarios {
      for example in try XCTUnwrap(scenario["variants"] as? [String]) {
        let app = launch(example, dark: index % 3 == 2, large: acceptsLargeText && index % 6 == 5,
          width: index % 3 == 1 ? "narrow" : index % 3 == 2 ? "standard" : "available")
        let canvas = canvas(in: app)
        XCTAssertTrue(canvas.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(canvas.frame.height, 0, "A registered renderer must produce a real composition")
        XCTAssertFalse(app.staticTexts["review.errors"].exists)
        capture(app, name: "matrix-variant-\(example)")
        app.terminate()
        index += 1
      }
    }
    XCTAssertEqual(index, try XCTUnwrap(report["variants"] as? Int))
  }

  func testDisplayConditionsPreserveProgramState() {
    let app = launch("adaptive-images", inspect: true)
    app.buttons["展开文字"].tap()
    let detail = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "留意人物的姿态、凿刻的痕迹")).firstMatch
    XCTAssertTrue(detail.exists)
    app.buttons["review.conditions-menu"].tap()
    app.segmentedControls["review.width-picker"].buttons["240"].tap()
    setDisplaySwitch("review.toggle-text", enabled: acceptsLargeText, in: app)
    setDisplaySwitch("review.toggle-appearance", enabled: true, in: app)
    XCTAssertTrue(app.staticTexts["review.conditions"].label.contains(acceptsLargeText ? "大字体" : "正常文字"))
    capture(app, name: "workspace-preview-conditions")
    app.buttons["review.panel-done"].tap()
    waitForPanelToClose(in: app)
    let preview = canvas(in: app)
    XCTAssertEqual(preview.frame.width, 240, accuracy: 2)
    XCTAssertTrue(detail.exists, "Display conditions retain the mounted SDK program and state")
    capture(app, name: "workspace-narrow-accessibility-dark")
    app.buttons["review.conditions-menu"].tap()
    app.buttons["恢复默认条件"].tap()
    app.buttons["review.panel-done"].tap()
    waitForPanelToClose(in: app)
    XCTAssertGreaterThan(preview.frame.width, 240)
    XCTAssertTrue(detail.exists)
    app.buttons["review.variants"].tap()
    app.buttons["review.variant.adaptive-card"].tap()
    XCTAssertEqual(app.staticTexts["review.scene-title"].label, "卡片动态布局")
    XCTAssertTrue(app.staticTexts["通用卡片，动态组合"].exists)
    XCTAssertFalse(app.staticTexts["review.errors"].exists)
    app.terminate()
  }

  func testClientBubbleTogglePreservesProgramState() {
    let app = launch("action-layout")
    let toggle = app.buttons["review.toggle-bubble"]
    XCTAssertEqual(toggle.value as? String, "关闭")
    let heading = app.staticTexts["给一处细节，多一点时间"]
    let originalX = heading.frame.minX
    capture(app, name: "workspace-without-client-bubble")
    toggle.tap()
    XCTAssertEqual(toggle.value as? String, "开启")
    XCTAssertEqual(heading.frame.minX, originalX + 16, accuracy: 1)
    capture(app, name: "workspace-client-bubble-light")
    let read = app.buttons["阅读介绍"]
    reveal(read, in: app)
    read.tap()
    let detail = app.staticTexts["从整体到局部"]
    XCTAssertTrue(detail.waitForExistence(timeout: 5))
    toggle.tap()
    XCTAssertEqual(toggle.value as? String, "关闭")
    XCTAssertTrue(detail.exists, "Removing the host surface must retain SDK state")
    toggle.tap()
    XCTAssertTrue(detail.exists)
    app.buttons["review.conditions-menu"].tap()
    setDisplaySwitch("review.toggle-appearance", enabled: true, in: app)
    app.buttons["review.panel-done"].tap()
    waitForPanelToClose(in: app)
    XCTAssertEqual(toggle.value as? String, "开启")
    capture(app, name: "workspace-client-bubble-dark")
    XCTAssertFalse(app.staticTexts["review.errors"].exists)
    app.terminate()
  }
}
