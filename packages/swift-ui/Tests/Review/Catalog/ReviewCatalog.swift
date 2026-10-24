import Foundation
import OpenUILang

struct ReviewProgram: Identifiable, Codable {
  let id: String
  let title: String
  let source: String
}

struct ReviewScenario: Identifiable {
  let id: String
  let title: String
  let purpose: String
  let variants: [ReviewProgram]
}

enum ReviewPrograms {}

/// One owning tree: programs belong to scenarios, with no parallel ID registry.
enum ReviewCatalog {
  static let scenarios: [ReviewScenario] = [
    .init(id: "layout", title: "自适应布局", purpose: "方向、换行与内容变化", variants: ReviewPrograms.layout),
    .init(id: "reading", title: "阅读与媒体", purpose: "摘要、详情、图库与资源状态", variants: ReviewPrograms.reading),
    .init(id: "actions", title: "卡片与操作", purpose: "内容层级、操作密度与独立点击", variants: ReviewPrograms.actions),
    .init(id: "forms", title: "输入与反馈", purpose: "选择、校验、提交与编辑草稿", variants: ReviewPrograms.forms),
    .init(id: "structured-data", title: "混合表格", purpose: "单元格组合、行高与横向滚动", variants: ReviewPrograms.structuredData),
    .init(id: "charts", title: "图表与指标", purpose: "趋势、分布与结构化数据", variants: ReviewPrograms.charts),
    .init(id: "structure", title: "内容与导航", purpose: "分组、层级、步骤与分页", variants: ReviewPrograms.structure),
    .init(id: "spatial", title: "空间与选择", purpose: "地图、内部卡片滑动与同步状态", variants: ReviewPrograms.spatial),
  ]
  static var programs: [ReviewProgram] { scenarios.flatMap(\.variants) }
  static func scenario(for programID: String) -> ReviewScenario? {
    scenarios.first { $0.variants.contains { $0.id == programID } }
  }
  static func importedPrograms(in bundle: Bundle = .main) -> [ReviewProgram] {
    guard let url = bundle.url(forResource: "ReviewExamples", withExtension: "json"),
      let data = try? Data(contentsOf: url),
      let programs = try? JSONDecoder().decode([ReviewProgram].self, from: data) else { return [] }
    return programs
  }
}

/// Source references come from the SDK lexer, not a second parser or a
/// hardcoded component inventory. Name coverage is distinct from visual proof.
struct ReviewCoverage {
  let entries: [LibrarySpecEntry]
  let namesByProgram: [String: Set<String>]

  init(spec: LibrarySpec, programs: [ReviewProgram]) {
    entries = spec.components.sorted { $0.name < $1.name }
    namesByProgram = Dictionary(uniqueKeysWithValues: programs.map { program in
      let tokens = tokenize(program.source).filter { $0 != .newline }
      let names = tokens.indices.compactMap { index -> String? in
        guard case .type(let name) = tokens[index], index + 1 < tokens.count,
          tokens[index + 1] == .lParen else { return nil }
        return name
      }
      return (program.id, Set(names))
    })
  }
  var represented: [String] {
    let references = namesByProgram.values.reduce(into: Set<String>()) { $0.formUnion($1) }
    return entries.map(\.name).filter { references.contains($0) }
  }
  var missing: [String] { entries.map(\.name).filter { !represented.contains($0) } }
  func examples(for name: String, in programs: [ReviewProgram]) -> [ReviewProgram] {
    programs.filter { namesByProgram[$0.id]?.contains(name) == true }
  }
}
