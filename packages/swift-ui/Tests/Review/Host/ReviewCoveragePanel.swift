import OpenUISwiftUI
import SwiftUI

struct ReviewCoveragePanel: View {
  @Environment(\.reviewLanguage) private var language
  let library: OpenUIComponentLibrary
  private let coverage: ReviewCoverage
  @State private var result: String?
  init(library: OpenUIComponentLibrary) {
    self.library = library
    self.coverage = ReviewCoverage(spec: library.toSpec(), programs: ReviewCatalog.programs)
  }
  private var failures: [String: Any]? {
    guard let result, let report = try? JSONSerialization.jsonObject(with: Data(result.utf8)) as? [String: Any]
    else { return nil }
    return report["failures"] as? [String: Any]
  }

  var body: some View {
    List {
      Section(language.text("固定的验收范围")) {
        Text(language.format("%ld 类组合 · %ld 个受控变体", ReviewCatalog.scenarios.count, ReviewCatalog.programs.count))
        Text(language.format("%ld / %ld 个注册名在程序中被引用", coverage.represented.count, coverage.entries.count))
          .accessibilityIdentifier("review.coverage.summary")
        Text(language.text("注册名包含数据辅助类型；引用覆盖不代表每个状态都已完成视觉验收。"))
          .font(.footnote).foregroundStyle(.secondary)
      }
      Section(language.text("核心引擎")) {
        Button(language.text("检查完整程序与流式结果"), action: run)
        if let failures {
          Text(failures.isEmpty
            ? language.format("%ld 个程序的完整与流式结果一致", ReviewCatalog.programs.count)
            : language.format("%ld 个程序需要检查", failures.count))
          ForEach(failures.keys.sorted(), id: \.self) { key in Text(key).foregroundStyle(.red) }
        }
      }
      Section(language.text("原生验收")) {
        Text(language.text("布局、点击、表单、资源状态和像素结果由 Swift XCUITest 运行并导出。这里不把核心检查冒充原生验收通过。"))
          .font(.subheadline).foregroundStyle(.secondary)
      }
      if let result {
        Section {
          DisclosureGroup(language.text("原始覆盖报告")) { Text(result).font(.caption.monospaced()).textSelection(.enabled) }
        }
      }
    }
  }
  private func run() { result = ReviewEngineAudit.run(library: library, language: language) }
}

struct ReviewEngineAuditView: View {
  @Environment(\.reviewLanguage) private var language
  let library: OpenUIComponentLibrary
  @State private var result = ""
  var body: some View {
    ScrollView { Text(result).font(.caption.monospaced()).padding().accessibilityIdentifier("review.matrix-audit") }
      .onAppear { if result.isEmpty { result = ReviewEngineAudit.run(library: library, language: language) } }
  }
}
