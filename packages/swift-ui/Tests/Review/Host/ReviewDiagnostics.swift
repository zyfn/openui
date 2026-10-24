import OpenUILang
import OpenUISwiftUI
import SwiftUI

@MainActor
final class ReviewEvidence: ObservableObject {
  struct StateUpdate: Codable {
    let sequence: Int
    let before: String
    let after: String
  }

  @Published private(set) var events = 0
  @Published private(set) var lastAction = ""
  @Published private(set) var snapshot = ""
  @Published private(set) var stateHistory: [StateUpdate] = []
  @Published private(set) var stateUpdateCount = 0
  @Published private(set) var executedSource = ""
  @Published private(set) var executionRevision = 0
  @Published private(set) var evaluations: [[String: String]] = []
  private var recordsHistory = false
  private var previousSnapshot = ""

  func reset() {
    events = 0; lastAction = ""; snapshot = ""
    stateHistory.removeAll(); stateUpdateCount = 0
    executedSource = ""; executionRevision = 0; previousSnapshot = ""
    evaluations = []
  }
  func beginExecution(source: String, values: [OpenUIString: Value], revision: Int, inspect: Bool) {
    recordsHistory = inspect
    guard inspect, revision != executionRevision else { return }
    executedSource = source
    executionRevision = revision
    previousSnapshot = Self.serialize(values)
  }
  func record(_ event: ActionEvent) { events += 1; lastAction = event.type.displayString }
  func recordEvaluation(_ evaluation: OpenUIActionEvaluation) {
    guard recordsHistory else { return }
    evaluations.append(["revision": "\(evaluation.sourceRevision)", "expression": String(reflecting: evaluation.expression),
      "before": Self.serialize(evaluation.state), "result": (try? evaluation.result.jsonString()) ?? "undefined"])
    if evaluations.count > 32 { evaluations.removeFirst(evaluations.count - 32) }
  }
  var evaluationsJSON: String {
    String(data: (try? JSONSerialization.data(withJSONObject: evaluations, options: [.sortedKeys])) ?? Data(), encoding: .utf8) ?? "[]"
  }
  func capture(_ values: [OpenUIString: Value]) {
    snapshot = Self.serialize(values)
    if recordsHistory {
      stateUpdateCount += 1
      stateHistory.append(StateUpdate(sequence: stateUpdateCount, before: previousSnapshot, after: snapshot))
      if stateHistory.count > 32 { stateHistory.removeFirst(stateHistory.count - 32) }
      previousSnapshot = snapshot
    }
  }
  var historyJSON: String {
    String(data: (try? JSONEncoder().encode(stateHistory)) ?? Data(), encoding: .utf8) ?? "[]"
  }
  static func serialize(_ values: [OpenUIString: Value]) -> String {
    (try? Value.object(values.sorted { $0.key < $1.key }
      .map { ObjectField(key: $0.key, value: $0.value) }).jsonString()) ?? ""
  }
}

/// Read-only evidence from the evaluated SDK tree, not from editor text or a
/// reconstructed action. Deliberately confined to --inspect review output.
private enum ReviewButtonPlans {
  static func describe(_ root: EvaluatedElement?, sourceRevision: Int) -> String {
    var buttons: [[String: Any]] = []
    func walk(_ value: Value, path: String) {
      switch value {
      case .element(let element):
        if element.typeName == "Button" {
          let plan = PropValue.actionPlan(element, "action")
          let steps = (plan?.steps ?? []).map { step -> [String: Any] in
            var fields: [String: Any] = ["description": String(reflecting: step)]
            if case .set(let target, let rhs) = step {
              fields["type"] = "set"; fields["target"] = target
              fields["rhs"] = String(reflecting: rhs)
            }
            return fields
          }
          buttons.append([
            "path": path, "label": PropValue.string(element, "label") ?? "",
            "statementID": element.statementId ?? "", "stepCount": steps.count, "steps": steps,
          ])
        }
        for (key, child) in element.props { walk(child, path: path + "." + key) }
      case .array(let items):
        for (index, child) in items.enumerated() { walk(child, path: "\(path)[\(index)]") }
      case .object(let fields):
        for field in fields { walk(field.value, path: path + "." + field.key.displayString) }
      default: break
      }
    }
    if let root { walk(.element(root), path: "root") }
    let output: [String: Any] = ["sourceRevision": sourceRevision, "buttons": buttons]
    return String(data: (try? JSONSerialization.data(withJSONObject: output, options: [.sortedKeys])) ?? Data(),
      encoding: .utf8) ?? "{}"
  }
}

struct ReviewDiagnostics: View {
  @ObservedObject var state: OpenUIState
  @ObservedObject var evidence: ReviewEvidence

  var body: some View {
    List {
      Section("运行状态") {
        ReviewDiagnosticRow("程序", value: state.isComplete ? "完整" : "流式接收中")
        ReviewDiagnosticRow("错误", value: "\(state.errors.count)")
        ReviewDiagnosticRow("交互事件", value: "\(evidence.events)")
      }
      Section("当前状态") {
        Text(evidence.snapshot.isEmpty ? "尚无交互更新" : evidence.snapshot)
          .font(.footnote.monospaced()).textSelection(.enabled)
      }
      if !state.errors.isEmpty {
        Section("诊断") { ForEach(Array(state.errors.enumerated()), id: \.offset) { _, error in Text(error.message) } }
      }
    }
  }
}

private struct ReviewDiagnosticRow: View {
  let title: String
  let value: String
  init(_ title: String, value: String) { self.title = title; self.value = value }
  var body: some View { HStack { Text(title); Spacer(); Text(value).foregroundStyle(.secondary) } }
}

/// Explicit automation instrumentation. Normal review keeps diagnostics out
/// of the canvas; --inspect adds stable evidence nodes for native assertions.
struct ReviewEvidenceFooter: View {
  @ObservedObject var state: OpenUIState
  @ObservedObject var evidence: ReviewEvidence
  @ObservedObject private var images = ReviewImageMonitor.shared

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Divider()
      Text("Images: \(images.loaded)").accessibilityIdentifier("review.images")
      Text("Events: \(evidence.events)").accessibilityIdentifier("review.events")
      Text(evidence.lastAction).accessibilityIdentifier("review.lastAction")
      Text(ReviewProjection.lastRowLabels(state.root)).accessibilityIdentifier("review.tableLastRow")
      Text(evidence.snapshot).font(.caption.monospaced()).accessibilityIdentifier("review.state")
      debugValue("review.state-current", ReviewEvidence.serialize(state.snapshotState()))
      debugValue("review.state-history", evidence.historyJSON)
      debugValue("review.state-update-count", "\(evidence.stateUpdateCount)")
      debugValue("review.source-revision", "\(evidence.executionRevision)")
      debugValue("review.executed-source", evidence.executedSource)
      debugValue("review.button-plans", ReviewButtonPlans.describe(state.root, sourceRevision: state.sourceRevision))
      debugValue("review.action-evaluations", evidence.evaluationsJSON)
    }
  }

  private func debugValue(_ identifier: String, _ value: String) -> some View {
    Text(value).font(.caption.monospaced()).lineLimit(1)
      .accessibilityLabel(value).accessibilityIdentifier(identifier)
  }
}
