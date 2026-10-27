import CryptoKit
import Foundation

enum ReviewPlaybackRate: Int, CaseIterable, Identifiable {
  case slow = 20, steady = 40, normal = 80, fast = 160, veryFast = 320
  var id: Int { rawValue }
  var title: String { "\(rawValue) TPS" }
}

/// The simulated network clock can read changes without waiting for the UI actor.
final class ReviewPlaybackRateControl: @unchecked Sendable {
  private let lock = NSLock()
  private var value: Double
  init(_ rate: ReviewPlaybackRate = .normal) { value = Double(rate.rawValue) }
  func set(_ rate: ReviewPlaybackRate) {
    lock.lock(); defer { lock.unlock() }; value = Double(rate.rawValue)
  }
  var tokensPerSecond: Double {
    lock.lock(); defer { lock.unlock() }; return value
  }
}

/// Review-only token boundaries; the SDK never depends on a tokenizer.
struct ReviewTokenStreams: Decodable {
  let encoding: String
  let byteLengths: [String: [Int]]
  static let bundled: Self? = {
    guard let url = Bundle.main.url(forResource: "ReviewTokenStreams", withExtension: "json"),
      let data = try? Data(contentsOf: url) else { return nil }
    return try? JSONDecoder().decode(Self.self, from: data)
  }()
  func lengths(for source: String) -> [Int]? {
    let digest = SHA256.hash(data: Data(source.utf8)).map { String(format: "%02x", $0) }.joined()
    return byteLengths[digest]
  }
}

/// A paced network inbox, independent of parsing and SwiftUI. Backlogged deltas
/// are drained together without changing, dropping or reordering their bytes.
actor ReviewPlaybackTransport {
  struct Batch: Sendable {
    let text: String
    let receivedTokens: Int
    let complete: Bool
  }
  enum TransportError: Error { case invalidTokenBoundaries }
  private let source: Data
  private let byteOffsets: [Int]
  private var pending = Data()
  private var receivedTokens = 0
  private var complete = false

  init(source: String, tokenByteLengths: [Int]) throws {
    let bytes = Data(source.utf8)
    guard tokenByteLengths.allSatisfy({ $0 > 0 }), tokenByteLengths.reduce(0, +) == bytes.count else {
      throw TransportError.invalidTokenBoundaries
    }
    self.source = bytes
    var offsets = [0]
    for count in tokenByteLengths { offsets.append(offsets.last! + count) }
    byteOffsets = offsets
  }

  func produce(rate: ReviewPlaybackRateControl) async {
    var previous = DispatchTime.now().uptimeNanoseconds
    var budget = 0.0
    while receivedTokens < byteOffsets.count - 1 && !Task.isCancelled {
      let now = DispatchTime.now().uptimeNanoseconds
      budget += Double(now - previous) / 1_000_000_000 * rate.tokensPerSecond
      previous = now
      let next = min(Int(budget), byteOffsets.count - 1)
      if next > receivedTokens {
        pending.append(source[byteOffsets[receivedTokens]..<byteOffsets[next]])
        receivedTokens = next
      }
      if receivedTokens < byteOffsets.count - 1 {
        try? await Task.sleep(nanoseconds: 20_000_000)
      }
    }
    complete = receivedTokens == byteOffsets.count - 1
  }

  func take() -> Batch {
    // BPE boundaries can split one UTF-8 character. Wait for its remaining bytes
    // instead of repairing it or sending replacement characters into the SDK.
    guard let text = String(data: pending, encoding: .utf8) else {
      return Batch(text: "", receivedTokens: receivedTokens, complete: false)
    }
    pending.removeAll(keepingCapacity: true)
    return Batch(text: text, receivedTokens: receivedTokens, complete: complete)
  }
}
