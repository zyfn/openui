import SwiftUI
import OpenUILang

public enum OpenUIStandardComponents {
    public static func library(id: String? = nil) throws -> OpenUIComponentLibrary {
        try OpenUIComponentLibrary(components: components, root: "Stack", id: id, componentGroups: OpenUIReference.groups)
    }
    public static var components: [OpenUIComponent] {
        let implementations = OpenUISelectionComponents.components + OpenUIFormComponents.components
            + OpenUIDisplayComponents.components + OpenUIContentComponents.components
            + OpenUIChartComponents.components + [
            OpenUIReference.component("Stack") { OpenUIStack(context: $0, wrapJustifyBetweenAsStart: true) },
            OpenUIReference.component("TextContent") { context in
                NativeMarkdownText(text: context.string("text") ?? "", mode: .textContent,
                    style: .textContent(context.string("size"), theme: context.theme))
            },
            OpenUIReference.component("Image") { NativeContentImage(context: $0) },
            OpenUIReference.component("Button") { OpenUINativeButton(context: $0) },
            OpenUIReference.component("Card") { context in
                OpenUIStack(context: context)
                    .modifier(OpenUICardSurface(theme: context.theme, variant: context.string("variant")))
            }
        ]
        let byName = Dictionary(uniqueKeysWithValues: implementations.map { ($0.definition.name, $0) })
        return OpenUIReference.definitions.map { definition in
            guard let component = byName[definition.name] else { preconditionFailure("Missing native renderer: " + definition.name) }
            return component
        }
    }

}

struct OpenUICardSurface: ViewModifier {
    let theme: OpenUITheme
    let variant: String?
    func body(content: Content) -> some View {
        content.environment(\.openUIActionDensity, .compact)
            .padding(theme.cardPadding).frame(maxWidth: .infinity, alignment: .leading)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous))
            .modifier(NativeCardSurface(
                theme: theme,
                fill: variant == "clear" ? .clear : variant == "sunk" ? theme.surface : nil,
                bordered: variant != "clear" && variant != "sunk"))
    }
}

private struct OpenUIStretchHeightKey: EnvironmentKey { static let defaultValue = false }
extension EnvironmentValues {
    var openUIStretchHeight: Bool {
        get { self[OpenUIStretchHeightKey.self] }
        set { self[OpenUIStretchHeightKey.self] = newValue }
    }
}

private struct OpenUIStack: View {
    let context: OpenUIComponentContext
    // Upstream Stack normalizes wrapped space-between; upstream Card does not.
    var wrapJustifyBetweenAsStart = false
    private var gap: CGFloat { context.theme.spacing(context.string("gap")) }
    private var children: [OpenUIRenderChild] { context.children() }

    var body: some View {
        OpenUIFlexLayout(
            direction: context.string("direction") ?? "column", gap: gap,
            align: context.string("align") ?? "stretch", justify: context.string("justify") ?? "start",
            wrap: context.flag("wrap") == true, fillsHeight: context.stretchesVertically,
            wrapJustifyBetweenAsStart: wrapJustifyBetweenAsStart
        ) {
            ForEach(children) { child in
                context.render(child.value)
                    .environment(\.openUIStretchHeight, context.string("direction") == "row" && stretches)
            }
        }
    }
    private var stretches: Bool { context.string("align") == nil || context.string("align") == "stretch" }
}

private struct NativeContentImage: View {
    let context: OpenUIComponentContext
    var body: some View {
        NativeRemoteImage(src: context.string("src"), alt: context.string("alt") ?? "",
            layout: context.stretchesVertically ? .stretch : .intrinsic)
            // Suggest a media width when a row measures its children. Grid card
            // widths are unrelated; the parent still controls the final bounds.
            .frame(idealWidth: context.theme.thumbnailSize)
            .clipShape(RoundedRectangle(cornerRadius: context.theme.mediaCornerRadius, style: .continuous))
    }
}
