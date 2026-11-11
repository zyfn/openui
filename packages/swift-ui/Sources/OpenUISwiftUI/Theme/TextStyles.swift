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

  init(font: OpenUIFont, color: Color, role: NativeTextRole, emphasisWeight: Font.Weight) {
    self.font = font.resolved(for: role)
    self.color = color; self.role = role; self.emphasisWeight = emphasisWeight
  }

  func richText(numeric: Bool = false, color override: Color? = nil) -> NativeRichTextStyle {
    .init(font: font, numeric: numeric, color: override ?? color, role: role, emphasisWeight: emphasisWeight)
  }
}

extension OpenUIThemeValues {
  func objectTitleStyle(emphasized: Bool = true) -> NativeTextStyle {
    .init(font: emphasized ? textHeadingXs : textHeadingXs.weight(textBodyDefault.weight),
      color: textNeutralPrimary, role: .title, emphasisWeight: textHeadingXs.weight)
  }

  func inlineTextStyle(_ size: String?, emphasized: Bool = false, numeric: Bool = false) -> NativeRichTextStyle {
    let base = textStyle(size == "xs" ? .compactBody : .body)
    return .init(font: inlineFont(size, emphasized: emphasized, numeric: numeric),
      numeric: numeric, color: base.color, role: base.role,
      emphasisWeight: inlineFont(size, emphasized: true, numeric: numeric).weight)
  }

    func inlineFont(_ size: String?, emphasized: Bool = false, numeric: Bool = false) -> OpenUIFont {
        // Numeric values and controls keep their own scale when reading text grows.
        if numeric {
            switch size {
            case "xs": return textLabelSm.weight(emphasized ? textBodySmHeavy.weight : textBodySm.weight)
            case "lg": return emphasized ? textBodyLgHeavy : textBodyLg
            default: return emphasized ? textNumbersDefaultHeavy : textNumbersDefaultHeavy.weight(textBodyDefault.weight)
            }
        }
        switch size {
        case "xs": return emphasized ? textBodySmHeavy : textBodySm
        case "lg": return emphasized ? textBodyLgHeavy : textBodyLg
        default: return emphasized ? textBodyDefaultHeavy : textBodyDefault
        }
    }
    func fieldFont(_ size: String?) -> OpenUIFont { size == "small" ? textBodySm : textBodyDefault }
  func entityLabelStyle(compact: Bool) -> NativeRichTextStyle {
    .init(font: compact ? textBodySm : textBodyDefault, color: textNeutralSecondary,
      role: compact ? .detail : .body)
  }

  func entityValueStyle(compact: Bool, numeric: Bool, header: Bool, footer: Bool) -> NativeRichTextStyle {
    let font = compact ? textBodySm : textBodyDefault
    return .init(font: footer ? textBodyLgHeavy
      : (numeric || header ? inlineFont(compact ? "xs" : "sm", emphasized: true, numeric: numeric)
         : font.weight(textLabelDefaultHeavy.weight)), numeric: numeric,
      color: header ? textNeutralSecondary : textNeutralPrimary,
      role: footer ? .title : compact ? .detail : .body)
  }

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
    let base = theme.textStyle(small ? .compactBody : .body)
    return .init(font: font, color: base.color, role: base.role,
      emphasisWeight: small ? theme.textBodySmHeavy.weight : large ? theme.textBodyLgHeavy.weight : theme.textBodyDefaultHeavy.weight)
  }
}

