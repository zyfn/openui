import OpenUILang
import OpenUISwiftUI
import SwiftUI
import Combine

@MainActor
struct ReviewWorkspace: View {
  @Environment(\.openURL) private var openURL
  @Environment(\.horizontalSizeClass) private var sizeClass
  private let library: OpenUIComponentLibrary
  private let programs: [ReviewProgram]
  private let configuration: ReviewConfiguration
  // The canvas observes render updates. The surrounding navigation needs only
  // completion changes, so a token update does not rebuild an open tools menu.
  @State private var state: OpenUIState
  @State private var isComplete = false
  @StateObject private var evidence = ReviewEvidence()
  @State private var selected: String
  @State private var display: ReviewDisplayOptions
  @State private var panel: ReviewPanel?
  @State private var drafts: [String: String] = [:]
  @State private var manualSource: String?
  @State private var manualRun = 0
  @State private var purchasePreview: ReviewPurchasePreview?
  @State private var playbackGeneration = 0
  @State private var playbackRate = ReviewPlaybackRate.normal
  @State private var playbackControl = ReviewPlaybackRateControl()
  @State private var playbackError: String?

  private var sample: ReviewProgram? { programs.first { $0.id == selected } }
  private var program: ReviewProgram? {
    if let manualSource {
      return ReviewProgram(id: "manual-\(manualRun)", title: "手动 Lang", source: manualSource, sources: sample?.sources)
    }
    return sample.map { display.language.program($0) }
  }
  private var scenario: ReviewScenario? {
    manualSource == nil ? ReviewCatalog.scenario(for: selected) : nil
  }
  private var position: Int? { ReviewCatalog.scenarios.firstIndex { $0.id == scenario?.id } }
  private var draft: Binding<String> {
    Binding(get: { drafts[selected] ?? program?.source ?? "" }, set: { drafts[selected] = $0 })
  }

  init(library: OpenUIComponentLibrary, configuration: ReviewConfiguration) {
    self.library = library
    self.configuration = configuration
    let programs = ReviewCatalog.programs
    self.programs = programs
    let requestedID = configuration.programID.flatMap { $0.isEmpty ? nil : $0 } ?? "scene-day-trip"
    guard let selected = programs.first(where: { $0.id == requestedID }) else {
      preconditionFailure("Unknown review program: \(requestedID). Prepare optional replay resources before selecting them.")
    }
    let state = OpenUIState(schema: library.library.toSchema())
    _state = State(initialValue: state)
    _isComplete = State(initialValue: state.isComplete)
    _selected = State(initialValue: selected.id)
    _display = State(initialValue: configuration.display)
    _playbackRate = State(initialValue: configuration.playbackRate)
    _playbackControl = State(initialValue: ReviewPlaybackRateControl(configuration.playbackRate))
  }

  var body: some View {
    HStack(spacing: 0) {
      if sizeClass == .regular {
        ReviewScenarioList(selected: selected, select: select)
          .frame(width: 250)
        Divider()
      }
      VStack(spacing: 0) {
        ReviewHeader(scenario: scenario, program: program, position: position,
          display: display, move: move, toggleTheme: toggleTheme,
          toggleBubble: toggleBubble, toggleLanguage: toggleLanguage, isManual: manualSource != nil,
          isPlaying: manualSource == nil && !isComplete,
          playbackRate: playbackRate, setPlaybackRate: { playbackRate = $0; playbackControl.set($0) },
          replay: replay, restoreSample: restoreSample, open: open)
        Divider()
        ReviewCanvas(library: library, state: state, evidence: evidence,
          programID: program?.id ?? selected, source: program?.source ?? "",
          display: display, inspector: configuration.inspector,
          sources: program?.sources ?? [], request: program?.request,
          exportFull: configuration.exportFull)
        if let playbackError {
          Text(playbackError).font(.footnote).foregroundStyle(.red).padding()
            .accessibilityIdentifier("review.transport-error")
        }
      }
    }
    .background(Color(uiColor: .systemBackground))
    .environment(\.reviewLanguage, display.language)
    .environment(\.locale, display.language.locale)
    .preferredColorScheme(display.dark ? .dark : .light)
    .sheet(item: $panel) { item in
      NavigationView {
        panelContent(item)
          .navigationTitle(display.language.text(item.title)).navigationBarTitleDisplayMode(.inline)
          .toolbar {
            ToolbarItem(placement: .cancellationAction) {
              if item == .source {
                Button(display.language.text("取消")) { panel = nil }.accessibilityIdentifier("review.editor-cancel")
              }
            }
            ToolbarItem(placement: .confirmationAction) {
              if item == .source {
                Button(display.language.text("运行"), action: runDraft)
                  .disabled(ReviewLangInput.program(from: draft.wrappedValue)
                    .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                  .accessibilityIdentifier("review.editor-run")
              } else {
                Button(display.language.text("完成")) { panel = nil }.accessibilityIdentifier("review.panel-done")
              }
            }
          }
      }.navigationViewStyle(.stack)
        .environment(\.reviewLanguage, display.language)
        .environment(\.locale, display.language.locale)
        .accessibilityElement(children: .contain).accessibilityIdentifier("review.panel")
    }
    .onAppear(perform: connectEvidence)
    .onReceive(state.$isComplete.removeDuplicates()) { isComplete = $0 }
    .task(id: playbackGeneration) { await play() }
    .onChange(of: display.language) { _ in reloadLocalizedSample() }
    .alert(item: $purchasePreview) { preview in
      Alert(title: Text(display.language.text("下单预览")),
        message: Text(preview.item + "\n" + preview.price + "\n\n"
          + display.language.text("仅演示购买动作，未创建订单，也不会扣款。")),
        dismissButton: .default(Text(display.language.text("完成"))))
    }
  }

  @ViewBuilder private func panelContent(_ item: ReviewPanel) -> some View {
    switch item {
    case .scenarios: ReviewScenarioList(selected: selected, select: select)
    case .conditions: ReviewConditions(display: $display)
    case .coverage: ReviewCoveragePanel(library: library)
    case .diagnostics: ReviewDiagnostics(state: state, evidence: evidence)
    case .source:
      ReviewSourceEditor(draft: draft, runningSource: program?.source ?? "",
        diagnostics: state.errors.map(\.message), restoreSample: restoreSample)
    }
  }

  private func toggleBubble() { display.clientBubble.toggle() }
  private func toggleTheme() { display.theme = display.theme.next }
  private func toggleLanguage() { display.language = display.language.next }
  private func reloadLocalizedSample() {
    UserDefaults.standard.set(display.language.rawValue, forKey: "review.language")
    guard manualSource == nil, let sample,
      ReviewCatalog.isBuiltIn(sample.id) else { return }
    load(display.language.program(sample))
  }
  private func open(_ item: ReviewPanel) {
    if item == .source, drafts[selected] == nil { drafts[selected] = program?.source ?? "" }
    panel = item
  }
  private func runDraft() {
    let source = ReviewLangInput.program(from: draft.wrappedValue)
    guard !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
    // Explicit Run starts a fresh execution of this source. Opening, editing,
    // cancelling or changing preview conditions never reaches this path.
    evidence.reset()
    purchasePreview = nil
    playbackGeneration += 1
    state.reset()
    state.setSource(source)
    evidence.beginExecution(source: source, values: state.snapshotState(),
      revision: state.sourceRevision, inspect: configuration.inspector)
    manualRun += 1
    manualSource = source
    panel = nil
  }
  private func restoreSample() {
    guard let sample else { return }
    select(sample)
  }
  private func select(_ item: ReviewProgram) {
    if item.id != selected || manualSource != nil {
      load(display.language.program(item))
      manualSource = nil
      selected = item.id
    }
    panel = nil
  }
  private func load(_ item: ReviewProgram) {
    evidence.reset()
    purchasePreview = nil
    state.reset()
    playbackGeneration += 1
    evidence.beginExecution(source: item.source, values: state.snapshotState(),
      revision: state.sourceRevision, inspect: configuration.inspector)
  }
  private func replay() {
    guard let program else { return }
    evidence.reset()
    purchasePreview = nil
    state.reset()
    evidence.beginExecution(source: program.source, values: state.snapshotState(),
      revision: state.sourceRevision, inspect: configuration.inspector)
    if manualSource != nil {
      playbackGeneration += 1
      state.setSource(program.source)
    }
    else { playbackGeneration += 1 }
  }
  private func play() async {
    guard manualSource == nil,
      let source = program?.source else { return }
    let generation = playbackGeneration
    playbackError = nil
    // Let the request occupy the conversation before its answer starts. The
    // raw source then arrives on an independent token-paced network clock.
    try? await Task.sleep(nanoseconds: 700_000_000)
    guard !Task.isCancelled, generation == playbackGeneration, manualSource == nil else { return }
    guard let lengths = ReviewTokenStreams.bundled?.lengths(for: source),
      let transport = try? ReviewPlaybackTransport(source: source, tokenByteLengths: lengths) else {
      playbackError = display.language.text("回放 token 数据缺失，请重新生成测试资源。")
      return
    }
    let control = playbackControl
    let sender = Task.detached(priority: .userInitiated) { await transport.produce(rate: control) }
    defer { sender.cancel() }
    var received = ""
    while !Task.isCancelled, generation == playbackGeneration, manualSource == nil {
      let batch = await transport.take()
      guard !Task.isCancelled, generation == playbackGeneration, manualSource == nil else { return }
      if !batch.text.isEmpty {
        received += batch.text
        state.push(batch.text)
      }
      if batch.complete {
        assert(Data(received.utf8) == Data(source.utf8))
        state.complete()
        return
      }
      try? await Task.sleep(nanoseconds: 20_000_000)
    }
  }
  private func move(_ step: Int) {
    let scenarios = ReviewCatalog.scenarios
    guard let position else { return }
    select(scenarios[(position + step + scenarios.count) % scenarios.count].variants[0])
  }
  private func connectEvidence() {
    evidence.beginExecution(source: program?.source ?? "", values: state.snapshotState(),
      revision: state.sourceRevision, inspect: configuration.inspector)
    state.onStateUpdate = { [evidence] in evidence.capture($0) }
    state.onAction = { event in
      evidence.record(event)
      if event.type.displayString == "open_url",
        case .string(let raw)? = event.params.last(where: { $0.0 == "url" })?.1,
        let url = URL(string: raw.displayString), ["https", "http"].contains(url.scheme ?? "") {
        if configuration.inspector { evidence.openedURL = url.absoluteString }
        else { openURL(url) }
        return
      }
      // The ordinary ToAssistant action terminates at this review host. There
      // is no checkout provider, order API, or purchase behavior in the SDK.
      purchasePreview = ReviewPurchasePreview(event: event)
    }
    state.onActionEvaluation = configuration.inspector ? { [evidence] in evidence.recordEvaluation($0) } : nil
  }
}

private struct ReviewPurchasePreview: Identifiable {
  let item: String
  let price: String
  var id: String { item + price }

  init?(event: ActionEvent) {
    guard event.type == "continue_conversation",
      let context = event.params.first(where: { $0.0 == "context" })?.1,
      case .object(let fields) = context,
      fields.first(where: { $0.key == "reviewPurchase" })?.value == .boolean(true),
      case .string(let item)? = fields.first(where: { $0.key == "item" })?.value,
      case .string(let price)? = fields.first(where: { $0.key == "price" })?.value
    else { return nil }
    self.item = item.displayString
    self.price = price.displayString
  }
}
