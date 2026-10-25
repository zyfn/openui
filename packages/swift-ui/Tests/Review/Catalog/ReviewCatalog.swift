import Foundation
import OpenUILang
import OpenUISwiftUI

struct ReviewProgram: Identifiable, Codable {
  let id: String
  let title: String
  let source: String
  var sources: [CardSource]? = nil
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
    .init(id: "explore", title: "探索一座城市", purpose: "图文、地点与地图", variants: [ReviewScenePrograms.program("scene-explore")!]),
    .init(id: "itinerary", title: "安排一天行程", purpose: "概览、步骤与路线", variants: [ReviewScenePrograms.program("scene-itinerary")!]),
    .init(id: "compare", title: "比较几个方案", purpose: "表格、图表与选择", variants: [ReviewScenePrograms.program("scene-compare")!]),
    .init(id: "preferences", title: "设置偏好与条件", purpose: "输入、筛选与反馈", variants: [ReviewScenePrograms.program("scene-preferences")!]),
    .init(id: "reading", title: "阅读一份资料", purpose: "图文、图库与来源", variants: [ReviewScenePrograms.program("scene-reading")!]),
    .init(id: "budget", title: "查看预算与数据", purpose: "指标、构成与明细", variants: [ReviewScenePrograms.program("scene-budget")!]),
  ]
  // Existing fixtures remain addressable for focused regression runs and the
  // component browser. They are not additional choices in the scene directory.
  static let regressionPrograms = ReviewPrograms.layout + ReviewPrograms.reading
    + ReviewPrograms.actions + ReviewPrograms.forms + ReviewPrograms.structuredData
    + ReviewPrograms.charts + ReviewPrograms.structure + ReviewPrograms.spatial
  static var programs: [ReviewProgram] { scenarios.flatMap(\.variants) + regressionPrograms }
  static func isBuiltIn(_ id: String) -> Bool { programs.contains { $0.id == id } }
  static func isRegression(_ id: String) -> Bool { regressionPrograms.contains { $0.id == id } }
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
