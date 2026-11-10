import SwiftUI
import OpenUILang

struct OpenUICardSurface: ViewModifier {
    let theme: OpenUIThemeValues
    let variant: String?
    func body(content: Content) -> some View {
        let surface = NativeContentSurface(variant, fallback: .card)
        content.environment(\.openUIActionDensity, .compact)
            .padding(.horizontal, theme.componentStyle.panelInset)
            .padding(.vertical, variant == "clear" ? 0 : theme.componentStyle.panelInset)
            .frame(maxWidth: .infinity, alignment: .leading)
            // Background and media own their corners; the open container must
            // not mask glyphs at the edge of its unpadded content.
            .modifier(NativeCardSurface(
                theme: theme,
                fill: surface.fill(theme),
                bordered: surface.bordered))
    }
}

private struct OpenUIStretchHeightKey: EnvironmentKey { static let defaultValue = false }
private struct OpenUIControlWidthKey: EnvironmentKey { static let defaultValue = false }
extension EnvironmentValues {
    var openUIFillControlWidth: Bool {
        get { self[OpenUIControlWidthKey.self] }
        set { self[OpenUIControlWidthKey.self] = newValue }
    }
    var openUIStretchHeight: Bool {
        get { self[OpenUIStretchHeightKey.self] }
        set { self[OpenUIStretchHeightKey.self] = newValue }
    }
}

struct OpenUIStack: View {
    @Environment(\.openUIMediaWidthReady) private var parentMediaWidthReady
    let context: OpenUIComponentContext
    // Upstream Stack normalizes wrapped space-between; upstream Card does not.
    var wrapJustifyBetweenAsStart = false
    private var gap: CGFloat { context.theme.spacing(context.string("gap")) }
    private var children: [OpenUIRenderChild] { context.presentationChildren() }

    var body: some View {
        OpenUIFlexLayout(
            direction: context.string("direction") ?? "column", gap: gap,
            align: context.string("align") ?? "stretch", justify: context.string("justify") ?? "start",
            wrap: context.flag("wrap") == true, fillsHeight: context.stretchesVertically,
            wrapJustifyBetweenAsStart: wrapJustifyBetweenAsStart
        ) {
            ForEach(children) { child in
                context.render(child.value)
                    // Row measurement may depend on an unfinished child's
                    // intrinsic content. Keep reading text progressive, but
                    // do not reveal fluid media inside that changing width.
                    .environment(\.openUIMediaWidthReady,
                        parentMediaWidthReady && (context.string("direction") != "row" || mediaWidthReady(child.value)))
                    .environment(\.openUIFillControlWidth,
                        (context.string("direction") ?? "column") == "column" && stretches)
                    .environment(\.openUIStretchHeight, context.string("direction") == "row" && stretches)
            }
        }
    }
    private var stretches: Bool { context.string("align") == nil || context.string("align") == "stretch" }
    private func mediaWidthReady(_ value: Value) -> Bool {
        switch value {
        case .element(let element): return element.isSourceComplete
        case .array(let values): return values.allSatisfy(mediaWidthReady)
        default: return true
        }
    }
}

struct NativeContentImage: View {
    let context: OpenUIComponentContext
    var body: some View {
        NativeRemoteImage(src: context.string("src"), alt: context.string("alt") ?? "",
            layout: .cover)
            // Suggest a media width when a row measures its children. Grid card
            // widths are unrelated; the parent still controls the final width.
            // Standard Image uses the shared native cover role.
            .frame(idealWidth: context.presentation.thumbnailSize)
            .clipShape(RoundedRectangle(cornerRadius: context.theme.radiusM, style: .continuous))
    }
}
