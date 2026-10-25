import Foundation
import SwiftUI

/// Review-host localization only. The SDK and caller-supplied programs do not
/// translate model output. English fixtures are ordinary, separately authored DSL.
enum ReviewLanguage: String, CaseIterable {
  case chinese = "zh-Hans"
  case english = "en"

  var title: String { self == .english ? "English" : "简体中文" }
  var next: Self { self == .english ? .chinese : .english }
  var locale: Locale { Locale(identifier: rawValue) }

  private static let englishBundle: Bundle = {
    guard let root = Bundle.main.resourceURL,
      let bundle = Bundle(url: root.appendingPathComponent("Localization/en.lproj"))
    else { preconditionFailure("Missing review localization resources") }
    return bundle
  }()

  static let englishSources: [String: String] = {
    guard let url = englishBundle.url(forResource: "Programs", withExtension: "json"),
      let data = try? Data(contentsOf: url),
      let sources = try? JSONDecoder().decode([String: String].self, from: data)
    else { preconditionFailure("Missing English review programs") }
    return sources
  }()

  func text(_ key: String) -> String {
    self == .chinese ? key
      : Self.englishBundle.localizedString(forKey: key, value: key, table: "Review")
  }

  func format(_ key: String, _ arguments: CVarArg...) -> String {
    String(format: text(key), locale: locale, arguments: arguments)
  }

  func program(_ original: ReviewProgram) -> ReviewProgram {
    guard self == .english else { return original }
    // Only catalog fixtures opt into translated source. Imported replays and
    // editor drafts retain their exact bytes, even when the host uses English.
    let source: String
    if ReviewCatalog.scenario(for: original.id) != nil {
      guard let english = Self.englishSources[original.id] else {
        preconditionFailure("Missing English review program: \(original.id)")
      }
      source = english
    } else { source = original.source }
    return ReviewProgram(id: original.id, title: text(original.title), source: source)
  }
}

private struct ReviewLanguageKey: EnvironmentKey {
  static let defaultValue = ReviewLanguage.chinese
}

extension EnvironmentValues {
  var reviewLanguage: ReviewLanguage {
    get { self[ReviewLanguageKey.self] }
    set { self[ReviewLanguageKey.self] = newValue }
  }
}
