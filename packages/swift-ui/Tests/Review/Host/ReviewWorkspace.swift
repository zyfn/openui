import OpenUILang
import OpenUISwiftUI
import SwiftUI

@MainActor
struct ReviewWorkspace: View {
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

  private var sample: ReviewProgram? { programs.first { $0.id == selected } }
  private var program: ReviewProgram? {
    if let manualSource {
      return ReviewProgram(id: "manual-\(manualRun)", title: "手动 Lang", source: manualSource)
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
    let requestedID = configuration.programID.flatMap { $0.isEmpty ? nil : $0 } ?? "composition"
    guard let selected = programs.first(where: { $0.id == requestedID }) else {
      preconditionFailure("Unknown review program: \(requestedID). Prepare optional replay resources before selecting them.")
    }
    let state = OpenUIState(schema: library.library.toSchema())
    state.setSource(configuration.display.language.program(selected).source)
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
          display: display, select: select, move: move, toggleTheme: toggleTheme,
          toggleBubble: toggleBubble, toggleLanguage: toggleLanguage, isManual: manualSource != nil,
          restoreSample: restoreSample, open: open)
        Divider()
        ReviewCanvas(library: library, state: state, evidence: evidence,
          programID: program?.id ?? selected, display: display, inspector: configuration.inspector)
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
    .onChange(of: display.language) { _ in reloadLocalizedSample() }
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
      ReviewCatalog.scenario(for: sample.id) != nil else { return }
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
    state.reset()
    state.setSource(item.source)
    evidence.beginExecution(source: item.source, values: state.snapshotState(),
      revision: state.sourceRevision, inspect: configuration.inspector)
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
    state.onAction = { [evidence] in evidence.record($0) }
    state.onActionEvaluation = configuration.inspector ? { [evidence] in evidence.recordEvaluation($0) } : nil
  }
}
