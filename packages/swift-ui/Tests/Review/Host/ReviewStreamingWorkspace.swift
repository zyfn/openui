import OpenUILang
import OpenUISwiftUI
import SwiftUI

/// Controlled feeds exercise the SDK while it is mounted. These controls are
/// test inputs, not alternate parsing, component or business presentation logic.
@MainActor struct ReviewStreamingWorkspace: View {
  let library: OpenUIComponentLibrary
  let mode: String
  private let source: String
  @StateObject private var state: OpenUIState
  @StateObject private var evidence = ReviewEvidence()
  @State private var offset = 0
  @State private var stage = 0

  init(library: OpenUIComponentLibrary, mode: String) {
    self.library = library; self.mode = mode
    if mode == "original", let url = Bundle.main.url(forResource: "StreamProgram", withExtension: "openui"),
      let text = try? String(contentsOf: url, encoding: .utf8) { source = text }
    else { source = mode == "gallery" ? ReviewStreamingPrograms.gallery : ReviewStreamingPrograms.lifecycle }
    let state = OpenUIState(schema: library.library.toSchema())
    if mode != "original" { state.setSource(source) }
    _state = StateObject(wrappedValue: state)
    _offset = State(initialValue: mode == "original" ? 0 : source.count)
  }
  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Button("下一段", action: advance).disabled(offset >= source.count)
          .accessibilityIdentifier("stream.next")
        Button("完成接收") { state.complete() }.disabled(offset < source.count)
          .accessibilityIdentifier("stream.complete")
        Button("追加数据", action: append).disabled(!state.isComplete)
          .accessibilityIdentifier("stream.append")
        Button("重开程序", action: replace).accessibilityIdentifier("stream.replace")
      }.font(.caption).buttonStyle(.bordered).padding(8)
      ScrollView {
        VStack(alignment: .leading, spacing: 12) {
          OpenUIRenderer(state: state, registry: library.registry)
            .openUIResourceContext(OpenUIResourceContext(baseURL: URL(string: "https://sdk-fixture.invalid/")))
            .frame(maxWidth: 240, alignment: .leading).padding(12)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20))
          ReviewEvidenceFooter(state: state, evidence: evidence)
          Text("\(offset) / \(source.count)").accessibilityIdentifier("stream.offset")
          Text(state.isComplete ? "complete" : "partial").accessibilityIdentifier("stream.phase")
          if !state.errors.isEmpty {
            // Keep the exact core diagnostics visible as evidence. Missing
            // required fields in an unfinished statement are not a verdict on
            // the final program; completion must clear them or fail acceptance.
            Text(state.errors.map(\.message).joined(separator: "\n"))
              .accessibilityIdentifier(state.isComplete ? "review.errors" : "stream.pending-diagnostics")
          }
        }.frame(maxWidth: .infinity, alignment: .leading).padding(16)
      }.accessibilityIdentifier("review.surface")
    }
    .onAppear {
      evidence.beginExecution(source: source, values: state.snapshotState(), revision: state.sourceRevision, inspect: true)
      state.onStateUpdate = { [evidence] in evidence.capture($0) }
      state.onActionEvaluation = { [evidence] in evidence.recordEvaluation($0) }
    }
  }
  private func advance() {
    let characters = Array(source)
    let end = min(characters.count, offset + 80)
    guard end > offset else { return }
    state.push(String(characters[offset..<end])); offset = end
  }
  private func append() {
    stage += 1
    if mode == "gallery" { state.applyPatch(ReviewStreamingPrograms.galleryAppend) }
    else if mode == "state" { state.applyPatch(ReviewStreamingPrograms.patch(stage: stage)) }
  }
  private func replace() {
    state.reset(); state.setSource(source); offset = source.count; stage = 0
    evidence.reset()
    evidence.beginExecution(source: source, values: state.snapshotState(), revision: state.sourceRevision, inspect: true)
  }
}
