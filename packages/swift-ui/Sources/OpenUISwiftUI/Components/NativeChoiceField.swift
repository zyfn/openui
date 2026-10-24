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
  private var field: NativeFieldState { NativeFieldState(context: context) }
  private var selection: [OpenUIString] { NativeChoiceSelection.values(field.value) }
  var body: some View {
    Group {
      if cards {
        LazyVGrid(
          columns: typeSize.isAccessibilitySize
            ? [GridItem(.flexible())]
            : [GridItem(.adaptive(minimum: context.theme.minimumChoiceWidth), spacing: 12)],
          alignment: .leading,
          spacing: 12
        ) { options }
      } else {
        NativeWrappingRow(gap: 8) { options }
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
          choice(item, selected: selected)
        }.buttonStyle(.plain).disabled(
          !context.canInteract || PropValue.value(item, "disabled") == .boolean(true)
        )
        .accessibilityLabel(PropValue.string(item, cards ? "title" : "label") ?? key.displayString)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("openui.choice.\(field.name.displayString).\(key.displayString)")
      }
    }
  }
  private func choice(_ item: EvaluatedElement, selected: Bool) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      if cards { context.render(PropValue.value(item, "topContent") ?? .null) }
      HStack(spacing: 6) {
        if !cards { context.render(PropValue.value(item, "icon") ?? .null) }
        Text(PropValue.string(item, cards ? "title" : "label") ?? "").font(
          .body.weight(cards || selected ? .medium : .regular)
        )
        .fixedSize(horizontal: false, vertical: true)
        if cards {
          Spacer(minLength: 4)
          Image(systemName: selected ? "checkmark.circle.fill" : "circle").foregroundStyle(
            selected ? context.theme.accent : context.theme.secondary)
        }
      }
      if cards, let subtitle = PropValue.string(item, "subtitle") {
        Text(subtitle).font(.subheadline).foregroundStyle(context.theme.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }.padding(cards ? 14 : 10).frame(
      maxWidth: cards ? .infinity : nil, maxHeight: cards ? .infinity : nil, alignment: .topLeading
    )
    .background(
      selected ? context.theme.accent.opacity(0.06) : context.theme.controlSurface,
      in: RoundedRectangle(cornerRadius: cards ? context.theme.controlCornerRadius : 24)
    )
    .overlay(
      RoundedRectangle(cornerRadius: cards ? context.theme.controlCornerRadius : 24).strokeBorder(
        selected ? context.theme.accent.opacity(0.18) : context.theme.border, lineWidth: 1))
  }
}
