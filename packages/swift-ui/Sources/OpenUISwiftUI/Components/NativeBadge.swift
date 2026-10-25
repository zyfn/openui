import SwiftUI

/// Standard badge presentation, shared by Tag/TagBlock and IconText. These
/// metrics implement component sizes; they do not depend on the host or content.
struct NativeBadgeColors {
  let foreground: Color
  let background: Color

  init(variant: String?, theme: OpenUITheme) {
    switch variant {
    case "inverted":
      foreground = theme.canvas
      background = theme.foreground
    case "info":
      foreground = .blue
      background = Color.blue.opacity(0.12)
    case "success":
      foreground = .green
      background = Color.green.opacity(0.12)
    case "warning":
      foreground = .orange
      background = Color.orange.opacity(0.12)
    case "danger":
      foreground = theme.error
      background = theme.error.opacity(0.12)
    default:
      // Upstream IconText normalizes filled/soft to neutral.
      foreground = theme.foreground
      background = theme.surface
    }
  }
}

struct NativeTagPill<Icon: View>: View {
  let text: String
  let size: String?
  let variant: String?
  let theme: OpenUITheme
  @ViewBuilder var icon: Icon
  @ScaledMetric(relativeTo: .caption) private var scale: CGFloat = 1

  private var minimumHeight: CGFloat { (size == "sm" ? 24 : size == "lg" ? 36 : 32) * scale }
  private var horizontalPadding: CGFloat { (size == "sm" ? 8 : size == "lg" ? 16 : 12) * scale }
  private var colors: NativeBadgeColors { NativeBadgeColors(variant: variant, theme: theme) }

  var body: some View {
    HStack(spacing: (size == "sm" ? 4 : 8) * scale) {
      icon.environment(\.openUIIconSize, 14 * scale)
      Text(text).lineLimit(1).truncationMode(.tail)
    }
    .font(theme.typography.caption.weight(.medium))
    .padding(.horizontal, horizontalPadding).padding(.vertical, 4 * scale)
    .frame(minHeight: minimumHeight)
    .foregroundStyle(colors.foreground)
    .background(colors.background, in: RoundedRectangle(cornerRadius: size == "lg" ? 12 : 8))
    .accessibilityElement(children: .combine)
    .accessibilityLabel(text)
    .accessibilityIdentifier("openui.tag")
  }
}
