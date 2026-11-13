import OpenUILang
import SwiftUI

struct OpenUINativeButton: View {
    let context: OpenUIComponentContext
    private var role: ButtonRole? { context.string("type") == "destructive" ? .destructive : nil }
    private var variant: String { context.string("variant") ?? "primary" }
    private var presentationReady: Bool {
        let source = context.element.sourceReadiness
        return context.codeUnitString("label") != nil && source.closed
          && ["label", "variant", "type", "size"].allSatisfy { source[$0].complete }
    }
    var body: some View {
        button.buttonStyle(
            NativeActionButtonStyle(
                theme: context.theme, variant: variant,
                size: context.string("size"), destructive: role == .destructive,
                stretchesTarget: context.stretchesVertically)
        )
        .accessibilityLabel(context.string("label") ?? "")
        .opacity(presentationReady ? 1 : 0)
        .accessibilityHidden(!presentationReady)
        .allowsHitTesting(presentationReady)
    }
    private var button: some View {
        OpenUIActionSurface(
            context: context, message: context.string("label") ?? "", action: context.value("action"),
            role: role, useNativeStyle: true, validateForm: true, showsProgress: true
        ) {
            Text(context.string("label") ?? "").fixedSize(horizontal: false, vertical: true)
                // The parent lays out the outer touch target. Expanding the label
                // to that height would paint the invisible target as button fill.
                // Keep natural text height (including wrapped lines), while column
                // actions may still fill their proposed width.
                .frame(maxWidth: context.fillsControlWidth ? .infinity : nil)
        }
    }
}
