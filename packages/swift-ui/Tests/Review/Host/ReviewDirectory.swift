import OpenUILang
import SwiftUI

struct ReviewScenarioList: View {
  @Environment(\.reviewLanguage) private var language
  let programs: [ReviewProgram]
  let selected: String
  let select: (ReviewProgram) -> Void

  var body: some View {
    List {
      Section(language.text("组合场景")) {
        ForEach(ReviewCatalog.scenarios) { scenario in
          Button { select(scenario.variants[0]) } label: {
            HStack(spacing: 10) {
              VStack(alignment: .leading, spacing: 4) {
                Text(language.text(scenario.title)).font(.body.weight(.medium))
                Text(language.text(scenario.purpose)).font(.caption).foregroundStyle(.secondary)
              }
              Spacer(minLength: 0)
              if scenario.variants.contains(where: { $0.id == selected }) {
                Image(systemName: "checkmark").font(.subheadline.weight(.semibold))
              }
            }.padding(.vertical, 5).contentShape(Rectangle())
          }.buttonStyle(.plain).accessibilityIdentifier("review.scenario.\(scenario.id)")
        }
      }
      let extra = programs.filter {
        ReviewCatalog.scenario(for: $0.id) == nil && !["review-table", "review-table-card"].contains($0.id)
      }
      if !extra.isEmpty {
        Section(language.text("外部回放")) {
          ForEach(extra) { program in
            Button(language.text(program.title)) { select(program) }.accessibilityIdentifier("review.case.\(program.id)")
          }
        }
      }
    }.listStyle(.plain).accessibilityIdentifier("review.scenario-directory")
  }
}

struct ReviewComponentBrowser: View {
  @Environment(\.reviewLanguage) private var language
  let coverage: ReviewCoverage
  let programs: [ReviewProgram]
  let select: (ReviewProgram) -> Void
  @State private var query = ""
  private var entries: [LibrarySpecEntry] {
    coverage.entries.filter {
      query.isEmpty || $0.name.localizedCaseInsensitiveContains(query)
        || $0.description.localizedCaseInsensitiveContains(query)
    }
  }

  var body: some View {
    List(entries, id: \.name) { entry in
      NavigationLink {
        ReviewComponentInfo(entry: entry, examples: coverage.examples(for: entry.name, in: programs), select: select)
      } label: {
        VStack(alignment: .leading, spacing: 4) {
          Text(entry.name).font(.body.weight(.medium))
          Text(entry.description).font(.caption).foregroundStyle(.secondary).lineLimit(2)
        }.padding(.vertical, 4)
      }.accessibilityIdentifier("review.component.\(entry.name)")
    }
    .searchable(text: $query, prompt: language.text("查找组件"))
    .accessibilityIdentifier("review.component-directory")
  }
}

private struct ReviewComponentInfo: View {
  @Environment(\.reviewLanguage) private var language
  let entry: LibrarySpecEntry
  let examples: [ReviewProgram]
  let select: (ReviewProgram) -> Void

  var body: some View {
    List {
      Section(language.text("SDK 定义")) {
        Text(entry.description)
        Text(entry.signature).font(.caption.monospaced()).textSelection(.enabled)
      }
      Section(language.text("组合中的使用")) {
        ForEach(examples) { program in
          Button(language.text(program.title)) { select(program) }.accessibilityIdentifier("review.example.\(program.id)")
        }
        if examples.isEmpty { Text(language.text("尚无包含此注册名的组合程序。数据辅助组件应在父组件中验收。")).foregroundStyle(.secondary) }
      }
    }.navigationTitle(entry.name).navigationBarTitleDisplayMode(.inline)
  }
}
