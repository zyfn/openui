import UIKit
import XCTest

final class ReviewLayoutTests: ReviewTestCase {
  func testNativeLightAndDarkRendering() {
    for name in ["choices", "content", "data", "editing"] {
      for dark in [false, true] {
        let app = launch(name, dark: dark)
        if name == "choices" {
          let first = app.buttons["设计与创作"].frame
          let second = app.buttons["科学与技术"].frame
          XCTAssertLessThan(
            abs(first.minY - second.minY), 4, "Normal-size choices must share a row on this iPhone")
          XCTAssertFalse(first.intersects(second), "Choice hit targets must not overlap")
          XCTAssertGreaterThanOrEqual(first.height, 44)
        }
        if name == "content" {
          let first = app.staticTexts["阅读"].firstMatch.frame
          let second = app.staticTexts["灵感"].firstMatch.frame
          XCTAssertLessThan(abs(first.minY - second.minY), 4, "Compact overview cards share a row")
          XCTAssertLessThan(first.maxX, second.minX)
        }
        capture(app, name: name + (dark ? "-dark" : "-light"))
        app.terminate()
      }
    }
  }

  func testMediaTextBannerAndInlineFormatting() throws {
    let referenceSize = try fixtureImageSize("detail")
    for large in textSizes {
      let app = launch("media-text", large: large, inspect: true)
      let image = app.images["横幅石刻照片"]
      XCTAssertTrue(image.waitForExistence(timeout: 5))
      XCTAssertGreaterThan(image.frame.width, app.windows.firstMatch.frame.width * 0.7)
      // Compare with the original bundled asset, independent of its orientation
      // or replacement with another licensed photograph.
      XCTAssertEqual(image.frame.height / image.frame.width,
        referenceSize.height / referenceSize.width, accuracy: 0.02)
      let title = app.staticTexts["从一处细节，读懂一件作品及其背后的故事"]
      XCTAssertGreaterThanOrEqual(title.frame.minY, image.frame.maxY + 8)
      XCTAssertEqual(title.frame.minX, image.frame.minX, accuracy: 2)
      let summary = app.staticTexts["重点：先看构图，再留意表面的纹理与光线。"]
      XCTAssertTrue(summary.exists, "Inline Markdown must render without literal delimiters")
      XCTAssertFalse(canvas(in: app).staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "**重点**")).firstMatch.exists,
        "Inspect rendered content, not the inspector's intentionally unmodified source text")
      capture(app, name: large ? "media-text-accessibility" : "media-text-light")
      let expand = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "展开观察方法")).firstMatch
      let detail = app.staticTexts["完整说明保留在这里，可以反复展开和收起，不占据摘要的阅读空间。"]
      // Upstream Accordion initially opens its newest item.
      if detail.exists {
        reveal(expand, in: app)
        expand.tap()
        XCTAssertFalse(detail.isHittable, "Collapsed native disclosure content must not be reachable")
      }
      reveal(expand, in: app)
      expand.tap()
      XCTAssertTrue(detail.waitForExistence(timeout: 3))
      reveal(detail, in: app)
      capture(app, name: large ? "media-text-expanded-accessibility" : "media-text-expanded")
      reveal(expand, in: app)
      expand.tap()
      XCTAssertFalse(detail.isHittable)
      let price = app.staticTexts["12.8k"]
      let button = app.buttons["打开来源了解更多"]
      reveal(button, in: app)
      XCTAssertFalse(price.frame.intersects(button.frame), "Footer values and actions must not overlap")
      XCTAssertGreaterThanOrEqual(button.frame.height, 44)
      app.terminate()
    }
  }

  func testAccessibleTextRemainsScrollable() {
    let app = launch("choices", large: true)
    capture(app, name: "choices-accessibility-top")
    let submit = app.buttons["保存偏好"]
    reveal(submit, in: app)
    capture(app, name: "choices-accessibility-bottom")
    app.terminate()
  }

  @objc func testNativeCarouselPageGrouping() {
    let app = launch("carousel")
    let title = app.staticTexts["第一页标题"]
    let body = app.staticTexts["同页正文"]
    let next = app.staticTexts["第二页标题"]
    XCTAssertTrue(title.waitForExistence(timeout: 5))
    let visible = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
      title.frame.minX.isFinite && body.frame.minX.isFinite && title.isHittable && body.isHittable
    }, object: nil)
    XCTAssertEqual(XCTWaiter.wait(for: [visible], timeout: 3), .completed)
    XCTAssertLessThan(
      abs(title.frame.minX - body.frame.minX), 3,
      "Elements in one page must share its horizontal origin")
    XCTAssertGreaterThan(
      body.frame.minY, title.frame.minY + 10,
      "Page content must stack within the page, not become a separate page")
    XCTAssertTrue(title.isHittable)
    XCTAssertFalse(next.isHittable, "Only the selected page is exposed for interaction")
    capture(app, name: "carousel-multiple-elements")
    let forward = app.buttons["openui.carousel.next"]
    reveal(forward, in: app)
    forward.tap()
    let moved = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
      app.staticTexts["openui.carousel.page"].label == "2 / 2"
    }, object: nil)
    XCTAssertEqual(XCTWaiter.wait(for: [moved], timeout: 5), .completed)
    let image = app.images["竖排显式图片尺寸"].firstMatch
    reveal(image, in: app)
    XCTAssertTrue(image.waitForExistence(timeout: 8))
    XCTAssertEqual(image.frame.width, 96, accuracy: 2)
    XCTAssertEqual(image.frame.height, 96, accuracy: 2)
    for name in ["utensils-crossed", "soup", "wheat"] {
      XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "openui.icon." + name).firstMatch.exists)
    }
    capture(app, name: "carousel-explicit-image-and-icons")
    let back = app.buttons["openui.carousel.previous"]
    reveal(back, in: app)
    back.tap()
    let returned = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
      app.staticTexts["openui.carousel.page"].label == "1 / 2"
    }, object: nil)
    XCTAssertEqual(XCTWaiter.wait(for: [returned], timeout: 5), .completed)
    app.terminate()
  }

  @objc func testNativeThumbnailFollowsChangingText() {
    let app = launch("adaptive-images")
    let photo = app.descendants(matching: .any).matching(
      NSPredicate(format: "label == %@", "自适应缩略图")
    ).firstMatch
    if !photo.waitForExistence(timeout: 8) {
      let tree = XCTAttachment(string: app.debugDescription)
      tree.name = "adaptive-image-accessibility"
      tree.lifetime = .keepAlways
      add(tree)
      XCTFail("The thumbnail must expose its alternative text")
      return
    }
    let title = app.staticTexts["内容会变化"]
    let short = app.staticTexts["看一处细节。"]
    let settled = XCTNSPredicateExpectation(
      predicate: NSPredicate { _, _ in
        photo.frame.height <= max(44, short.frame.maxY - title.frame.minY) + 2
      }, object: nil)
    XCTAssertEqual(XCTWaiter.wait(for: [settled], timeout: 3), .completed)
    let original = photo.frame.size
    capture(app, name: "image-row-short-copy")
    app.buttons["展开文字"].tap()
    let expanded = XCTNSPredicateExpectation(
      predicate: NSPredicate { _, _ in
        photo.frame.height > original.height + 20
      }, object: nil)
    XCTAssertEqual(XCTWaiter.wait(for: [expanded], timeout: 3), .completed)
    XCTAssertLessThanOrEqual(photo.frame.maxX + 10, title.frame.minX)
    capture(app, name: "image-row-expanded-copy")
    app.buttons["收起文字"].tap()
    let collapsed = XCTNSPredicateExpectation(
      predicate: NSPredicate { _, _ in
        abs(photo.frame.height - original.height) < 2 && abs(photo.frame.width - original.width) < 2
      }, object: nil)
    XCTAssertEqual(XCTWaiter.wait(for: [collapsed], timeout: 3), .completed)
    capture(app, name: "image-row-collapsed-copy")
    app.terminate()

    guard acceptsLargeText else { return }
    let accessible = launch("adaptive-images", large: true)
    let largePhoto = accessible.descendants(matching: .any).matching(
      NSPredicate(format: "label == %@", "自适应缩略图")
    ).firstMatch
    let largeTitle = accessible.staticTexts["内容会变化"]
    reveal(largeTitle, in: accessible)
    let beside = largePhoto.frame.maxX + 8 <= largeTitle.frame.minX
    let above = largePhoto.frame.maxY + 8 <= largeTitle.frame.minY
    XCTAssertTrue(beside || above,
      "Measured media and accessible copy must remain separate, whether they fit beside or above")
    XCTAssertLessThanOrEqual(largeTitle.frame.maxX, canvas(in: accessible).frame.maxX + 2)
    capture(accessible, name: "image-row-accessible-copy")
    accessible.terminate()
  }

  @objc func testNativeCardChildrenReflowWhenLayoutAndCopyChange() {
    let app = launch("adaptive-card", inspect: true)
    let loaded = XCTNSPredicateExpectation(
      predicate: NSPredicate { _, _ in
        let monitor = app.staticTexts["review.images"]
        return monitor.exists && monitor.label != "Images: 0" && app.activityIndicators.count == 0
      }, object: nil)
    XCTAssertEqual(XCTWaiter.wait(for: [loaded], timeout: 8), .completed)
    let image = app.descendants(matching: .any).matching(
      NSPredicate(format: "label == %@", "通用卡片图片")).firstMatch
    let title = app.staticTexts["同一张卡片"]
    XCTAssertTrue(image.exists)
    XCTAssertTrue(title.exists)
    XCTAssertLessThanOrEqual(image.frame.maxX + 10, title.frame.minX)
    XCTAssertGreaterThan(image.frame.width, 44)
    XCTAssertEqual(image.frame.width / image.frame.height, 1.5, accuracy: 0.03, "Image retains the pinned upstream default aspect")
    capture(app, name: "card-row-short-copy")

    app.buttons["展开说明"].tap()
    let expanded = app.staticTexts[
      "图像与说明来自同一个通用容器。文字变长时自然换行，卡片高度跟随内容增长。模型可以选择横向、纵向或允许换行的排列，而不需要为每一种内容新增组件。"]
    XCTAssertTrue(expanded.waitForExistence(timeout: 5))
    XCTAssertGreaterThan(expanded.frame.height, 50)
    XCTAssertLessThanOrEqual(image.frame.maxX + 10, title.frame.minX)
    capture(app, name: "card-row-long-copy")

    app.buttons["纵向排列"].tap()
    XCTAssertLessThanOrEqual(image.frame.maxY + 10, title.frame.minY)
    capture(app, name: "card-column-long-copy")
    app.buttons["允许换行"].tap()
    XCTAssertGreaterThan(image.frame.width, 44)
    XCTAssertGreaterThan(image.frame.height, 32)
    XCTAssertLessThanOrEqual(image.frame.maxY + 10, title.frame.minY)
    capture(app, name: "card-wrapped-long-copy")
    app.terminate()
  }
}
