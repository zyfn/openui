import OpenUILang
import OpenUISwiftUI
import SwiftUI

private actor ReviewQueryProvider: ToolProvider {
  private var reply: Value?
  private var pending: [CheckedContinuation<Value, Error>] = []
  func callTool(name: OpenUIString, arguments: OpenUIObject) async throws -> Value {
    if let reply { return reply }
    return try await withCheckedThrowingContinuation { pending.append($0) }
  }
  func resolve(_ value: Value) {
    reply = value
    let calls = pending; pending = []
    calls.forEach { $0.resume(returning: value) }
  }
  func reset() {
    reply = nil
    let calls = pending; pending = []
    calls.forEach { $0.resume(throwing: CancellationError()) }
  }
}

@MainActor struct ReviewQueryWorkspace: View {
  let library: OpenUIComponentLibrary
  private let provider: ReviewQueryProvider
  @StateObject private var state: OpenUIState
  private static let source = """
    data=Query("fixture",{}, {labels:[],values:[]})
    root=Stack([
      TextContent("Query-backed content","large-heavy"),
      Table([Col("Name",data.labels),Col("Value",data.values)]),
      PieChart(data.labels,data.values,"donut"),
      BarChart(data.labels,[Series("Value",data.values)]),
      TextContent("After the data")
    ],"column","m")
    """
  init(library: OpenUIComponentLibrary) {
    self.library = library
    let provider = ReviewQueryProvider()
    self.provider = provider
    let state = OpenUIState(schema: library.library.toSchema(), toolProvider: provider)
    state.setSource(Self.source)
    _state = StateObject(wrappedValue: state)
  }
  var body: some View {
    VStack(spacing: 12) {
      HStack {
        Button("Resolve data") { resolve(labels: ["Alpha", "Beta"], values: [10, 20]) }
          .accessibilityIdentifier("query.resolve")
        Button("Resolve empty") { resolve(labels: [], values: []) }
          .accessibilityIdentifier("query.empty")
        Button("Refresh") {
          Task { await provider.reset(); state.runQuery(statementId: "data", tool: "fixture", args: .object([])) }
        }.accessibilityIdentifier("query.refresh")
      }.font(.caption).buttonStyle(.bordered)
      Text(state.isQueryLoading ? "loading" : "ready").accessibilityIdentifier("query.phase")
      ScrollView {
        OpenUIRenderer(state: state, registry: library.registry).padding(20)
        if !state.errors.isEmpty { Text(state.errors.map(\.message).joined(separator: "\n")).accessibilityIdentifier("review.errors") }
      }.accessibilityIdentifier("review.surface")
    }.padding(.top, 12)
  }
  private func resolve(labels: [String], values: [Double]) {
    let value = Value.object([.init(key: "labels", value: .array(labels.map(Value.string))),
      .init(key: "values", value: .array(values.map(Value.number)))])
    Task { await provider.resolve(value) }
  }
}
