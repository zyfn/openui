import Foundation
import AppKit
import SwiftUI
import OpenUISwiftUI
import OpenUILang
import CryptoKit

@main struct GuideExport {
  @MainActor static func main() throws {
    if CommandLine.arguments[1] == "--validate" {
      let data = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[2]))
      let reference = try JSONSerialization.jsonObject(with: data) as! [String: Any]
      let library = try OpenUIStandardComponents.library()
      let parser = createParser(schema: library.library.toSchema())
      let examples = reference["examples"] as! [[String: Any]]
      var failures = 0
      for example in examples {
        let result = parser.parse(example["source"] as! String)
        if !result.meta.errors.isEmpty || !result.meta.unresolved.isEmpty {
          FileHandle.standardError.write(Data("Invalid example \(example["id"]!): \(result.meta.errors) unresolved=\(result.meta.unresolved)\n".utf8))
          failures += 1
        }
      }
      guard failures == 0 else { throw NSError(domain: "GuideExamples", code: failures) }
      print("Validated \(examples.count) examples against the actual Swift library.")
      return
    }
    let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let theme = OpenUIThemeValues()
    func color(_ color: Color, dark: Bool) -> String {
      var result = ""
      NSAppearance(named: dark ? .darkAqua : .aqua)!.performAsCurrentDrawingAppearance {
        let c = NSColor(color).usingColorSpace(.sRGB)!
        result = String(format: "#%02X%02X%02X", Int((c.redComponent * 255).rounded()), Int((c.greenComponent * 255).rounded()), Int((c.blueComponent * 255).rounded()))
        if c.alphaComponent < 0.999 { result += String(format: "%02X", Int((c.alphaComponent * 255).rounded())) }
      }
      return result
    }
    var colors: [String: Any] = [:], fonts: [String: Any] = [:], metrics: [String: Double] = [:]
    for child in Mirror(reflecting: theme).children {
      guard let key = child.label else { continue }
      if let value = child.value as? Color { colors[key] = ["light": color(value, dark: false), "dark": color(value, dark: true)] }
      if let value = child.value as? OpenUIFont {
        fonts[key] = ["size": value.size, "weight": value.weight == .semibold ? 600 : value.weight == .medium ? 500 : value.weight == .bold ? 700 : 400, "family": value.family ?? "system", "monospacedDigits": value.monospacedDigits, "lineHeight": value.lineHeight as Any? ?? NSNull()]
      }
      if let value = child.value as? CGFloat { metrics[key] = Double(value) }
    }
    let chartPalette = theme.chartColors(forSeriesCount: 8).map { ["light": color($0, dark: false), "dark": color($0, dark: true)] }
    let tokens: [String: Any] = ["colors": colors, "fonts": fonts, "metrics": metrics, "chartPalette": chartPalette, "chartPalettePlatform": "macOS"]
    try JSONSerialization.data(withJSONObject: tokens, options: [.prettyPrinted, .sortedKeys]).write(to: directory.appendingPathComponent("tokens.json"))
    let library = try OpenUIStandardComponents.library()
    try Data(library.toSpec().jsonString().utf8).write(to: directory.appendingPathComponent("library.json"))
    var root = URL(fileURLWithPath: #filePath)
    for _ in 0..<5 { root.deleteLastPathComponent() }
    let sources = root.appendingPathComponent("packages/swift-ui/Sources")
    let files = FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil)!
    var hashes: [String: String] = [:]
    for case let file as URL in files where file.pathExtension == "swift" || file.pathExtension == "strings" || file.lastPathComponent == "upstream-catalog.json" {
      let relative = String(file.path.dropFirst(root.path.count + 1))
      hashes[relative] = SHA256.hash(data: try Data(contentsOf: file)).map { String(format: "%02x", $0) }.joined()
    }
    let input = hashes.keys.sorted().map { $0 + "\0" + hashes[$0]! + "\n" }.joined()
    let fingerprint = SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    try JSONSerialization.data(withJSONObject: ["files": hashes, "fingerprint": fingerprint], options: [.prettyPrinted, .sortedKeys]).write(to: directory.appendingPathComponent("source-manifest.json"))
  }
}
