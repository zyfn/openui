import Foundation
import OpenUILang
import OpenUISwiftUI

// Core integrity is independent from native rendering and screenshot acceptance.
enum ReviewEngineAudit {
  @MainActor static func run(library: OpenUIComponentLibrary, language: ReviewLanguage = .chinese) -> String {
    let spec = library.toSpec()
    let cases = ReviewCatalog.programs
    let schema = library.library.toSchema()
    let coverage = ReviewCoverage(spec: spec, programs: cases)
    let represented = coverage.represented
    let programIDs = cases.map(\.id)
    var failures: [String: [String]] = [:]
    var localizationFailures: [String: String] = [:]
    let englishSources = ReviewLanguage.englishSources
    let expectedIDs = Set(programIDs)
    if Set(englishSources.keys) != expectedIDs {
      localizationFailures["catalog"] = "English fixture IDs must match the bounded catalog exactly"
    }
    var localized: [ReviewProgram] = []
    for item in cases {
      guard let source = englishSources[item.id] else { continue }
      let originalTokens = tokenize(item.source)
      let englishTokens = tokenize(source)
      let equivalent = originalTokens.count == englishTokens.count
        && zip(originalTokens, englishTokens).allSatisfy { original, translated in
          if case .str(let text) = original, containsChinese(text.displayString) {
            guard case .str(let english) = translated else { return false }
            return !containsChinese(english.displayString)
          }
          return original == translated
        }
      if !equivalent {
        localizationFailures[item.id] = "Translation changed syntax, identifiers, or nonlocalized arguments"
      }
      localized.append(.init(id: "en/" + item.id, title: item.title, source: source))
    }
    for item in cases + localized {
      let batch = createParser(schema: schema).parse(item.source)
      let stream = createStreamingParser(schema: schema)
      let characters = Array(item.source)
      let cuts = Array(Set([1, min(37, characters.count), characters.count / 2, characters.count])).sorted()
      var offset = 0
      for cut in cuts where cut > offset {
        _ = stream.push(String(characters[offset..<cut]), complete: false)
        offset = cut
      }
      let final = stream.getResult(complete: true)
      var errors = batch.meta.errors.map(\.message) + final.meta.errors.map(\.message)
      if batch.meta.incomplete || final.meta.incomplete { errors.append("Incomplete program") }
      if !batch.meta.unresolved.isEmpty || !final.meta.unresolved.isEmpty { errors.append("Unresolved references") }
      if !batch.meta.orphaned.isEmpty || !final.meta.orphaned.isEmpty { errors.append("Orphaned statements") }
      if let a = batch.root, let b = final.root {
        let full = jsonToOpenUI(a, params: schema.components, calls: schema.callDefs,
          options: SerializeOptions(stateDeclarations: batch.stateDeclarations))
        let incremental = jsonToOpenUI(b, params: schema.components, calls: schema.callDefs,
          options: SerializeOptions(stateDeclarations: final.stateDeclarations))
        if full != incremental { errors.append("Batch and streaming trees differ") }
      } else { errors.append("Missing root") }
      if !errors.isEmpty { failures[item.id] = errors }
    }
    let report: [String: Any] = [
      "registered": spec.components.count,
      "represented": represented,
      "missing": spec.components.map(\.name).filter { !represented.contains($0) }.sorted(),
      "variants": cases.count,
      "duplicateProgramIDs": Set(programIDs.filter { id in programIDs.filter { $0 == id }.count > 1 }).sorted(),
      "failures": failures,
      "localizedVariants": localized.count,
      "localizationFailures": localizationFailures,
      "scenarios": ReviewCatalog.scenarios.map { scenario in [
        "id": scenario.id, "title": language.text(scenario.title), "variants": scenario.variants.map(\.id),
        "components": spec.components.map(\.name).filter { name in scenario.variants.contains { coverage.namesByProgram[$0.id]?.contains(name) == true } },
      ] as [String: Any] },
      "scope": "Fixture and engine coverage; native geometry, interaction and image review are separate checks.",
    ]
    let data = try! JSONSerialization.data(withJSONObject: report, options: [.sortedKeys])
    return String(data: data, encoding: .utf8)!
  }

  private static func containsChinese(_ text: String) -> Bool {
    text.unicodeScalars.contains { (0x3400...0x9FFF).contains(Int($0.value)) }
  }
}
