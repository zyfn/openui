import UIKit
import XCTest

final class ReviewMediaTests: ReviewTestCase {
  func testSavedProgramReview() throws {
    guard Bundle(for: Self.self).url(forResource: "ReviewProgram", withExtension: "openui") != nil else {
      throw XCTSkip("Prepare --review-program to review an external source; it is not part of the fixed SDK matrix")
    }
    let app = launch("review")
    XCTAssertFalse(app.staticTexts["No saved review program"].exists)
    capture(app, name: "saved-program-top")
    let scroll = app.scrollViews["review.surface"]
    for index in 1...5 {
      scroll.swipeUp(velocity: .slow)
      capture(app, name: "saved-program-page-\(index)")
    }
    app.terminate()
  }

  func testPromptCompositionExamples() throws {
    struct Example: Decodable { let id: String; let title: String }
    guard let url = Bundle(for: Self.self).url(forResource: "ReviewExamples", withExtension: "json") else {
      throw XCTSkip("Prepare with --review-examples to replay exported guidance examples")
    }
    let examples = try JSONDecoder().decode([Example].self, from: Data(contentsOf: url))
    XCTAssertFalse(examples.isEmpty)
    for example in examples {
      let app = launch(example.id, inspect: true)
      XCTAssertTrue(app.staticTexts[example.title].waitForExistence(timeout: 3))
      capture(app, name: example.id)
      app.terminate()
    }
  }

  func testGalleryEmptySingleAndManyUseTheSameProgram() {
    let app = launch("media-states", inspect: true)
    let clear = app.buttons["清空图库"]
    reveal(clear, in: app)
    clear.tap()
    XCTAssertFalse(app.buttons["openui.gallery.image.0"].exists)
    capture(app, name: "matrix-gallery-empty")
    let single = app.buttons["只看一张"]
    reveal(single, in: app)
    single.tap()
    XCTAssertTrue(app.buttons["openui.gallery.image.0"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.buttons["openui.gallery.image.1"].exists)
    capture(app, name: "matrix-gallery-single")
    let many = app.buttons["恢复图集"]
    reveal(many, in: app)
    many.tap()
    XCTAssertTrue(app.buttons["openui.gallery.image.4"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.staticTexts["review.errors"].exists)
    capture(app, name: "matrix-gallery-many")
    app.terminate()
  }

  func testNativeMediaUnavailableCollapsesAndPreservesContent() {
    let app = launch("media-states", inspect: true, media: "unavailable")
    let summary = app.staticTexts.matching(NSPredicate(format: "label IN %@", ["9 images unavailable", "9 张图片暂不可用"])).firstMatch
    XCTAssertTrue(summary.waitForExistence(timeout: 8))
    let gallery = app.descendants(matching: .any).matching(identifier: "openui.gallery").firstMatch
    reveal(gallery, in: app)
    XCTAssertLessThan(gallery.frame.height, app.windows.firstMatch.frame.height * 0.35)
    XCTAssertFalse(app.buttons["openui.gallery.image.0"].exists)
    XCTAssertTrue(app.staticTexts["观察作品的细节"].exists)
    XCTAssertTrue(app.staticTexts["这段摘要在图片不可用时仍应保留。"].exists)
    capture(app, name: "media-all-unavailable")
    app.buttons["openui.gallery.details"].tap()
    XCTAssertTrue(app.staticTexts["参考照片一"].exists)
    XCTAssertTrue(app.staticTexts["参考照片九"].exists)
    let choice = app.buttons["保留本地选择"]
    reveal(choice, in: app)
    choice.tap()
    XCTAssertTrue(app.staticTexts["1"].exists)
    XCTAssertFalse(app.staticTexts["review.errors"].exists)
    capture(app, name: "media-unavailable-descriptions")
    app.terminate()
  }

  func testNativeGalleryLoadedPreviewAndReadingPosition() {
    let app = launch("media-states", inspect: true)
    reveal(app.staticTexts["参考图库"], in: app)
    app.scrollViews["review.surface"].swipeUp(velocity: .slow)
    let first = app.buttons["openui.gallery.image.0"]
    XCTAssertTrue(first.waitForExistence(timeout: 8))
    reveal(first, in: app)
    let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: first)
    XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 5), .completed)
    let before = first.frame
    capture(app, name: "media-normal-photos")
    first.tap()
    let close = app.buttons["openui.gallery.close"]
    XCTAssertTrue(close.waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label IN %@", ["All photos", "全部图片"])).firstMatch.exists)
    let second = app.buttons["openui.gallery.thumbnail.1"]
    XCTAssertTrue(second.exists)
    second.tap()
    XCTAssertTrue(app.staticTexts["2 / 9"].exists)
    capture(app, name: "media-gallery-modal-selection")
    close.tap()
    XCTAssertFalse(close.exists)
    XCTAssertEqual(first.frame.minY, before.minY, accuracy: 3, "Closing preview retains the underlying reading position")
    let all = app.buttons["openui.gallery.showAll"]
    reveal(all, in: app)
    all.tap()
    XCTAssertTrue(close.waitForExistence(timeout: 5))
    let last = app.buttons["openui.gallery.thumbnail.8"]
    let strip = app.scrollViews.containing(.button, identifier: "openui.gallery.thumbnail.0").firstMatch
    for _ in 0..<4 where !last.isHittable { strip.swipeLeft() }
    XCTAssertTrue(last.isHittable)
    last.tap()
    XCTAssertTrue(app.staticTexts["9 / 9"].exists, "Show All must retain the complete supplied collection")
    capture(app, name: "media-gallery-show-all")
    close.tap()
    XCTAssertFalse(app.staticTexts["review.errors"].exists)
    app.terminate()
  }

  func testNativeMediaLoadingIsDistinctAndCompactInGallery() {
    let app = launch("media-states", media: "loading")
    XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "openui.media.loading").firstMatch.waitForExistence(timeout: 5))
    reveal(app.staticTexts["参考图库"], in: app)
    app.scrollViews["review.surface"].swipeUp(velocity: .slow)
    let gallery = app.descendants(matching: .any).matching(identifier: "openui.gallery").firstMatch
    XCTAssertLessThan(gallery.frame.height, app.windows.firstMatch.frame.height * 0.4)
    XCTAssertFalse(app.buttons["openui.gallery.image.0"].isEnabled)
    XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label IN %@", ["9 images unavailable", "9 张图片暂不可用"])).firstMatch.exists)
    capture(app, name: "media-loading-gallery")
    app.terminate()
  }

  func testNativeGalleryPartialFailureAndRetry() {
    let app = launch("media-states", inspect: true, media: "partial")
    reveal(app.staticTexts["参考图库"], in: app)
    app.scrollViews["review.surface"].swipeUp(velocity: .slow)
    let good = app.buttons["openui.gallery.image.0"]
    XCTAssertTrue(good.waitForExistence(timeout: 8))
    let summary = app.staticTexts["4 images unavailable"]
    XCTAssertTrue(summary.waitForExistence(timeout: 8))
    reveal(good, in: app)
    XCTAssertFalse(app.buttons["openui.gallery.image.1"].exists)
    capture(app, name: "media-partial-photos")
    good.tap()
    let failed = app.buttons["openui.gallery.thumbnail.1"]
    XCTAssertTrue(failed.waitForExistence(timeout: 5))
    XCTAssertFalse(failed.isEnabled, "A known failed image must not pretend to be viewable")
    app.buttons["openui.gallery.close"].tap()
    app.terminate()

    let retry = launch("media-states", inspect: true, media: "retry")
    XCTAssertTrue(retry.staticTexts["9 images unavailable"].waitForExistence(timeout: 8))
    let button = retry.buttons["openui.gallery.retry"]
    reveal(button, in: retry)
    button.tap()
    let recovered = retry.buttons["openui.gallery.image.0"]
    XCTAssertTrue(recovered.waitForExistence(timeout: 8))
    let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: recovered)
    XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 5), .completed)
    XCTAssertFalse(retry.staticTexts["9 images unavailable"].exists)
    capture(retry, name: "media-retry-recovered")
    retry.terminate()
  }

  @objc func testNativeImageCompositions() {
    for name in ["images", "image-cards", "composition"] {
      for dark in [false, true] {
        let app = launch(name, dark: dark, inspect: true)
        let loaded = XCTNSPredicateExpectation(
          predicate: NSPredicate { _, _ in
            let monitor = app.staticTexts["review.images"]
            guard monitor.exists else { return false }
            return (Int(monitor.label.split(separator: " ").last ?? "0") ?? 0) > 0
              && app.activityIndicators.count == 0
          }, object: nil)
        XCTAssertEqual(
          XCTWaiter.wait(for: [loaded], timeout: 8), .completed,
          "Real bundled image bytes must reach the standard AsyncImage renderer")
        XCTAssertFalse(app.buttons["普通图文说明"].exists)
        let prefix = name + (dark ? "-dark" : "-light")
        capture(app, name: prefix + "-top")
        app.scrollViews["review.surface"].swipeUp()
        capture(app, name: prefix + "-middle")
        app.scrollViews["review.surface"].swipeUp()
        capture(app, name: prefix + "-bottom")
        app.terminate()
      }
    }
  }
}
