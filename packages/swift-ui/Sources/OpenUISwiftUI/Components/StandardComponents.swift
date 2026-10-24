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
            OpenUIReference.component("Stack") { OpenUIStack(context: $0) },
            OpenUIReference.component("TextContent") { context in
                NativeInlineMarkdown.text(context.string("text") ?? "")
                    .font(textFont(context.string("size"), typography: context.theme.typography)).textSelection(.enabled)
                    .foregroundStyle(context.string("size") == "small" ? context.theme.secondary : context.theme.foreground)
                    .fixedSize(horizontal: false, vertical: true)
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
    private static func textFont(_ size: String?, typography: OpenUITypography) -> Font {
        switch size {
        case "small": return typography.detail
        case "small-heavy": return typography.detail.weight(.semibold)
        case "large": return typography.title.weight(.regular)
        case "large-heavy": return typography.display
        default: return typography.body
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
    private var gap: CGFloat { context.theme.spacing(context.string("gap")) }
    private var children: [OpenUIRenderChild] { context.children() }

    var body: some View {
        if #available(iOS 16, macOS 13, *) {
            OpenUIFlexLayout(direction: context.string("direction") ?? "column", gap: gap,
                align: context.string("align") ?? "stretch", justify: context.string("justify") ?? "start",
                wrap: context.flag("wrap") == true, fillsHeight: context.stretchesVertically) {
                ForEach(children) { child in
                    context.render(child.value)
                        .environment(\.openUIStretchHeight, context.string("direction") == "row" && stretches)
                }
            }
        } else {
            legacyBody
        }
    }
    @ViewBuilder private var legacyBody: some View {
        if context.string("direction") == "row" {
            if context.flag("wrap") == true {
                // Layout is unavailable here. The compatibility grid still
                // follows the container proposal, without a screen breakpoint.
                LazyVGrid(columns: [GridItem(.adaptive(minimum: context.theme.minimumCardWidth), spacing: gap)], spacing: gap) {
                    ForEach(children) { context.render($0.value) }
                }
            } else {
                HStack(alignment: verticalAlignment, spacing: 0) {
                    if ["around", "evenly"].contains(context.string("justify") ?? "") { Spacer(minLength: 0) }
                    ForEach(Array(children.enumerated()), id: \.element.id) { index, child in
                        context.render(child.value)
                            .frame(maxHeight: stretches ? .infinity : nil, alignment: .top)
                        if index < children.count - 1 {
                            Color.clear.frame(width: gap)
                            if ["between", "around", "evenly"].contains(context.string("justify") ?? "") { Spacer(minLength: 0) }
                            // Around has half an interior space at either edge.
                            if context.string("justify") == "around" { Spacer(minLength: 0) }
                        }
                    }
                    if ["around", "evenly"].contains(context.string("justify") ?? "") { Spacer(minLength: 0) }
                }.fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: rowAlignment)
            }
        } else {
            VStack(alignment: horizontalAlignment, spacing: gap) {
                ForEach(children) { child in
                    if context.string("align") == nil || context.string("align") == "stretch" {
                        context.render(child.value).frame(maxWidth: .infinity, alignment: .leading)
                    } else { context.render(child.value) }
                }
            }.frame(maxWidth: .infinity, alignment: columnAlignment)
        }
    }
    private var stretches: Bool { context.string("align") == nil || context.string("align") == "stretch" }

    private var verticalAlignment: VerticalAlignment {
        switch context.string("align") {
        case "center": return .center
        case "end": return .bottom
        case "baseline": return .firstTextBaseline
        default: return .top
        }
    }
    private var horizontalAlignment: HorizontalAlignment {
        switch context.string("align") { case "center": return .center; case "end": return .trailing; default: return .leading }
    }
    private var rowAlignment: Alignment {
        switch context.string("justify") { case "center": return .center; case "end": return .trailing; default: return .leading }
    }
    private var columnAlignment: Alignment {
        switch context.string("align") { case "center": return .center; case "end": return .trailing; default: return .leading }
    }
}

private struct NativeContentImage: View {
    let context: OpenUIComponentContext
    var body: some View {
        NativeRemoteImage(src: context.string("src"), alt: context.string("alt") ?? "", layout: .aspect(3.0 / 2.0))
            // Flexible containers need a useful ideal size even before the
            // bitmap loads. The actual parent proposal still controls size.
            .frame(idealWidth: context.theme.minimumCompactCardWidth)
            .clipShape(RoundedRectangle(cornerRadius: context.theme.mediaCornerRadius, style: .continuous))
    }
}
