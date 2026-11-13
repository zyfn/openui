import Foundation
import Combine

/// Presentation-only coalescing for rapidly growing text. The language parser
/// and Store always receive every source update; this object only limits how
/// often a native Markdown subtree is asked to lay out another full prefix.
@MainActor
final class NativeStreamingTextBuffer: ObservableObject {
  @Published private(set) var displayed: String?
  private var pending: String?
  private var scheduled: Task<Void, Never>?
  private let intervalNanoseconds: UInt64 = 48_000_000

  func receive(_ source: String, streaming: Bool) {
    guard streaming else {
      scheduled?.cancel(); scheduled = nil; pending = nil
      if displayed == nil || !displayed!.utf16.elementsEqual(source.utf16) {
        displayed = source
      }
      return
    }
    guard let visible = displayed else {
      displayed = source
      return
    }
    if visible.utf16.elementsEqual(source.utf16) {
      // An earlier pending suffix may still be newer; do not discard it.
      return
    }
    // Replacement, correction and document changes must never display a
    // stale prefix. Only a true append may be coalesced.
    guard source.utf16.starts(with: visible.utf16) else {
      scheduled?.cancel(); scheduled = nil; pending = nil
      displayed = source
      return
    }
    pending = source
    guard scheduled == nil else { return }
    scheduled = Task { @MainActor [weak self] in
      do { try await Task.sleep(nanoseconds: 48_000_000) }
      catch { return }
      self?.flush()
    }
  }

  func flush() {
    scheduled?.cancel(); scheduled = nil
    guard let pending else { return }
    self.pending = nil
    if displayed == nil || !displayed!.utf16.elementsEqual(pending.utf16) {
      displayed = pending
    }
  }

  func cancel() {
    scheduled?.cancel(); scheduled = nil
    pending = nil
  }
}
