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

  private var density: CGFloat { size == "sm" ? 2 / 3 : size == "lg" ? 4 / 3 : 1 }
  private var font: Font { size == "sm" ? theme.typography.caption : size == "lg" ? theme.typography.body : theme.typography.detail }
  private var colors: NativeBadgeColors { NativeBadgeColors(variant: variant, theme: theme) }

  var body: some View {
    HStack(spacing: theme.contentSpacing / 2 * density * scale) {
      icon.environment(\.openUIIconSize, 14 * scale)
      Text(text).fixedSize(horizontal: false, vertical: true)
    }
    .font(font.weight(.medium))
    .padding(.horizontal, theme.contentSpacing * density * scale)
    .padding(.vertical, theme.contentSpacing / 3 * density * scale)
    .foregroundStyle(colors.foreground)
    .background(colors.background, in: RoundedRectangle(cornerRadius: theme.controlCornerRadius))
    .accessibilityElement(children: .combine)
    .accessibilityLabel(text)
    .accessibilityIdentifier("openui.tag")
  }
}
