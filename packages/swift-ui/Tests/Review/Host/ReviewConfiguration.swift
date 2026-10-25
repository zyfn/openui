import Foundation
import OpenUISwiftUI
import SwiftUI

/// A host-override check, not two SDK visual presets.
enum ReviewVisualTheme: String, CaseIterable {
  case standard = "default"
  case accent

  var title: String { self == .standard ? "SDK 默认" : "宿主强调色" }
  var compactTitle: String { self == .standard ? "默认" : "强调色" }
  var next: Self { self == .standard ? .accent : .standard }
  var sdkTheme: OpenUITheme {
    var theme = OpenUITheme()
    if self == .accent {
      theme.accent = .blue
      theme.dataColors[0] = theme.accent
    }
    return theme
  }
}

enum ReviewWidth: String, CaseIterable {
  case available, standard, narrow
  var title: String {
    switch self { case .available: return "自适应"; case .standard: return "320"; case .narrow: return "240" }
  }
  var maximum: CGFloat {
    switch self { case .available: return .infinity; case .standard: return 320; case .narrow: return 240 }
  }
}

struct ReviewDisplayOptions {
  var language = ReviewLanguage.chinese
  var theme = ReviewVisualTheme.standard
  var width = ReviewWidth.available
  var largeText = false
  var dark = false
  var clientBubble = false
  var summary: String {
    [theme.title, width.title, largeText ? "大字体" : "正常文字", dark ? "深色" : "浅色"]
      .map { language.text($0) }.joined(separator: " · ")
  }
}

struct ReviewConfiguration {
  let programID: String?
  let inspector: Bool
  let audit: Bool
  let streamingCase: String?
  let display: ReviewDisplayOptions

  init(arguments: [String] = ProcessInfo.processInfo.arguments) {
    func value(_ key: String) -> String? {
      guard let index = arguments.firstIndex(of: key), index + 1 < arguments.count else { return nil }
      return arguments[index + 1]
    }
    programID = value("--case")
    inspector = arguments.contains("--inspect")
    audit = arguments.contains("--audit-matrix")
    streamingCase = value("--stream-case")
    display = ReviewDisplayOptions(
      language: ReviewLanguage(rawValue: value("--language")
        ?? UserDefaults.standard.string(forKey: "review.language") ?? "zh-Hans") ?? .chinese,
      theme: ReviewVisualTheme(rawValue: value("--theme") ?? "") ?? .standard,
      width: ReviewWidth(rawValue: value("--width") ?? "") ?? .available,
      largeText: arguments.contains("--large-text"), dark: value("--appearance") == "dark",
      clientBubble: arguments.contains("--bubble"))
  }
}

enum ReviewPanel: String, Identifiable {
  case scenarios, components, conditions, coverage, diagnostics, source
  var id: String { rawValue }
  var title: String {
    switch self {
    case .scenarios: return "场景目录"
    case .components: return "组件目录"
    case .conditions: return "预览条件"
    case .coverage: return "覆盖与核心验收"
    case .diagnostics: return "运行诊断"
    case .source: return "编写 openui-lang"
    }
  }
}
