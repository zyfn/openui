import SwiftUI

struct NativeTableSkeleton: View {
  let columns: Int
  @Environment(\.openUITheme) private var theme
  var body: some View {
    VStack(spacing: 16) {
      ForEach(0..<5, id: \.self) { _ in
        HStack(spacing: 16) {
          ForEach(0..<max(3, columns), id: \.self) { _ in
            RoundedRectangle(cornerRadius: 4).fill(theme.secondary.opacity(0.12)).frame(height: 16)
          }
        }
      }
    }.padding(.vertical, 12).frame(maxWidth: .infinity)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(Text("Loading data", bundle: NativeControlResources.bundle))
      .accessibilityIdentifier("openui.table.loading")
  }
}

struct NativePieSkeleton: View {
  let donut: Bool
  let semi: Bool
  @Environment(\.openUITheme) private var theme
  var body: some View {
    Circle().trim(from: semi ? 0.5 : 0, to: 1)
      .stroke(theme.secondary.opacity(0.12), lineWidth: donut ? 28 : 70)
      .padding(40).frame(height: semi ? 150 : 250)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(Text("Loading data", bundle: NativeControlResources.bundle))
      .accessibilityIdentifier("openui.chart.loading")
  }
}
