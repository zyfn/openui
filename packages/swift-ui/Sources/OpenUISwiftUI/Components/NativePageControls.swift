import SwiftUI

struct NativePageControls: View {
  let page: Int
  let count: Int
  let enabled: Bool
  let identifier: String
  let select: (Int) -> Void
  var body: some View {
    HStack(spacing: 8) {
      Spacer(minLength: 0)
      Button { select(page - 1) } label: {
        Image(systemName: "chevron.left").font(.subheadline).frame(minWidth: 44, minHeight: 44)
      }
      .accessibilityLabel(Text("Previous page", bundle: NativeControlResources.bundle))
      .accessibilityIdentifier(identifier + ".previous")
      .disabled(!enabled || page <= 0)
      Text("\(page + 1) / \(count)").font(.caption).monospacedDigit()
        .accessibilityIdentifier(identifier + ".page")
      Button { select(page + 1) } label: {
        Image(systemName: "chevron.right").font(.subheadline).frame(minWidth: 44, minHeight: 44)
      }
      .accessibilityLabel(Text("Next page", bundle: NativeControlResources.bundle))
      .accessibilityIdentifier(identifier + ".next")
      .disabled(!enabled || page >= count - 1)
    }.buttonStyle(.plain)
  }
}
