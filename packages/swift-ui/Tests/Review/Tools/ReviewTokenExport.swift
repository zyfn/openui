import Foundation

/// Export the same compiled sources used by the review host, without parsing or
/// changing them. Tokenization is an offline review-resource preparation step.
@main struct ReviewTokenExport {
  @MainActor static func main() throws {
    let programs = ReviewCatalog.programs
    var sources = programs.map(\.source)
    sources += ReviewCatalog.programs.map { ReviewLanguage.english.program($0).source }
    let data = try JSONEncoder().encode(Array(Set(sources)).sorted())
    try data.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
  }
}
