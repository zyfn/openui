import OpenUILang
import SwiftUI


struct OpenUINativeForm: View {
    let context: OpenUIComponentContext
    @StateObject private var validation = NativeFormValidation()
    var body: some View {
        // Keep one field/action subtree. The native task-panel appearance reuses
        // Card's surface; it does not add a second form or change its submission.
        VStack(alignment: .leading, spacing: context.theme.spacing("ml")) {
            ForEach(context.children("fields")) { context.render($0.value) }
            context.slot("buttons").environment(\.openUIFormActions, true)
        }
        .environment(\.openUIFieldPresentation, .standalone)
        .environment(\.openUIExactFormName, context.codeUnitString("name"))
        .environment(\.openUIFormValidation, validation)
        .modifier(OpenUICardSurface(theme: context.theme,
            variant: context.presentation.formShowsCardSurface ? "card" : "clear",
            active: context.layoutConfigurationReady))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(context.string("name") ?? "Form")
        .onAppear { updateDeclarations() }
        .onChange(of: context.element) { _ in updateDeclarations() }
        .onChange(of: context.canInteract) { _ in updateDeclarations() }
    }
    private func updateDeclarations() {
        let names: Set<String> = ["Input", "TextArea", "Select", "CheckBoxGroup", "SwitchGroup",
            "RadioGroup", "Slider", "DatePicker", "Chips", "OptionCards"]
        var declared: [(OpenUIString, NativeFormValidation.Field)] = []
        var seen = Set<ObjectIdentifier>()
        func visit(_ value: Value, depth: Int) {
            guard depth < 128 else { return }
            switch value {
            case .element(let element):
                guard seen.insert(ObjectIdentifier(element)).inserted, element.typeName != "Form" else { return }
                if names.contains(element.typeName) {
                    let child = context.childContext(element, form: context.codeUnitString("name"))
                    let field = NativeFieldState(context: child)
                    let draft: NativeSliderDraft? = child.existingEditingRecord(kind: "slider", name: field.name)
                    declared.append((field.name, .init(rules: field.rules, value: { field.validationValue },
                        prepare: { [weak draft] in draft?.flush() },
                        draftError: { [weak draft] in draft?.validationError() })))
                } else {
                    for (_, prop) in element.props { visit(prop, depth: depth + 1) }
                }
            case .array(let values): for value in values { visit(value, depth: depth + 1) }
            case .object(let fields): for field in fields { visit(field.value, depth: depth + 1) }
            default: break
            }
        }
        visit(context.value("fields") ?? .null, depth: 0)
        validation.setDeclarations(declared)
    }
}

struct OpenUINativeFormControl: View {
    let context: OpenUIComponentContext
    private var inputOwnsLabel: Bool {
        let type: String?
        if case .element(let input) = context.value("input") { type = input.typeName }
        else { type = context.element.sourceReadiness["input"].placeholder?.typeName }
        return type.map { context.componentOwnsFormControlLabel($0) } ?? false
    }
    var body: some View {
        VStack(alignment: .leading, spacing: context.theme.spacing("s")) {
            if !inputOwnsLabel {
                Text(context.string("label") ?? "")
                    .nativeTextStyle(context.theme.textStyle(.fieldLabel))
                    .fixedSize(horizontal: false, vertical: true)
            }
            context.slot("input")
            if let hint = context.string("hint"), !hint.isEmpty {
                Text(hint).nativeTextStyle(context.theme.textStyle(.supporting))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .environment(\.openUIFieldLabel, context.string("label"))
    }
}

struct OpenUINativeButtons: View {
    let context: OpenUIComponentContext
    @Environment(\.layoutDirection) private var direction
    var body: some View {
        NativeButtonsLayout(column: context.string("direction") == "column",
            rightToLeft: direction == .rightToLeft,
            rowGap: context.theme.spacing("m"), columnGap: context.theme.spacing("m")) { buttons }
    }
    private var buttons: some View {
        ForEach(context.presentationChildren("buttons")) {
            context.render($0.value)
                .environment(\.openUIFillControlWidth, context.string("direction") == "column")
                .environment(\.openUIStretchHeight, context.string("direction") != "column")
        }
    }
}
