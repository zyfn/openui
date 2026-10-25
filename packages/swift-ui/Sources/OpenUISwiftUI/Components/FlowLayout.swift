import SwiftUI

/// Pure placement is also used by tests; no global display state is consulted.
enum OpenUIFlowPlacement {
    static func frames(sizes: [CGSize], width: CGFloat, gap: CGFloat, align: String, justify: String,
                       wrap: Bool = true, baselines: [CGFloat] = [], crossExtent: CGFloat? = nil) -> [CGRect] {
        let width = max(0, width)
        var rows: [[Int]] = [], row: [Int] = [], used: CGFloat = 0
        for index in sizes.indices {
            let itemWidth = min(width, max(0, sizes[index].width))
            if wrap && !row.isEmpty, used + gap + itemWidth > width { rows.append(row); row = []; used = 0 }
            used += (row.isEmpty ? 0 : gap) + itemWidth; row.append(index)
        }
        if !row.isEmpty { rows.append(row) }
        var frames = Array(repeating: CGRect.zero, count: sizes.count)
        var y: CGFloat = 0
        for row in rows {
            let baseline = row.map { baselines.indices.contains($0) ? baselines[$0] : sizes[$0].height }.max() ?? 0
            let height = max(!wrap ? crossExtent ?? 0 : 0, row.map {
                align == "baseline" ? baseline + sizes[$0].height - (baselines.indices.contains($0) ? baselines[$0] : sizes[$0].height) : sizes[$0].height
            }.max() ?? 0)
            let content = row.reduce(CGFloat.zero) { $0 + min(width, max(0, sizes[$1].width)) }
            let free = max(0, width - content - CGFloat(max(0, row.count - 1)) * gap)
            let extra: CGFloat
            let initial: CGFloat
            switch justify {
            case "between": extra = row.count > 1 ? free / CGFloat(row.count - 1) : 0; initial = 0
            case "evenly": extra = free / CGFloat(row.count + 1); initial = extra
            case "around": extra = free / CGFloat(row.count); initial = extra / 2
            case "center": extra = 0; initial = free / 2
            case "end": extra = 0; initial = free
            default: extra = 0; initial = 0
            }
            var x = initial
            for index in row {
                let size = CGSize(width: min(width, max(0, sizes[index].width)), height: sizes[index].height)
                let offset = align == "center" ? (height - size.height) / 2 : align == "end" ? height - size.height
                    : align == "baseline" ? baseline - (baselines.indices.contains(index) ? baselines[index] : size.height) : 0
                frames[index] = CGRect(x: x, y: y + offset, width: size.width, height: align == "stretch" ? height : size.height)
                x += size.width + gap + extra
            }
            y += height + gap
        }
        return frames
    }
}

@available(iOS 16, macOS 13, *)
struct OpenUIFlexLayout: Layout {
    var direction: String
    var gap: CGFloat
    var align: String
    var justify: String
    var wrap: Bool
    var fillsHeight = false

    private func finite(_ value: CGFloat?) -> CGFloat? {
        value.flatMap { $0.isFinite ? max(0, $0) : nil }
    }
    private func frames(_ proposal: ProposedViewSize, _ subviews: Subviews) -> [CGRect] {
        guard !subviews.isEmpty else { return [] }
        if direction == "column" {
            let measured = subviews.map { $0.sizeThatFits(ProposedViewSize(width: finite(proposal.width), height: nil)) }
            let width = finite(proposal.width) ?? measured.map(\.width).max() ?? 0
            let height = finite(proposal.height) ?? measured.reduce(0) { $0 + $1.height } + gap * CGFloat(subviews.count - 1)
            // A column's main axis is vertical; the same spacing math applies.
            return OpenUIFlowPlacement.frames(sizes: measured.map { CGSize(width: $0.height, height: $0.width) },
                width: height, gap: gap, align: align == "baseline" ? "start" : align, justify: justify,
                wrap: false, crossExtent: width).map {
                    CGRect(x: $0.minY, y: $0.minX, width: $0.height, height: $0.width)
                }
        }
        let ideal = subviews.map { $0.sizeThatFits(.unspecified) }
        let width = finite(proposal.width) ?? ideal.reduce(0) { $0 + $1.width } + gap * CGFloat(subviews.count - 1)
        var proposals = ideal.map { min(width, $0.width) }
        if !wrap {
            // Offer the least flexible children space first, as a native stack
            // does. No media/content percentage or component-type heuristic.
            var remaining = max(0, width - gap * CGFloat(subviews.count - 1))
            let order = subviews.indices.sorted { ideal[$0].width < ideal[$1].width }
            for (position, index) in order.enumerated() {
                let offered = min(ideal[index].width, remaining / CGFloat(order.count - position))
                proposals[index] = max(0, offered)
                remaining = max(0, remaining - subviews[index].sizeThatFits(ProposedViewSize(width: offered, height: nil)).width)
            }
        }
        let dimensions = subviews.indices.map {
            subviews[$0].dimensions(in: ProposedViewSize(width: proposals[$0], height: nil))
        }
        return OpenUIFlowPlacement.frames(sizes: dimensions.map { CGSize(width: $0.width, height: $0.height) },
            width: width, gap: gap, align: align, justify: wrap && justify == "between" ? "start" : justify,
            wrap: wrap, baselines: dimensions.map { $0[.firstTextBaseline] }, crossExtent: finite(proposal.height))
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let measured = ProposedViewSize(width: proposal.width, height: fillsHeight ? proposal.height : nil)
        let placed = frames(measured, subviews)
        return CGSize(width: finite(proposal.width) ?? placed.map(\.maxX).max() ?? 0,
                      height: max(fillsHeight ? finite(proposal.height) ?? 0 : 0, placed.map(\.maxY).max() ?? 0))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (view, frame) in zip(subviews, frames(ProposedViewSize(width: bounds.width, height: fillsHeight ? bounds.height : nil), subviews)) {
            view.place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                       anchor: .topLeading, proposal: ProposedViewSize(frame.size))
        }
    }
}

enum NativeMediaRowAxis { case horizontal, vertical, adaptive }

/// Media and copy are measured together. The decision uses rendered geometry,
/// not a screen breakpoint, character count, or a content-specific width ratio.
enum NativeMediaRowPlacement {
    struct Result {
        var media: CGRect
        var text: CGRect
        var size: CGSize
        var stacked: Bool
    }

    static func measure(width: CGFloat, media idealMedia: CGSize, gap: CGFloat,
                        axis: NativeMediaRowAxis, resizesMedia: Bool, minimumMediaSide: CGFloat,
                        centered: Bool, text: (CGFloat) -> CGSize) -> Result {
        let width = width.isFinite ? max(1, width) : 1
        func finite(_ value: CGFloat) -> CGFloat { value.isFinite ? max(0, value) : 0 }
        func copy(_ proposed: CGFloat) -> CGSize {
            let measured = text(max(1, proposed))
            return CGSize(width: max(max(1, proposed), finite(measured.width)), height: finite(measured.height))
        }
        let full = copy(width)
        var media = CGSize(width: finite(idealMedia.width), height: finite(idealMedia.height))
        if resizesMedia {
            let side = min(width, min(media.width, max(minimumMediaSide, full.height)))
            media = CGSize(width: side, height: side)
        }
        let gap = media.width > 0 && media.height > 0 ? max(0, gap) : 0
        let remaining = max(0, width - media.width - gap)
        let beside = copy(remaining)
        // A free-flowing row can stack when wrapping alongside the media costs
        // more vertical space than putting that media above the full-width text.
        let stack = axis == .vertical || (axis == .adaptive
            && (remaining <= 0 || beside.width > remaining + 0.5 || beside.height > full.height + media.height + gap))
        if stack {
            let textFrame = CGRect(x: 0, y: media.height + gap, width: full.width, height: full.height)
            return Result(media: CGRect(origin: .zero, size: media), text: textFrame,
                          size: CGSize(width: max(width, max(media.width, full.width)), height: textFrame.maxY), stacked: true)
        }

        // Explicit horizontal layout remains horizontal. Preserve fixed media
        // dimensions and give over-constrained copy its full viewport width.
        // Scrolling then reveals that readable paragraph without a private
        // minimum width, smaller font, or automatic direction change.
        let overflows = remaining <= 0 || beside.width > remaining + 0.5
            || beside.height > full.height + media.height + gap
        let measured = overflows ? full : beside
        let height = max(media.height, measured.height)
        let mediaY = centered ? (height - media.height) / 2 : 0
        let textY = centered ? (height - measured.height) / 2 : 0
        let textFrame = CGRect(x: media.width + gap, y: textY, width: measured.width, height: measured.height)
        return Result(media: CGRect(origin: CGPoint(x: 0, y: mediaY), size: media), text: textFrame,
                      size: CGSize(width: max(width, textFrame.maxX), height: height), stacked: false)
    }
}

/// Shared by ImageText/IconText and list media. Scroll overflow is intentional
/// when a program requests a horizontal row whose fixed media cannot fit.
struct NativeMediaRow<Media: View, Copy: View>: View {
    var axis: NativeMediaRowAxis
    var gap: CGFloat
    var resizesMedia = false
    var centered = false
    @ViewBuilder var media: Media
    @ViewBuilder var copy: Copy
    @ScaledMetric(relativeTo: .body) private var minimumMediaSide: CGFloat = 44
    @Environment(\.openUITheme) private var theme
    @Namespace private var scope
    @State private var width: CGFloat = 0
    @State private var height: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            if width > 0 {
                ScrollView(.horizontal, showsIndicators: true) {
                    row.fixedSize(horizontal: false, vertical: true)
                        .background(GeometryReader { geometry in
                            Color.clear.preference(key: NativeMediaRowHeights.self, value: [scope: geometry.size.height])
                        })
                }
                .frame(height: max(1, height))
                .accessibilityIdentifier("openui.media-row")
            } else { Color.clear.frame(height: 1) }
        }
        .frame(idealWidth: theme.minimumCompactCardWidth, maxWidth: .infinity, alignment: .leading)
        .background(GeometryReader { geometry in
            Color.clear.preference(key: NativeMediaRowWidths.self, value: [scope: geometry.size.width])
        })
        .onPreferenceChange(NativeMediaRowWidths.self) { values in
            guard let next = values[scope], next.isFinite, next > 0 else { return }
            if abs(next - width) > 0.5 { width = next }
        }
        .onPreferenceChange(NativeMediaRowHeights.self) { values in
            guard let next = values[scope], next.isFinite, next > 0 else { return }
            if abs(next - height) > 0.5 { height = next }
        }
    }

    @ViewBuilder private var row: some View {
        if #available(iOS 16, macOS 13, *) {
            NativeMediaRowLayout(width: width, gap: gap, axis: axis,
                resizesMedia: resizesMedia, minimumMediaSide: minimumMediaSide, centered: centered) {
                media
                copy
            }
        } else if axis == .horizontal {
            // The old systems cannot run Layout measurements. Keep an explicit
            // horizontal relationship, constrain copy to the viewport, and let
            // any fixed-size media overflow scroll instead of clipping text.
            HStack(alignment: centered ? .center : .top, spacing: gap) {
                media
                copy.frame(width: width, alignment: .leading)
            }.frame(minWidth: width, alignment: .leading)
        } else {
            // Adaptive list rows choose the safe vertical fallback here;
            // this is usable but not identical to the measured modern layout.
            VStack(alignment: .leading, spacing: gap) {
                media
                copy.frame(width: width, alignment: .leading)
            }.frame(minWidth: width, alignment: .leading)
        }
    }
}

@available(iOS 16, macOS 13, *)
private struct NativeMediaRowLayout: Layout {
    let width: CGFloat
    let gap: CGFloat
    let axis: NativeMediaRowAxis
    let resizesMedia: Bool
    let minimumMediaSide: CGFloat
    let centered: Bool

    private func measured(_ subviews: Subviews) -> NativeMediaRowPlacement.Result {
        guard subviews.count > 1 else {
            let size = subviews.first?.sizeThatFits(ProposedViewSize(width: width, height: nil)) ?? .zero
            return .init(media: .zero, text: CGRect(origin: .zero, size: size), size: size, stacked: true)
        }
        return NativeMediaRowPlacement.measure(width: width, media: subviews[0].sizeThatFits(.unspecified),
            gap: gap, axis: axis, resizesMedia: resizesMedia, minimumMediaSide: minimumMediaSide,
            centered: centered) { subviews[1].sizeThatFits(ProposedViewSize(width: $0, height: nil)) }
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        measured(subviews).size
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = measured(subviews)
        let frames = subviews.count > 1 ? [result.media, result.text] : [result.text]
        for (view, frame) in zip(subviews, frames) {
            view.place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                       anchor: .topLeading, proposal: ProposedViewSize(frame.size))
        }
    }
}

private struct NativeMediaRowWidths: PreferenceKey {
    static let defaultValue: [Namespace.ID: CGFloat] = [:]
    static func reduce(value: inout [Namespace.ID: CGFloat], nextValue: () -> [Namespace.ID: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { _, next in next })
    }
}
private struct NativeMediaRowHeights: PreferenceKey {
    static let defaultValue: [Namespace.ID: CGFloat] = [:]
    static func reduce(value: inout [Namespace.ID: CGFloat], nextValue: () -> [Namespace.ID: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { _, next in next })
    }
}
