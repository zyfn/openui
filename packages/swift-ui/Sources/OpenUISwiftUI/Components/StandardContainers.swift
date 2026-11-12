import SwiftUI
import OpenUILang

private struct OpenUICardMediaInsetKey: EnvironmentKey { static let defaultValue: CGFloat = 0 }
extension EnvironmentValues {
    var openUICardMediaInset: CGFloat {
        get { self[OpenUICardMediaInsetKey.self] }
        set { self[OpenUICardMediaInsetKey.self] = newValue }
    }
}

/// Only the leading image owns the card's top corners. Body media retains its
/// ordinary image corners and does not extend through surrounding text.
struct NativeCardTopMediaShape: Shape {
    let radius: CGFloat
    var topOnly = false
    func path(in rect: CGRect) -> Path {
        var path = RoundedRectangle(cornerRadius: radius, style: .continuous).path(in: rect)
        if topOnly { path.addRect(CGRect(x: rect.minX, y: rect.midY, width: rect.width, height: rect.height / 2)) }
        return path
    }
}

struct OpenUIStyledCard: View {
    let context: OpenUIComponentContext
    @ScaledMetric(relativeTo: .body) private var readingScale: CGFloat = 1

    private var minimumWidth: CGFloat {
        let surface = NativeContentSurface(context.string("variant"), fallback: .card)
        let width = surface == .clear ? context.presentation.minimumTextColumnWidth
            : context.presentation.minimumCardWidth
        return max(0, width.isFinite ? width * readingScale : 0)
    }

    var body: some View {
        OpenUIStack(context: context)
            .environment(\.openUICardMediaInset,
                context.string("variant") == "clear" || context.string("variant") == "sunk"
                    ? 0 : context.theme.componentStyle.panelInset)
            .modifier(OpenUICardSurface(theme: context.theme, variant: context.string("variant"),
                active: context.layoutConfigurationReady))
            .layoutValue(key: OpenUIFlexGrowKey.self, value: true)
            .layoutValue(key: OpenUIFlexMinimumWidthKey.self, value: minimumWidth)
    }
}

struct OpenUICardSurface: ViewModifier {
    let theme: OpenUIThemeValues
    let variant: String?
    var active = true
    @Environment(\.openUIAncestorLayoutReady) private var parentLayoutReady
    func body(content: Content) -> some View {
        let surface = NativeContentSurface(variant, fallback: .card)
        let ready = active && parentLayoutReady
        let inset = ready && surface != .clear ? theme.componentStyle.panelInset : 0
        content.environment(\.openUIActionDensity, .compact)
            // Transparent layout units own allocation, not gutters. The parent
            // supplies the gap; nested clear cards must not accumulate insets.
            .padding(inset)
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
    @Environment(\.openUICardMediaInset) private var cardMediaInset
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
        let mediaWidthReady = parentMediaWidthReady && layoutReady && (direction != "row" || context.rowWidthReady)
        let content = children
        let first = content.first?.id
        OpenUIFlexLayout(
            direction: direction, gap: gap,
            align: layoutReady ? context.string("align") ?? "stretch" : "stretch",
            justify: layoutReady ? context.string("justify") ?? "start" : "start",
            wrap: layoutReady && context.flag("wrap") == true, fillsHeight: layoutReady && context.stretchesVertically,
            wrapJustifyBetweenAsStart: wrapJustifyBetweenAsStart
        ) {
            ForEach(content) { child in
                context.render(child.value)
                    .environment(\.openUICardMediaInset,
                        layoutReady && direction == "column" && child.id == first ? cardMediaInset : 0)
                    .environment(\.openUIAncestorLayoutReady, layoutReady)
                    // Unknown siblings can still change the whole row's width
                    // allocation. Once all native Card roles are known, copy
                    // can grow independently inside their stable columns.
                    .environment(\.openUIMediaWidthReady,
                        mediaWidthReady)
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
}

struct NativeContentImage: View {
    let context: OpenUIComponentContext
    @Environment(\.openUICardMediaInset) private var cardMediaInset
    var body: some View {
        NativeRemoteImage(src: context.string("src"), alt: context.string("alt") ?? "",
            layout: .cover)
            // Suggest a media width when a row measures its children. Grid card
            // widths are unrelated; the parent still controls the final width.
            // Standard Image uses the shared native cover role.
            .frame(idealWidth: context.presentation.thumbnailSize)
            .clipShape(NativeCardTopMediaShape(radius: cardMediaInset > 0 ? context.theme.radius3xl : context.theme.radiusM,
                topOnly: cardMediaInset > 0))
            .padding(.horizontal, -cardMediaInset)
            .padding(.top, -cardMediaInset)
    }
}
