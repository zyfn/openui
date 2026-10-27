import OpenUILang
import OpenUISwiftUI
import SwiftUI

@MainActor
struct ReviewWorkspace: View {
  @Environment(\.openURL) private var openURL
  @Environment(\.horizontalSizeClass) private var sizeClass
  private let library: OpenUIComponentLibrary
  private let programs: [ReviewProgram]
  private let coverage: ReviewCoverage
  private let configuration: ReviewConfiguration
  @StateObject private var state: OpenUIState
  @StateObject private var evidence = ReviewEvidence()
  @State private var selected: String
  @State private var display: ReviewDisplayOptions
  @State private var panel: ReviewPanel?
  @State private var drafts: [String: String] = [:]
  @State private var manualSource: String?
  @State private var manualRun = 0
  @State private var purchasePreview: ReviewPurchasePreview?
  @State private var playbackGeneration = 0

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
    var programs = ReviewCatalog.programs + ReviewCatalog.importedPrograms()
    if let url = Bundle.main.url(forResource: "ReviewProgram", withExtension: "openui"),
      let source = try? String(contentsOf: url, encoding: .utf8) {
      programs += ["review", "review-table", "review-table-card"].map {
        ReviewProgram(id: $0, title: "原样回放", source: source)
      }
    }
    self.programs = programs
    self.coverage = ReviewCoverage(spec: library.toSpec(), programs: programs)
    let requestedID = configuration.programID.flatMap { $0.isEmpty ? nil : $0 } ?? "scene-day-trip"
    guard let selected = programs.first(where: { $0.id == requestedID }) else {
      preconditionFailure("Unknown review program: \(requestedID). Prepare optional replay resources before selecting them.")
    }
    let state = OpenUIState(schema: library.library.toSchema())
    if configuration.instant {
      state.setSource(configuration.display.language.program(selected).source)
    }
    _state = StateObject(wrappedValue: state)
    _selected = State(initialValue: selected.id)
    _display = State(initialValue: configuration.display)
  }

  var body: some View {
    HStack(spacing: 0) {
      if sizeClass == .regular {
        ReviewScenarioList(programs: programs, selected: selected, select: select)
          .frame(width: 250)
        Divider()
      }
      VStack(spacing: 0) {
        ReviewHeader(scenario: scenario, program: program, position: position,
          display: display, move: move, toggleTheme: toggleTheme,
          toggleBubble: toggleBubble, toggleLanguage: toggleLanguage, isManual: manualSource != nil,
          isPlaying: manualSource == nil && !state.isComplete,
          replay: replay, restoreSample: restoreSample, open: open)
        Divider()
        ReviewCanvas(library: library, state: state, evidence: evidence,
          programID: program?.id ?? selected, source: program?.source ?? "",
          display: display, inspector: configuration.inspector,
          sources: program?.sources ?? [], request: program?.request,
          exportFull: configuration.exportFull)
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
    case .scenarios: ReviewScenarioList(programs: programs, selected: selected, select: select)
    case .components: ReviewComponentBrowser(coverage: coverage, programs: programs, select: select)
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
    if configuration.instant {
      playbackGeneration += 1
      state.setSource(item.source)
    } else {
      playbackGeneration += 1
    }
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
    if configuration.instant || manualSource != nil {
      playbackGeneration += 1
      state.setSource(program.source)
    }
    else { playbackGeneration += 1 }
  }
  private func play() async {
    guard !configuration.instant, manualSource == nil,
      let source = program?.source else { return }
    let generation = playbackGeneration
    // Let the request occupy the conversation before its answer starts. The
    // first source characters are then delivered in small real SDK pushes;
    // later complete records arrive faster, including large JSON tool data.
    try? await Task.sleep(nanoseconds: 700_000_000)
    let chunks = ReviewPlaybackTransport.chunks(source)
    assert(chunks.map(\.text).joined() == source)
    for chunk in chunks {
      guard !Task.isCancelled, generation == playbackGeneration, manualSource == nil else { return }
      state.push(chunk.text)
      try? await Task.sleep(nanoseconds: chunk.delay)
    }
    guard !Task.isCancelled, generation == playbackGeneration, manualSource == nil else { return }
    state.complete()
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

/// Review-only transport timing. Every delivered byte is appended to the one
/// original program through OpenUIState.push; no synthetic UI text is shown.
enum ReviewPlaybackTransport {
  struct Chunk {
    let text: String
    let delay: UInt64
  }

  static func chunks(_ source: String) -> [Chunk] {
    let lines = source.components(separatedBy: "\n")
    // Long programs still reveal their heading character by character, but
    // use fewer later parser evaluations so replay stays responsive.
    let bodyWidth = source.count > 8_000 ? 320 : 160
    let bodyDelay: UInt64 = source.count > 8_000 ? 95_000_000 : 130_000_000
    var output: [Chunk] = []
    var prefixCount = 0
    for (index, line) in lines.enumerated() {
      let piece = line + (index < lines.count - 1 ? "\n" : "")
      let expression = line.split(separator: "=", maxSplits: 1).last?
        .trimmingCharacters(in: .whitespaces)
      if piece.count < 240 && expression?.hasPrefix("\"") == true {
        // Scalar text assignments can fill an already-mounted styled slot.
        // Their real partial values are the clearest view of SDK streaming.
        let characters = Array(piece)
        for slice in stride(from: 0, to: characters.count, by: 2) {
          output.append(Chunk(text: String(characters[slice..<min(slice + 2, characters.count)]),
            delay: 110_000_000))
        }
        prefixCount += piece.count
      } else if prefixCount < 320 && piece.count < 1_000 {
        let characters = Array(piece)
        for slice in stride(from: 0, to: characters.count, by: 8) {
          output.append(Chunk(text: String(characters[slice..<min(slice + 8, characters.count)]),
            delay: 115_000_000))
        }
        prefixCount += piece.count
      } else {
        prefixCount = 320
        if piece.count > 1_000 && (expression?.hasPrefix("{") == true || expression?.hasPrefix("[") == true) {
          // Preserve a large data record as one transport packet. Components
          // and prose still grow through the same SDK parser below.
          output.append(Chunk(text: piece, delay: bodyDelay))
        } else {
          let characters = Array(piece)
          for slice in stride(from: 0, to: characters.count, by: bodyWidth) {
            output.append(Chunk(text: String(characters[slice..<min(slice + bodyWidth, characters.count)]),
              delay: bodyDelay))
          }
        }
      }
    }
    return output
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
