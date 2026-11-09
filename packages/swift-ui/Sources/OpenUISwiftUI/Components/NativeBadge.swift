import SwiftUI

private struct NativeArtworkTagKey: EnvironmentKey { static let defaultValue = false }
extension EnvironmentValues {
  var openUIArtworkTag: Bool {
    get { self[NativeArtworkTagKey.self] }
    set { self[NativeArtworkTagKey.self] = newValue }
  }
}

/// Standard badge presentation, shared by Tag/TagBlock and IconText. These
/// metrics implement component sizes; they do not depend on the host or content.
struct NativeBadgeColors {
  let foreground: Color
  let background: Color

  init(variant: String?, theme: OpenUIThemeValues) {
    switch variant {
    case "inverted":
      foreground = theme.textAccentPrimary ?? NativeControlPalette.adaptive(light: 0xFFFFFF, dark: 0x0B0B0D)
      background = theme.invertedBackground
    case "info":
      foreground = theme.textInfoPrimary
      background = theme.infoBackground
    case "success":
      foreground = theme.textSuccessPrimary
      background = theme.successBackground
    case "warning":
      foreground = theme.textAlertPrimary
      background = theme.alertBackground
    case "danger":
      foreground = theme.textDangerPrimary
      background = theme.dangerBackground
    default:
      // Upstream IconText normalizes filled/soft to neutral.
      foreground = theme.textNeutralPrimary
      background = theme.sunk
    }
  }
}

struct NativeTagPill<Icon: View>: View {
  let text: String
  let size: String?
  let variant: String?
  let theme: OpenUIThemeValues
  @ViewBuilder var icon: Icon
  @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1
  @Environment(\.openUIArtworkTag) private var onArtwork
  @Environment(\.openUIPresentation) private var presentation

  private var font: OpenUIFont {
    size == "sm" ? theme.textBodyXs : size == "lg" ? theme.textBodyDefault : theme.textLabelSm
  }
  private var horizontalInset: CGFloat { theme.spacing(size == "sm" ? "xs" : size == "lg" ? "m" : "s") }
  private var verticalInset: CGFloat {
    onArtwork ? theme.space2xs : size == "sm" ? theme.space3xs : theme.space2xs
  }
  private var colors: NativeBadgeColors { NativeBadgeColors(variant: variant, theme: theme) }
  private var shape: NativeButtonShape {
    .init(radius: nil, maximumRadius: min(max(0, theme.radiusFull) * scale,
      NativeButtonShape.readableRadius(horizontal: horizontalInset * scale, vertical: verticalInset * scale)))
  }

  var body: some View {
    HStack(spacing: theme.spacing(size == "sm" ? "2xs" : "xs") * scale) {
      icon.environment(\.openUIIconSize, font.size)
      Text(text).fixedSize(horizontal: false, vertical: true)
    }
    .openUIFont(font, role: .control)
    .padding(.horizontal, horizontalInset * scale)
    .padding(.vertical, verticalInset * scale)
    .foregroundStyle(colors.foreground)
    // A photograph cannot provide the contrast contract of a normal surface.
    .background(onArtwork ? theme.foreground : colors.background, in: shape)
    .overlay(shape.strokeBorder(onArtwork ? theme.borderDefault : .clear, lineWidth: presentation.borderWidth))
    .accessibilityElement(children: .combine)
    .accessibilityLabel(text)
    .accessibilityIdentifier("openui.tag")
  }
}
