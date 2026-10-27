import OpenUILang
import SwiftUI

struct ReviewScenarioList: View {
  @Environment(\.reviewLanguage) private var language
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
    }.listStyle(.plain).accessibilityIdentifier("review.scenario-directory")
  }
}
