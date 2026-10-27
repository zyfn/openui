import Foundation
import OpenUILang
import OpenUISwiftUI

struct ReviewProgram: Identifiable, Codable {
  let id: String
  let title: String
  let source: String
  var sources: [CardSource]? = nil
  var request: String? = nil
}

struct ReviewScenario: Identifiable {
  let id: String
  let title: String
  let purpose: String
  let variants: [ReviewProgram]
}

/// One owning tree: programs belong to scenarios, with no parallel ID registry.
enum ReviewCatalog {
  static let scenarios: [ReviewScenario] = [
    .init(id: "day-trip", title: "规划一次一日游", purpose: "路线、餐饮、体验与当天预算", variants: [ReviewScenePrograms.program("scene-day-trip")!]),
    .init(id: "two-day-trip", title: "规划一次两日游", purpose: "两天行程、机票、一晚住宿与总预算", variants: [ReviewScenePrograms.program("scene-two-day-trip")!]),
    .init(id: "shopping", title: "选购一台旅行相机", purpose: "需求取舍、商品比较与购买预览", variants: [ReviewScenePrograms.program("scene-shopping")!]),
    .init(id: "spending", title: "分析消费与预算", purpose: "三个月账单、变化原因与下月计划", variants: [ReviewScenePrograms.program("scene-spending")!]),
    .init(id: "gathering", title: "组织一次朋友聚会", purpose: "场地、晚餐、流程与费用分摊", variants: [ReviewScenePrograms.program("scene-gathering")!]),
    .init(id: "learning", title: "图文学习一段历史", purpose: "器物、图像、证据与延伸阅读", variants: [ReviewScenePrograms.program("scene-learning")!]),
  ]
  static var programs: [ReviewProgram] { scenarios.flatMap(\.variants) }
  static func isBuiltIn(_ id: String) -> Bool { programs.contains { $0.id == id } }
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
}
