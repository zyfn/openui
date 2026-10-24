import OpenUISwiftUI
import SwiftUI

struct ReviewCoveragePanel: View {
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
      Section("固定的验收范围") {
        Text("\(ReviewCatalog.scenarios.count) 类组合 · \(ReviewCatalog.programs.count) 个受控变体")
        Text("\(coverage.represented.count) / \(coverage.entries.count) 个注册名在程序中被引用")
          .accessibilityIdentifier("review.coverage.summary")
        Text("注册名包含数据辅助类型；引用覆盖不代表每个状态都已完成视觉验收。")
          .font(.footnote).foregroundStyle(.secondary)
      }
      Section("核心引擎") {
        Button("检查完整程序与流式结果", action: run)
        if let failures {
          Text(failures.isEmpty ? "\(ReviewCatalog.programs.count) 个程序的完整与流式结果一致" : "\(failures.count) 个程序需要检查")
          ForEach(failures.keys.sorted(), id: \.self) { key in Text(key).foregroundStyle(.red) }
        }
      }
      Section("原生验收") {
        Text("布局、点击、表单、资源状态和像素结果由 Swift XCUITest 运行并导出。这里不把核心检查冒充原生验收通过。")
          .font(.subheadline).foregroundStyle(.secondary)
      }
      if let result {
        Section {
          DisclosureGroup("原始覆盖报告") { Text(result).font(.caption.monospaced()).textSelection(.enabled) }
        }
      }
    }
  }
  private func run() { result = ReviewEngineAudit.run(library: library) }
}

struct ReviewEngineAuditView: View {
  let library: OpenUIComponentLibrary
  @State private var result = ""
  var body: some View {
    ScrollView { Text(result).font(.caption.monospaced()).padding().accessibilityIdentifier("review.matrix-audit") }
      .onAppear { if result.isEmpty { result = ReviewEngineAudit.run(library: library) } }
  }
}
