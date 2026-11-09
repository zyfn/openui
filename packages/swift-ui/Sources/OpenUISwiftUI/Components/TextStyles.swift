import SwiftUI

/// Complete, internal text recipes for slots whose purpose is already explicit.
/// The same resolved font feeds native text, rich text and geometry measurement.
struct NativeTextStyle {
  enum Purpose: Equatable { case body, compactBody, supporting, caption, fieldLabel, action, compactAction, fieldError }

  let font: OpenUIFont
  let color: Color
  let role: NativeTextRole
  let emphasisWeight: Font.Weight

  init(_ purpose: Purpose, theme: OpenUIThemeValues) {
    let font: OpenUIFont
    switch purpose {
    case .body:
      font = theme.textBodyDefault; role = .body
      color = theme.textNeutralPrimary; emphasisWeight = theme.textBodyDefaultHeavy.weight
    case .compactBody:
      font = theme.textBodySm; role = .detail
      color = theme.textNeutralPrimary; emphasisWeight = theme.textBodySmHeavy.weight
    case .supporting, .fieldError:
      font = theme.textBodySm; role = .detail
      color = purpose == .fieldError ? theme.textDangerPrimary : theme.textNeutralSecondary
      emphasisWeight = theme.textBodySmHeavy.weight
    case .caption:
      font = theme.textBodyXs; role = .caption
      color = theme.textNeutralSecondary; emphasisWeight = theme.textBodySmHeavy.weight
    case .fieldLabel:
      font = theme.textLabelDefaultHeavy; role = .label
      color = theme.textNeutralPrimary; emphasisWeight = font.weight
    case .action, .compactAction:
      font = purpose == .compactAction ? theme.textLabelSmHeavy : theme.textLabelDefaultHeavy
      role = .control; color = theme.textNeutralPrimary; emphasisWeight = font.weight
    }
    self.font = font.resolved(for: role)
  }

  func richText(numeric: Bool = false, color override: Color? = nil) -> NativeRichTextStyle {
    .init(font: font, numeric: numeric, color: override ?? color, role: role, emphasisWeight: emphasisWeight)
  }
}

extension OpenUIThemeValues {
  func textStyle(_ purpose: NativeTextStyle.Purpose) -> NativeTextStyle { .init(purpose, theme: self) }
}

extension View {
  func nativeTextStyle(_ style: NativeTextStyle, color: Color? = nil) -> some View {
    openUIFont(style.font, role: style.role).foregroundStyle(color ?? style.color)
  }
}

// Official text-size variants select semantic roles; theme values stay independent.
struct NativeRichTextStyle {
  var font: OpenUIFont?
  var numeric = false
  var color: Color?
  var role: NativeTextRole = .body
  var emphasisWeight: Font.Weight?
  static func textContent(_ size: String?, theme: OpenUIThemeValues) -> Self {
    let font: OpenUIFont?
    switch size {
    case "small": font = theme.textBodySm
    case "small-heavy": font = theme.textBodySmHeavy
    case "large": font = theme.textBodyLg
    case "large-heavy": font = theme.textBodyLgHeavy
    case "default": font = theme.textBodyDefault
    default: font = nil
    }
    // Size variants select a reading scale, not an information-priority color.
    let small = size == "small" || size == "small-heavy"
    let large = size == "large" || size == "large-heavy"
    return .init(font: font, color: theme.textNeutralPrimary, role: small ? .detail : .body,
      emphasisWeight: small ? theme.textBodySmHeavy.weight : large ? theme.textBodyLgHeavy.weight : theme.textBodyDefaultHeavy.weight)
  }
}

