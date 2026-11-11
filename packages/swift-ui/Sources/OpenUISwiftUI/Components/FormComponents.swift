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
