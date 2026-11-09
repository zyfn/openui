import SwiftUI

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

