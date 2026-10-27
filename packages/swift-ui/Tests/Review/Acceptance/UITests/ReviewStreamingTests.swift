import UIKit
import XCTest

final class ReviewStreamingTests: ReviewTestCase {
  @objc func testPlaybackSpeedIsAHostControlAndReplayStillCompletes() {
    continueAfterFailure = false
    let app = XCUIApplication(bundleIdentifier: "dev.swiftui.component-review")
    app.launchArguments = ["--case", "scene-day-trip", "--language", "en", "--tps", "40", "-AppleLanguages", "(en)"]
    app.launch()
    app.buttons["review.tools"].tap()
    let speed = app.descendants(matching: .any).matching(
      NSPredicate(format: "label BEGINSWITH %@", "Playback speed")).firstMatch
    if !speed.exists {
      let hierarchy = XCTAttachment(string: app.debugDescription)
      hierarchy.name = "playback-rate-menu-hierarchy"
      hierarchy.lifetime = .keepAlways
      add(hierarchy)
    }
    XCTAssertTrue(speed.waitForExistence(timeout: 5))
    speed.tap()
    app.buttons["160 TPS"].tap()
    XCTAssertTrue(app.staticTexts["review.scene-position"].label.contains("160 TPS"))
    app.buttons["review.replay"].tap()
    let ready = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "value == %@", "Ready to replay"), object: app.buttons["review.replay"])
    XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 60), .completed)
    XCTAssertFalse(app.staticTexts["review.transport-error"].exists)
    XCTAssertFalse(app.staticTexts["review.errors"].exists)
    app.terminate()
  }

  func testSixAuthoredCasesCompleteThroughTheDefaultSdkStream() {
    for id in ["scene-day-trip", "scene-two-day-trip", "scene-shopping",
               "scene-spending", "scene-gathering", "scene-learning"] {
      let app = XCUIApplication(bundleIdentifier: "dev.swiftui.component-review")
      app.launchArguments = ["--case", id, "--language", "en", "--tps", "320", "-AppleLanguages", "(en)"]
      app.launch()
      XCTAssertTrue(app.staticTexts["review.user-request"].waitForExistence(timeout: 10), id)
      let ready = XCTNSPredicateExpectation(
        predicate: NSPredicate(format: "value == %@", "Ready to replay"),
        object: app.buttons["review.replay"])
      XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 60), .completed, id)
      let content = canvas(in: app)
      XCTAssertGreaterThan(content.frame.height, 0, id)
      XCTAssertEqual(content.frame.width, app.windows.firstMatch.frame.width - 40, accuracy: 2, id)
      capture(app, name: "streamed-" + id)
      XCTAssertFalse(app.staticTexts["review.transport-error"].exists, id)
      XCTAssertFalse(app.staticTexts["review.errors"].exists, id)
      app.terminate()
    }
  }

  func testSceneUsesTheSdkStreamAndReplayRestartsIt() {
    let app = XCUIApplication(bundleIdentifier: "dev.swiftui.component-review")
    app.launchArguments = ["--case", "scene-day-trip", "--language", "en", "--tps", "320", "-AppleLanguages", "(en)"]
    app.launch()
    let replay = app.buttons["review.replay"]
    XCTAssertTrue(replay.waitForExistence(timeout: 10))
    XCTAssertTrue(app.staticTexts["review.user-request"].exists)
    let ready = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "value == %@", "Ready to replay"), object: replay)
    XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 60), .completed)
    XCTAssertTrue(app.staticTexts["Paris, at your own pace"].exists)
    let ending = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "€240 for two")).firstMatch
    XCTAssertTrue(ending.exists)
    XCTAssertTrue(ending.isHittable, "The document should follow the latest SDK-rendered content")
    replay.tap()
    let completedAgain = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "value == %@", "Ready to replay"), object: replay)
    XCTAssertEqual(XCTWaiter.wait(for: [completedAgain], timeout: 60), .completed)
    XCTAssertFalse(app.staticTexts["review.errors"].exists)
    capture(app, name: "scene-sdk-stream-replayed")
    app.terminate()
  }

  func testChangingScenesStopsTheOldSdkStream() {
    let app = XCUIApplication(bundleIdentifier: "dev.swiftui.component-review")
    app.launchArguments = ["--case", "scene-two-day-trip", "--language", "en", "--tps", "320", "-AppleLanguages", "(en)"]
    app.launch()
    let next = app.buttons["review.next"]
    XCTAssertTrue(next.waitForExistence(timeout: 10))
    next.tap()
    XCTAssertEqual(app.staticTexts["review.scene-title"].label, "Choose a camera")
    let replay = app.buttons["review.replay"]
    let ready = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "value == %@", "Ready to replay"), object: replay)
    XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 60), .completed)
    XCTAssertTrue(app.staticTexts["A camera worth taking with you"].exists)
    XCTAssertFalse(app.staticTexts["Paris, two days and one night"].exists)
    XCTAssertFalse(app.staticTexts["review.errors"].exists)
    app.terminate()
  }

  func testLongTwoDayProgramCompletesAndEnablesItsActions() {
    let app = XCUIApplication(bundleIdentifier: "dev.swiftui.component-review")
    app.launchArguments = ["--case", "scene-two-day-trip", "--language", "en", "--tps", "80", "-AppleLanguages", "(en)"]
    app.launch()
    let replay = app.buttons["review.replay"]
    XCTAssertTrue(replay.waitForExistence(timeout: 10))
    let sectionTitles = ["Flights, each way", "Your two-day itinerary", "A place to stay",
                         "Your places, on one map", "Recommended plan budget"]
    var earlySections = Set<String>()
    var unstablePhotos: [CGRect] = []
    var photoSamples = 0
    let ready = XCTNSPredicateExpectation(
      predicate: NSPredicate { _, _ in
        let visible = sectionTitles.map { app.staticTexts[$0].exists }
        for index in sectionTitles.indices where visible[index] && visible[..<index].contains(false) {
          earlySections.insert(sectionTitles[index])
        }
        let photo = app.images["Left Bank · garden double"].firstMatch
        if photo.exists && photo.frame.width > 0 {
          photoSamples += 1
          let frame = photo.frame
          if frame.width > 320 || abs(frame.height - frame.width / 1.5) > 3 {
            unstablePhotos.append(frame)
          }
        }
        return replay.value as? String == "Ready to replay"
      }, object: nil)
    XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 120), .completed)
    XCTAssertTrue(earlySections.isEmpty,
      "A later section appeared before an earlier one: \(earlySections.sorted())")
    XCTAssertGreaterThan(photoSamples, 0, "Inspect actual image frames while the two-day source is arriving")
    XCTAssertTrue(unstablePhotos.isEmpty,
      "Photos must enter at their cover crop, without full-width or elongated provisional frames: \(unstablePhotos)")
    XCTAssertFalse(app.staticTexts["review.transport-error"].exists)
    XCTAssertTrue(app.buttons["Overview"].isEnabled)
    XCTAssertTrue(app.buttons["Day 1"].isEnabled)
    XCTAssertTrue(app.buttons["Day 2"].isEnabled)
    XCTAssertFalse(app.staticTexts["review.errors"].exists)
    app.terminate()
  }
}
