import SwiftUI
import OpenUILang

struct OpenUICardSurface: ViewModifier {
    let theme: OpenUIThemeValues
    let variant: String?
    var active = true
    @Environment(\.openUIAncestorLayoutReady) private var parentLayoutReady
    func body(content: Content) -> some View {
        let surface = NativeContentSurface(variant, fallback: .card)
        let ready = active && parentLayoutReady
        content.environment(\.openUIActionDensity, .compact)
            .padding(.horizontal, ready ? theme.componentStyle.panelInset : 0)
            .padding(.vertical, !ready || variant == "clear" ? 0 : theme.componentStyle.panelInset)
            .frame(maxWidth: .infinity, alignment: .leading)
            // Background and media own their corners; the open container must
            // not mask glyphs at the edge of its unpadded content.
            .modifier(NativeCardSurface(
                theme: theme,
                fill: ready ? surface.fill(theme) : .clear,
                bordered: ready && surface.bordered))
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
    @Environment(\.openUIAncestorLayoutReady) private var parentLayoutReady
    let context: OpenUIComponentContext
    // Upstream Stack normalizes wrapped space-between; upstream Card does not.
    var wrapJustifyBetweenAsStart = false
    private var layoutReady: Bool { parentLayoutReady && context.layoutConfigurationReady }
    private var direction: String { layoutReady ? context.string("direction") ?? "column" : "column" }
    private var gap: CGFloat { layoutReady ? context.theme.spacing(context.string("gap")) : context.theme.spaceM }
    private var projection: (value: Value, blocked: Bool) {
        let value = context.presentationValue()
        return layoutReady ? (value, false) : NativeLayoutContract.readingPrefix(value)
    }
    private var children: [OpenUIRenderChild] { OpenUIRenderChild.children(of: projection.value) }

    var body: some View {
        OpenUIFlexLayout(
            direction: direction, gap: gap,
            align: layoutReady ? context.string("align") ?? "stretch" : "stretch",
            justify: layoutReady ? context.string("justify") ?? "start" : "start",
            wrap: layoutReady && context.flag("wrap") == true, fillsHeight: layoutReady && context.stretchesVertically,
            wrapJustifyBetweenAsStart: wrapJustifyBetweenAsStart
        ) {
            ForEach(children) { child in
                context.render(child.value)
                    .environment(\.openUIAncestorLayoutReady, layoutReady)
                    // Row measurement may depend on an unfinished child's
                    // intrinsic content. Keep reading text progressive, but
                    // do not reveal fluid media inside that changing width.
                    .environment(\.openUIMediaWidthReady,
                        parentMediaWidthReady && layoutReady && (direction != "row" || mediaWidthReady(child.value)))
                    .environment(\.openUIFillControlWidth,
                        direction == "column" && stretches)
                    .environment(\.openUIStretchHeight, direction == "row" && stretches)
            }
            if !layoutReady && (projection.blocked || children.isEmpty) {
                NativePendingContent(loading: !context.hasDataFailure && (context.isStreaming || context.hasPendingData),
                    terminalMessage: context.hasDataFailure ? "Content unavailable" : "Content is incomplete")
            }
        }
    }
    private var stretches: Bool { !layoutReady || context.string("align") == nil || context.string("align") == "stretch" }
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
