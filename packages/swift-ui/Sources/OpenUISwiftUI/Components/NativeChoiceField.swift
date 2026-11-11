import OpenUILang
import SwiftUI

/// Presentation state mapping for upstream selectionFieldUtils. Field storage,
/// validation and submission remain the existing shared runtime adapters.
enum NativeChoiceSelection {
  static func isSingle(_ context: OpenUIComponentContext) -> Bool {
    (context.string("type") ?? (context.element.typeName == "Chips" ? "multiple" : "single"))
      == "single"
  }
  static func values(_ value: Value) -> [OpenUIString] {
    switch value {
    case .string(let text): return text.isEmpty ? [] : [text]
    case .array(let array):
      return array.compactMap {
        if case .string(let text) = $0 { return text }
        return nil
      }
    default: return []
    }
  }
  static func stored(_ values: [OpenUIString], single: Bool) -> Value {
    if single { return values.first.flatMap { $0.isEmpty ? nil : Value.string($0) } ?? .undefined }
    return .array(values.map(Value.string))
  }
  static func toggle(_ key: OpenUIString, value: Value, single: Bool) -> Value {
    let selection = single ? Array(values(value).prefix(1)) : values(value)
    let next =
      single
      ? (selection.first == key ? [] : [key])
      : selection.contains(key) ? selection.filter { $0 != key } : selection + [key]
    return stored(next, single: single)
  }
}

struct NativeChoiceField: View {
  let context: OpenUIComponentContext
  let cards: Bool
  @EnvironmentObject private var state: OpenUIState
  @Environment(\.dynamicTypeSize) private var typeSize
  @Environment(\.layoutDirection) private var direction
  @Environment(\.isEnabled) private var enabled
  @ScaledMetric(relativeTo: .body) private var textScale: CGFloat = 1
  private var field: NativeFieldState { NativeFieldState(context: context) }
  private var selection: [OpenUIString] { NativeChoiceSelection.values(field.value) }
  var body: some View {
    Group {
      if cards {
        NativeChoiceCardsLayout(minimumWidth: context.presentation.minimumChoiceWidth * textScale,
          gap: context.theme.spacing("m"),
          singleColumn: typeSize.isAccessibilitySize, rightToLeft: direction == .rightToLeft) { options }
      } else {
        NativeWrappingRow(gap: context.theme.spacing("s")) { options }
      }
    }.frame(maxWidth: .infinity, alignment: .leading).fixedSize(horizontal: false, vertical: true)
  }
  private var options: some View {
    ForEach(Array(field.options.enumerated()), id: \.offset) { _, item in
      if let key = PropValue.codeUnitString(item, "value"), !key.isEmpty {
        let selected = selection.contains(key)
        Button {
          guard PropValue.value(item, "disabled") != .boolean(true) else { return }
          field.write(
            NativeChoiceSelection.toggle(
              key, value: field.value, single: NativeChoiceSelection.isSingle(context)))
        } label: {
          choice(item, selected: selected).openUIControlTarget(alignment: .leading)
        }.buttonStyle(.plain).disabled(
          !context.canInteract || PropValue.value(item, "disabled") == .boolean(true)
        )
        .accessibilityLabel(PropValue.string(item, cards ? "title" : "label") ?? key.displayString)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("openui.choice.\(field.name.displayString).\(key.displayString)")
      }
    }
  }
  private func isDisabled(_ item: EvaluatedElement) -> Bool {
    !enabled || !context.canInteract || PropValue.value(item, "disabled") == .boolean(true)
  }
  private func choice(_ item: EvaluatedElement, selected: Bool) -> some View {
    VStack(alignment: .leading, spacing: context.theme.spacing("m")) {
      if cards { context.render(PropValue.value(item, "topContent") ?? .null) }
      cardCopy(item, selected: selected)
    }.padding(.horizontal, cards ? context.theme.componentStyle.objectInset : context.theme.spaceS)
    .padding(.vertical, cards ? context.theme.componentStyle.objectInset : context.theme.spaceXs).frame(
      maxWidth: cards ? .infinity : nil, maxHeight: cards ? .infinity : nil, alignment: .topLeading
    )
    .background(
      selected ? context.theme.componentStyle.selectedSurface : .clear,
      in: RoundedRectangle(cornerRadius: choiceRadius)
    )
    .overlay(
      RoundedRectangle(cornerRadius: choiceRadius).strokeBorder(
        selected && !isDisabled(item) ? context.theme.componentStyle.selectedBorder : context.theme.componentStyle.surfaceBorder, lineWidth: context.presentation.borderWidth))
  }
  private var choiceRadius: CGFloat { cards ? context.theme.componentStyle.optionRadius : context.theme.radiusFull }
  private func cardCopy(_ item: EvaluatedElement, selected: Bool) -> some View {
    VStack(alignment: .leading, spacing: context.theme.componentStyle.titleDetailGap) {
      HStack(spacing: context.theme.spacing("xs")) {
        if !cards { context.render(PropValue.value(item, "icon") ?? .null) }
        Text(PropValue.string(item, cards ? "title" : "label") ?? "").openUIFont(
          cards ? context.theme.textBodyDefaultHeavy : context.theme.textLabelDefaultHeavy, role: cards ? .title : .control
        )
        .foregroundStyle(isDisabled(item) ? context.theme.componentStyle.disabledText : context.theme.textNeutralPrimary)
        .fixedSize(horizontal: false, vertical: true)
        if cards {
          Spacer(minLength: 4)
          Image(systemName: selected ? "checkmark.circle.fill" : "circle").foregroundStyle(
            isDisabled(item) ? context.theme.componentStyle.disabledText
              : selected ? context.theme.componentStyle.selectedBorder : context.theme.textNeutralSecondary)
        }
      }
      if cards, let subtitle = PropValue.string(item, "subtitle") {
        Text(subtitle).nativeTextStyle(context.theme.textStyle(.supporting),
          color: isDisabled(item) ? context.theme.componentStyle.disabledText : nil)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }
}
