import OpenUILang
import SwiftUI

enum OpenUIDisplayComponents {
    static var components: [OpenUIComponent] {
        return [
            OpenUIReference.component("Label") {
                Text($0.string("text") ?? "").font(.subheadline.weight(.medium))
            },
            OpenUIReference.component("Separator") { context in NativeSeparator(context: context) },
            OpenUIReference.component("CodeBlock") { context in
                VStack(alignment: .leading, spacing: 8) {
                    if let language = context.string("language"), !language.isEmpty {
                        Text(language).font(.caption).foregroundStyle(.secondary)
                    }
                    ScrollView(.horizontal) {
                        Text(context.string("codeString") ?? "").font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }.padding(12).background(context.theme.surface, in: RoundedRectangle(cornerRadius: 10))
            },
            OpenUIReference.component("Col") { _ in EmptyView() },
            OpenUIReference.component("Table") { NativeDataTable(context: $0) },
            OpenUIReference.component("EditableTable") { NativeEditableTable(context: $0) },
            OpenUIReference.component("AccordionItem") { _ in EmptyView() },
            OpenUIReference.component("Accordion") { NativeAccordion(context: $0) },
            OpenUIReference.component("MetricIndicatorWithStrikethrough") {
                NativeMetric(context: $0, inline: false)
            },
            OpenUIReference.component("MetricIndicatorInline") {
                NativeMetric(context: $0, inline: true)
            },
        ]
    }
}

private struct NativeSeparator: View {
    let context: OpenUIComponentContext
    @ViewBuilder var body: some View {
        Group {
            if context.string("orientation") == "vertical" {
                Rectangle().fill(context.theme.border).frame(width: 1).frame(minHeight: 18)
            } else {
                Divider()
            }
        }.accessibilityHidden(context.flag("decorative") ?? true)
    }
}

private struct NativeMetric: View {
    let context: OpenUIComponentContext
    var inline: Bool
    var body: some View {
        Group {
            if inline {
                if #available(iOS 16, macOS 13, *) {
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) { content }
                        VStack(alignment: .leading, spacing: 4) { content }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 4) { content }
                }
            } else {
                VStack(alignment: .leading, spacing: 4) { content }
            }
        }.accessibilityElement(children: .combine)
    }
    @ViewBuilder private var content: some View {
        Text(context.string("value") ?? "").font(context.theme.typography.metric).monospacedDigit()
        if let previous = context.string("previousValue") {
            Text(previous).strikethrough().font(context.theme.typography.caption).foregroundStyle(context.theme.secondary)
        }
        if case .object(let trend) = context.value("trend"), case .number(let number) = trend["value"],
            number.isFinite,
            case .string(let direction) = trend["direction"]
        {
            Label(
                number.formatted(.number.precision(.fractionLength(0...2))) + "%",
                systemImage: direction == "down" ? "arrow.down" : "arrow.up"
            )
            .font(context.theme.typography.caption).foregroundStyle(context.theme.secondary)
        }
        if let subtext = context.string("subtext") {
            Text(subtext).font(context.theme.typography.detail).foregroundStyle(context.theme.secondary)
        }
    }
}

private struct NativeAccordion: View {
    let context: OpenUIComponentContext
    @State private var selected: OpenUIString?
    @State private var initialized = false
    private var items: [OpenUIRenderChild] { context.children("items") }
    private var keys: [OpenUIString] {
        items.compactMap { child in
            guard case .element(let item) = child.value else { return nil }
            return PropValue.codeUnitString(item, "value")
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(items) { child in
                if case .element(let item) = child.value, let key = PropValue.codeUnitString(item, "value")
                {
                    DisclosureGroup(
                        isExpanded: Binding(
                            get: { selected == key },
                            set: { open in
                                initialized = true
                                selected = open ? key : nil
                            })
                    ) {
                        context.render(PropValue.value(item, "content") ?? .null).padding(.top, 6)
                    } label: {
                        Text(PropValue.string(item, "trigger") ?? "").font(context.theme.typography.heading)
                    }
                    .padding(context.theme.cardPadding)
                    .modifier(NativeCardSurface(theme: context.theme))
                }
            }
        }
        .onAppear(perform: reconcileSelection)
        .onChange(of: keys) { _ in reconcileSelection() }
    }
    private func reconcileSelection() {
        if keys.isEmpty { initialized = false; selected = nil; return }
        if !initialized || selected.map({ !keys.contains($0) }) == true {
            initialized = true
            selected = keys.first
        }
    }

}

private struct NativeDataTable: View {
    struct Column: Identifiable {
        let id: String
        let title: String
        let data: [Value]
    }
    let context: OpenUIComponentContext
    @Environment(\.openUITableCellPolicy) private var cellPolicy
    @ScaledMetric(relativeTo: .body) private var minimumWidth: CGFloat = 88
    @State private var availableWidth: CGFloat = 0
    @State private var currentPage = 0
    @Namespace private var measurementScope
    private let pageSize = 10 // Pinned upstream Table's DEFAULT_PAGE_SIZE.
    private let columnGap: CGFloat = 16
    private var fallbackWidth: CGFloat {
        max(minimumWidth, (availableWidth - columnGap * CGFloat(max(0, columns.count - 1))) / CGFloat(max(1, columns.count)))
    }
    private var columns: [Column] {
        context.children("columns").compactMap { child in
            guard case .element(let element) = child.value else { return nil }
            let raw = PropValue.value(element, "data") ?? .null
            let data: [Value]
            if case .array(let values) = raw {
                data = Array(values)
            } else {
                data = raw == .null || raw == .undefined ? [] : [raw]
            }
            return Column(id: child.id, title: PropValue.string(element, "label") ?? "", data: data)
        }
    }
    private var rowCount: Int { columns.map { $0.data.count }.max() ?? 0 }
    private var pageCount: Int { max(1, (rowCount + pageSize - 1) / pageSize) }
    private var safePage: Int { min(currentPage, pageCount - 1) }
    private var visibleRows: Range<Int> {
        let start = safePage * pageSize
        return start..<min(start + pageSize, rowCount)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal) { tableContent }
            if pageCount > 1 {
                NativePageControls(page: safePage, count: pageCount, enabled: context.canInteract, identifier: "openui.table") { currentPage = $0 }
            }
        }
        .background(
            GeometryReader { geometry in
                Color.clear.preference(key: NativeTableWidthKey.self, value: [measurementScope: geometry.size.width])
            }
        )
        .onPreferenceChange(NativeTableWidthKey.self) { values in
            guard let width = values[measurementScope], width.isFinite, width > 0, abs(width - availableWidth) > 0.5 else { return }
            availableWidth = width
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("openui.table")
        .environment(\.openUIActionDensity, .compact)
        .onChange(of: pageCount) { count in currentPage = min(currentPage, max(0, count - 1)) }
    }
    @ViewBuilder private var tableContent: some View {
        if #available(iOS 16, macOS 13, *) {
            NativeDataTableLayout(columns: columns.count, width: max(minimumWidth, availableWidth),
                minimum: minimumWidth, gap: columnGap) {
                ForEach(columns) { column in
                    Text(column.title).font(context.theme.typography.detail.weight(.semibold))
                        .foregroundStyle(context.theme.secondary)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
                context.theme.border.frame(height: 0.5).layoutValue(key: NativeTableBoundaryKey.self, value: true)
                    .accessibilityHidden(true)
                ForEach(visibleRows, id: \.self) { row in
                    ForEach(columns) { column in
                        cell(column.data.indices.contains(row) ? column.data[row] : .null)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .accessibilityElement(children: .contain)
                            .accessibilityIdentifier("openui.table.cell.\(row).\(column.id)")
                    }
                    if row < visibleRows.upperBound - 1 {
                        context.theme.border.frame(height: 0.5).layoutValue(key: NativeTableBoundaryKey.self, value: true)
                            .accessibilityHidden(true)
                    }
                }
            }
        } else {
            // Grid is unavailable on the package's original iOS 15/macOS 12
            // deployment baseline. Retain the existing scrollable fallback.
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: columnGap) {
                    ForEach(columns) { column in
                        Text(column.title).font(.subheadline.weight(.semibold))
                            .frame(width: fallbackWidth, alignment: .leading)
                    }
                }.padding(.vertical, 10)
                Divider()
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(visibleRows, id: \.self) { row in
                        HStack(alignment: .top, spacing: columnGap) {
                            ForEach(columns) { column in
                                cell(column.data.indices.contains(row) ? column.data[row] : .null)
                                    .frame(width: fallbackWidth, alignment: .leading)
                            }
                        }.padding(.vertical, 10).accessibilityElement(children: .combine)
                        if row < visibleRows.upperBound - 1 { Divider() }
                    }
                }
            }
        }
    }
    @ViewBuilder private func cell(_ value: Value) -> some View {
        if case .boolean(let flag) = value {
            Text(flag ? "true" : "false")
        } else {
            context.renderTableCell(value, policy: cellPolicy)
        }
    }
}

/// Every column receives one shared proposal before any row is measured.
/// Flexible columns share available space; intrinsic/fixed children can keep a
/// wider scrollable table. Nothing depends on the component type in a cell.
enum NativeTableColumnPlacement {
    static func widths(ideal: [CGFloat], minimum: CGFloat, available: CGFloat, gap: CGFloat) -> [CGFloat] {
        guard !ideal.isEmpty else { return [] }
        let available = available.isFinite ? max(0, available) : 0
        let floor = max(1, minimum)
        var widths = ideal.map { _ in floor }
        var remaining = max(0, available - gap * CGFloat(ideal.count - 1) - floor * CGFloat(ideal.count))
        let order = ideal.indices.sorted { ideal[$0] < ideal[$1] }
        for (offset, index) in order.enumerated() {
            let target = ideal[index].isFinite ? max(floor, ideal[index]) : available
            let extra = min(max(0, target - floor), remaining / CGFloat(order.count - offset))
            widths[index] += extra
            remaining -= extra
        }
        if remaining > 0 {
            for index in widths.indices { widths[index] += remaining / CGFloat(widths.count) }
        }
        return widths
    }
}

@available(iOS 16, macOS 13, *)
private struct NativeTableBoundaryKey: LayoutValueKey { static let defaultValue = false }

@available(iOS 16, macOS 13, *)
private struct NativeDataTableLayout: Layout {
    let columns: Int
    let width: CGFloat
    let minimum: CGFloat
    let gap: CGFloat

    private func frames(_ views: Subviews) -> [CGRect] {
        guard columns > 0 else { return [] }
        let cells = views.indices.filter { !views[$0][NativeTableBoundaryKey.self] }
        var ideal = Array(repeating: minimum, count: columns)
        for (position, index) in cells.enumerated() {
            let measured = views[index].sizeThatFits(.unspecified).width
            if measured.isFinite { ideal[position % columns] = max(ideal[position % columns], measured) }
        }
        var widths = NativeTableColumnPlacement.widths(ideal: ideal, minimum: minimum, available: width, gap: gap)
        // Some children explicitly refuse compression (for example a supplied
        // fixed media size). Widen that column for every row, not just its cell.
        for (position, index) in cells.enumerated() {
            let column = position % columns
            let measured = views[index].sizeThatFits(ProposedViewSize(width: widths[column], height: nil)).width
            if measured.isFinite { widths[column] = max(widths[column], measured) }
        }
        var result = Array(repeating: CGRect.zero, count: views.count)
        var y: CGFloat = 0
        for start in stride(from: 0, to: cells.count, by: columns) {
            let end = min(start + columns, cells.count)
            let sizes = (start..<end).map { views[cells[$0]].sizeThatFits(ProposedViewSize(width: widths[$0 % columns], height: nil)) }
            let height = sizes.map(\.height).filter(\.isFinite).max() ?? 0
            var x: CGFloat = 0
            for position in start..<end {
                let index = cells[position]
                let column = position % columns
                result[index] = CGRect(x: x, y: y, width: widths[column], height: height)
                x += result[index].width + gap
            }
            y += height
            if end > start {
                let divider = cells[end - 1] + 1
                if views.indices.contains(divider), views[divider][NativeTableBoundaryKey.self] {
                    result[divider] = CGRect(x: 0, y: y, width: max(0, x - gap), height: 0.5)
                    y += 0.5
                }
            }
        }
        return result
    }
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let placed = frames(subviews)
        return CGSize(width: placed.map(\.maxX).max() ?? 0, height: placed.map(\.maxY).max() ?? 0)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (view, frame) in zip(subviews, frames(subviews)) {
            view.place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY), anchor: .topLeading,
                proposal: ProposedViewSize(frame.size))
        }
    }
}

private struct NativeTableWidthKey: PreferenceKey {
    static let defaultValue: [Namespace.ID: CGFloat] = [:]
    static func reduce(value: inout [Namespace.ID: CGFloat], nextValue: () -> [Namespace.ID: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { _, next in next })
    }
}
