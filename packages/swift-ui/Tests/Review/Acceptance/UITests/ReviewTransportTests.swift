import Foundation
import XCTest

final class ReviewTransportTests: ReviewTestCase {
  @objc func testTokenClockContinuesWhileTheConsumerIsIdleAndAcceptsRateChanges() {
    let finished = expectation(description: "Token-paced transport")
    Task {
      defer { finished.fulfill() }
      let source = String(repeating: "a", count: 80)
      let transport = try! ReviewPlaybackTransport(source: source, tokenByteLengths: Array(repeating: 1, count: 80))
      let rate = ReviewPlaybackRateControl(.slow)
      let start = DispatchTime.now().uptimeNanoseconds
      let sender = Task.detached { await transport.produce(rate: rate) }
      defer { sender.cancel() }
      try? await Task.sleep(nanoseconds: 300_000_000)
      let first = await transport.take()
      let elapsed = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000_000
      XCTAssertGreaterThan(first.receivedTokens, 0)
      XCTAssertEqual(Double(first.receivedTokens) / elapsed, 20, accuracy: 6)
      XCTAssertFalse(first.complete)
      rate.set(.veryFast)
      await sender.value
      let rest = await transport.take()
      XCTAssertTrue(rest.complete)
      XCTAssertEqual(first.text + rest.text, source)
    }
    wait(for: [finished], timeout: 5)
  }

  @objc func testUtf8TokenFragmentsAreDeliveredWithoutReplacementOrLostBytes() {
    let finished = expectation(description: "UTF-8 stream")
    Task {
      defer { finished.fulfill() }
      let source = "玉琮 → Paris 🏛️"
      let transport = try! ReviewPlaybackTransport(source: source,
        tokenByteLengths: Array(repeating: 1, count: source.utf8.count))
      let sender = Task.detached { await transport.produce(rate: ReviewPlaybackRateControl(.veryFast)) }
      defer { sender.cancel() }
      var actual = ""
      while true {
        let batch = await transport.take()
        actual += batch.text
        if batch.complete { break }
        try? await Task.sleep(nanoseconds: 5_000_000)
      }
      XCTAssertEqual(Data(actual.utf8), Data(source.utf8))
    }
    wait(for: [finished], timeout: 5)
  }
}
