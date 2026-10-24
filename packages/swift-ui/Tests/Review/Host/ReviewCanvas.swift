import OpenUILang
import OpenUISwiftUI
import SwiftUI
import UIKit

struct ReviewCanvas: View {
  let library: OpenUIComponentLibrary
  @ObservedObject var state: OpenUIState
  @ObservedObject var evidence: ReviewEvidence
  let programID: String
  let display: ReviewDisplayOptions
  let inspector: Bool

  // Preview-only host surface, matching ChatResultTheme.assistant and the
  // client's bubble insets. It remains independent of the SDK visual theme.
  private static let clientBubbleColor = Color(uiColor: UIColor { traits in
    traits.userInterfaceStyle == .dark ? .secondarySystemBackground
      : UIColor(red: 232 / 255, green: 235 / 255, blue: 236 / 255, alpha: 1)
  })

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        VStack(alignment: .leading, spacing: 0) {
          ReviewRenderedProgram(library: library, state: state, programID: programID)
            .openUITableCellPolicy(.readOnly)
            .openUITheme(display.theme.sdkTheme)
            .openUIResourceContext(OpenUIResourceContext(baseURL: URL(string: "https://sdk-fixture.invalid/")))
        }
        .padding(.horizontal, display.clientBubble ? 16 : 0)
        .padding(.vertical, display.clientBubble ? 12 : 0)
        .frame(maxWidth: display.width.maximum, alignment: .leading)
        .background(display.clientBubble ? Self.clientBubbleColor : .clear,
          in: RoundedRectangle(cornerRadius: 24))
        .dynamicTypeSize(display.largeText ? .accessibility2 : .large)
        .accessibilityElement(children: .contain).accessibilityIdentifier("review.canvas")
        .frame(maxWidth: .infinity)
        if !state.errors.isEmpty {
          Text(state.errors.map(\.message).joined(separator: "\n"))
            .foregroundStyle(.red).accessibilityIdentifier("review.errors")
        }
        if inspector { ReviewEvidenceFooter(state: state, evidence: evidence) }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 20).padding(.vertical, 24)
    }
    .background(display.theme.sdkTheme.canvas)
    .accessibilityIdentifier("review.surface")
    // Only changing the DSL program replaces the renderer. Theme, appearance,
    // width and the preview bubble update values on the existing subtree.
    .id(programID)
  }
}

private struct ReviewRenderedProgram: View {
  let library: OpenUIComponentLibrary
  @ObservedObject var state: OpenUIState
  let programID: String

  var body: some View {
    if let root = state.root, ["review-table", "review-table-card"].contains(programID),
      let element = ReviewProjection.find(.element(root), matching: { node in
        programID == "review-table" ? node.typeName == "Table"
          : node.typeName == "Card" && ReviewProjection.find(.element(node), matching: { $0.typeName == "Table" }) != nil
      }) {
      if programID == "review-table-card" {
        RenderNode(element: element, registry: library.registry).environmentObject(state).font(.body)
          .accessibilityElement(children: .contain).accessibilityIdentifier("review.tableCard")
      } else {
        RenderNode(element: element, registry: library.registry).environmentObject(state).font(.body)
      }
    } else { OpenUIRenderer(state: state, registry: library.registry) }
  }
}

/// Saved-source diagnostics project evaluated nodes without rewriting data.
enum ReviewProjection {
  static func lastRowLabels(_ root: EvaluatedElement?) -> String {
    guard let root, let table = find(.element(root), matching: { $0.typeName == "Table" }) else { return "[]" }
    let labels = PropValue.children(table, "columns").compactMap { column -> String? in
      guard case .array(let values) = PropValue.value(column, "data"), let last = values.last else { return nil }
      switch last {
      case .string(let value): return value.displayString
      case .number(let value): return jsNumberString(value)
      default: return nil
      }
    }
    return String(data: (try? JSONSerialization.data(withJSONObject: labels)) ?? Data(), encoding: .utf8) ?? "[]"
  }
  static func find(_ value: Value, matching predicate: (EvaluatedElement) -> Bool) -> EvaluatedElement? {
    switch value {
    case .element(let node):
      if predicate(node) { return node }
      for (_, value) in node.props { if let match = find(value, matching: predicate) { return match } }
    case .array(let values):
      for value in values { if let match = find(value, matching: predicate) { return match } }
    case .object(let fields):
      for field in fields { if let match = find(field.value, matching: predicate) { return match } }
    default: break
    }
    return nil
  }
}
