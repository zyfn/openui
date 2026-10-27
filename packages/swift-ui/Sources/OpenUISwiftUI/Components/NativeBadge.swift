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
      foreground = theme.info
      background = theme.info.opacity(0.12)
    case "success":
      foreground = theme.success
      background = theme.success.opacity(0.12)
    case "warning":
      foreground = theme.warning
      background = theme.warning.opacity(0.12)
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
  @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1

  private var density: CGFloat { size == "sm" ? 2 / 3 : size == "lg" ? 4 / 3 : 1 }
  private var font: OpenUIFont { size == "sm" ? theme.typography.label : size == "lg" ? theme.typography.body : theme.typography.detail }
  private var colors: NativeBadgeColors { NativeBadgeColors(variant: variant, theme: theme) }

  var body: some View {
    HStack(spacing: theme.contentSpacing / 2 * density * scale) {
      icon.environment(\.openUIIconSize, font.size)
      Text(text).fixedSize(horizontal: false, vertical: true)
    }
    .openUIFont(font.weight(theme.typography.label.weight))
    .padding(.horizontal, theme.contentSpacing * density * scale)
    .padding(.vertical, theme.spacing("xs") * (size == "lg" ? 1.5 : 1) * scale)
    .foregroundStyle(colors.foreground)
    .background(colors.background, in: RoundedRectangle(cornerRadius: theme.controlCornerRadius))
    .accessibilityElement(children: .combine)
    .accessibilityLabel(text)
    .accessibilityIdentifier("openui.tag")
  }
}
