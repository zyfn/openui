import SwiftUI
import UIKit

struct ReviewSourceEditor: View {
  @Binding var draft: String
  let runningSource: String
  let diagnostics: [String]
  let restoreSample: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text(ReviewLangInput.program(from: draft) == runningSource ? "与当前程序相同" : "有未运行的修改")
          .font(.footnote).foregroundStyle(.secondary)
          .accessibilityIdentifier("review.editor-status")
        Spacer()
        Button("清空草稿") { draft = "" }
          .font(.footnote).accessibilityIdentifier("review.editor-clear")
      }
      Text("粘贴或编辑 openui-lang。运行会替换预览并重置本地交互；取消保留草稿和当前状态。")
        .font(.footnote).foregroundStyle(.secondary)
      ReviewCodeTextEditor(text: $draft)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 12))
      if !diagnostics.isEmpty {
        VStack(alignment: .leading, spacing: 4) {
          Text("上次运行诊断").font(.footnote.weight(.semibold))
          ScrollView {
            Text(diagnostics.joined(separator: "\n"))
              .font(.footnote.monospaced()).foregroundStyle(.red).textSelection(.enabled)
              .frame(maxWidth: .infinity, alignment: .leading)
              .accessibilityIdentifier("review.editor-diagnostics")
          }.frame(maxHeight: 100)
        }
      }
      HStack {
        Button("恢复目录样例", action: restoreSample)
          .accessibilityIdentifier("review.editor-restore")
        Spacer()
        Text("\(draft.count) 字符").font(.caption).foregroundStyle(.secondary)
      }.font(.footnote).frame(minHeight: 44)
    }
    .padding(16)
  }
}

/// Only remove one complete, outer Markdown wrapper. No statement rewriting,
/// error recovery or partial extraction: all language behavior stays in core.
enum ReviewLangInput {
  static func program(from input: String) -> String {
    let envelope = input.trimmingCharacters(in: .whitespacesAndNewlines)
    let lines = envelope.components(separatedBy: "\n")
    guard lines.count >= 2,
      lines.first?.trimmingCharacters(in: .whitespacesAndNewlines) == "```openui-lang",
      lines.last?.trimmingCharacters(in: .whitespacesAndNewlines) == "```"
    else { return input }
    return lines.dropFirst().dropLast().joined(separator: "\n")
  }
}

/// Scoped native text editing lets us explicitly disable smart punctuation.
/// It doesn't change UITextView appearance or any SDK input's configuration.
private struct ReviewCodeTextEditor: UIViewRepresentable {
  @Binding var text: String

  func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

  func makeUIView(context: Context) -> UITextView {
    let view = UITextView()
    view.delegate = context.coordinator
    view.font = UIFontMetrics(forTextStyle: .body).scaledFont(
      for: .monospacedSystemFont(ofSize: 15, weight: .regular))
    view.adjustsFontForContentSizeCategory = true
    view.textColor = .label
    view.backgroundColor = .secondarySystemBackground
    view.textContainerInset = UIEdgeInsets(top: 14, left: 12, bottom: 14, right: 12)
    view.textContainer.lineFragmentPadding = 0
    view.autocorrectionType = .no
    view.autocapitalizationType = .none
    view.spellCheckingType = .no
    view.smartQuotesType = .no
    view.smartDashesType = .no
    view.smartInsertDeleteType = .no
    view.allowsEditingTextAttributes = false
    view.keyboardDismissMode = .interactive
    view.alwaysBounceVertical = true
    view.accessibilityIdentifier = "review.lang-input"
    view.accessibilityLabel = "openui-lang 程序"
    return view
  }

  func updateUIView(_ view: UITextView, context: Context) {
    context.coordinator.text = $text
    if view.text != text { view.text = text }
  }

  final class Coordinator: NSObject, UITextViewDelegate {
    var text: Binding<String>
    init(text: Binding<String>) { self.text = text }
    func textViewDidChange(_ textView: UITextView) { text.wrappedValue = textView.text ?? "" }
  }
}
