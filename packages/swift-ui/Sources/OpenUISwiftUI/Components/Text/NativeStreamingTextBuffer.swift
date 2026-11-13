import Foundation
import Combine

/// A text-component presentation buffer, not a parser or a second document Store.
/// The scheduler is internal and injectable so its lifecycle is tested without
/// assuming that a wall-clock delay also completed a MainActor task.
@MainActor
final class NativeStreamingTextBuffer: ObservableObject {
  typealias Cancellation = @MainActor () -> Void
  typealias Scheduler = @MainActor (@escaping @MainActor () -> Void) -> Cancellation

  @Published private(set) var displayed: String?
  private var received: String?
  private var pending: String?
  private var cancelScheduled: Cancellation?
  private var generation: UInt64 = 0
  private let schedule: Scheduler

  init(schedule: Scheduler? = nil) {
    self.schedule = schedule ?? { delivery in
      let task = Task { @MainActor in
        do { try await Task.sleep(nanoseconds: 48_000_000) }
        catch { return }
        guard !Task.isCancelled else { return }
        delivery()
      }
      return { task.cancel() }
    }
  }

  /// Reading a view or fitting its size must not schedule or publish work.
  /// Corrections and completion are visible immediately, before onChange runs.
  func text(for source: String, streaming: Bool) -> String {
    guard streaming, let displayed, let received,
      source.utf16.starts(with: received.utf16) else { return source }
    return displayed
  }

  func receive(_ source: String, streaming: Bool) {
    let previous = received
    received = source
    guard streaming, let displayed else {
      cancel()
      publish(source)
      return
    }
    if displayed.utf16.elementsEqual(source.utf16) {
      cancel()
      return
    }
    // Compare against the last accepted input, not the older displayed prefix:
    // A -> AB (pending) -> AC is a correction, not append-only growth.
    guard let previous, source.utf16.starts(with: previous.utf16) else {
      cancel()
      publish(source)
      return
    }
    pending = source
    guard cancelScheduled == nil else { return }
    generation &+= 1
    let expectedGeneration = generation
    let cancellation = schedule { [weak self] in
      guard let self, self.generation == expectedGeneration else { return }
      self.flush()
    }
    // A custom scheduler may deliver synchronously. Do not retain its obsolete
    // cancellation handle after that delivery has already drained the buffer.
    if generation == expectedGeneration, pending != nil {
      cancelScheduled = cancellation
    } else {
      cancellation()
    }
  }

  func flush() {
    let next = pending
    cancel()
    if let next { publish(next) }
  }

  func cancel() {
    generation &+= 1
    let cancellation = cancelScheduled
    cancelScheduled = nil
    pending = nil
    cancellation?()
  }

  private func publish(_ source: String) {
    if displayed?.utf16.elementsEqual(source.utf16) != true {
      displayed = source
    }
  }
}
