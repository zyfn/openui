import OpenUILang
import SwiftUI

enum OpenUIFormComponents {
    static let fieldNames = ["Input", "TextArea", "Select", "CheckBoxGroup", "RadioGroup", "SwitchGroup", "DatePicker", "Slider"]
    static var components: [OpenUIComponent] {
        [
            OpenUIReference.component("Form") { OpenUINativeForm(context: $0) },
            OpenUIReference.component("FormControl") { OpenUINativeFormControl(context: $0) },
            OpenUIReference.component("Buttons") { OpenUINativeButtons(context: $0) },
            OpenUIReference.component("Input") { OpenUINativeField(context: $0, kind: .input) },
            OpenUIReference.component("TextArea") { OpenUINativeField(context: $0, kind: .textArea) },
            OpenUIReference.component("Select") { OpenUINativeField(context: $0, kind: .select) },
            OpenUIReference.component("RadioGroup") { OpenUINativeField(context: $0, kind: .radio) },
            OpenUIReference.component("CheckBoxGroup") { OpenUINativeField(context: $0, kind: .checkbox) },
            OpenUIReference.component("SwitchGroup") { OpenUINativeField(context: $0, kind: .switches) },
            OpenUIReference.component("Slider") { OpenUINativeField(context: $0, kind: .slider) },
            OpenUIReference.component("DatePicker") { OpenUINativeField(context: $0, kind: .date) },
            OpenUIReference.component("Chips") { OpenUINativeField(context: $0, kind: .chips) },
            OpenUIReference.component("OptionCards") { OpenUINativeField(context: $0, kind: .optionCards) },
            OpenUIReference.component("SelectItem") { _ in EmptyView() },
            OpenUIReference.component("RadioItem") { _ in EmptyView() },
            OpenUIReference.component("CheckBoxItem") { _ in EmptyView() },
            OpenUIReference.component("SwitchItem") { _ in EmptyView() },
            OpenUIReference.component("ChipItem") { _ in EmptyView() },
            OpenUIReference.component("OptionCard") { _ in EmptyView() }
        ]
    }
}

private struct OpenUINativeForm: View {
    let context: OpenUIComponentContext
    @StateObject private var validation = NativeFormValidation()
    @Environment(\.displayScale) private var displayScale
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            if !context.children("fields").isEmpty {
                VStack(spacing: 0) {
                    ForEach(context.children("fields")) { child in
                        if child.id != context.children("fields").first?.id {
                            Rectangle().fill(context.theme.border).frame(height: 1 / displayScale)
                                .padding(.horizontal, 20)
                        }
                        context.render(child.value)
                    }
                }
                .background(
                    context.theme.controlSurface,
                    in: RoundedRectangle(cornerRadius: context.theme.cornerRadius, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: context.theme.cornerRadius, style: .continuous)
                        .strokeBorder(context.theme.border)
                )
                .environment(\.openUIFieldPresentation, .grouped)
            }
            context.slot("buttons").environment(\.openUIFormActions, true)
        }
        .environment(\.openUIExactFormName, context.codeUnitString("name"))
        .environment(\.openUIFormValidation, validation)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(context.string("name") ?? "Form")
    }
}

/// Adapts by native control shape and the available text size, never by a
/// business field name. Inline rows fall back to a vertical label/value pair.
private struct OpenUINativeFormControl: View {
    let context: OpenUIComponentContext
    @Environment(\.openUIFieldPresentation) private var presentation
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .body) private var rowHeight: CGFloat = {
        #if os(iOS)
            56
        #else
            40
        #endif
    }()
    private var compact: Bool {
        guard case .element(let input) = context.value("input") else { return false }
        return ["Input", "Select"].contains(input.typeName)
            || (input.typeName == "DatePicker" && PropValue.string(input, "mode") != "range")
    }
    private var grouped: Bool { presentation != .standalone }
    private var rowInset: CGFloat {
        #if os(iOS)
            compact && !typeSize.isAccessibilitySize ? 6 : 16
        #else
            compact ? 4 : 12
        #endif
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            layout
            if let hint = context.string("hint"), !hint.isEmpty {
                Text(hint).font(.footnote).foregroundStyle(context.theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, grouped ? 20 : 0)
        .padding(.vertical, grouped ? rowInset : 0)
        .frame(minHeight: grouped ? rowHeight : nil, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .environment(\.openUIFieldLabel, context.string("label"))
    }
    @ViewBuilder private var layout: some View {
        if grouped && compact && !typeSize.isAccessibilitySize {
            if #available(iOS 16, macOS 13, *) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline, spacing: 24) {
                        label.fixedSize(horizontal: true, vertical: true)
                        input.frame(minWidth: 120, maxWidth: .infinity)
                            .environment(\.openUIFieldPresentation, .inline)
                    }
                    stacked
                }
            } else { stacked }
        } else { stacked }
    }
    private var label: some View {
        Text(context.string("label") ?? "")
            .font(compact ? .body : .body.weight(.medium))
            .foregroundStyle(context.theme.foreground)
            .fixedSize(horizontal: false, vertical: true)
    }
    private var input: some View { context.slot("input") }
    private var stacked: some View {
        VStack(alignment: .leading, spacing: grouped ? 12 : 8) { label; input }
    }
}

private struct OpenUINativeButtons: View {
    let context: OpenUIComponentContext
    @ViewBuilder var body: some View {
        if context.string("direction") == "column" {
            VStack(alignment: .leading, spacing: 8) { buttons }
        } else {
            if #available(iOS 16, macOS 13, *) {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) { buttons }
                    VStack(alignment: .leading, spacing: 8) { buttons }
                }
            } else {
                VStack(alignment: .leading, spacing: 8) { buttons }
            }
        }
    }
    private var buttons: some View {
        ForEach(context.children("buttons")) { context.render($0.value) }
    }
}
