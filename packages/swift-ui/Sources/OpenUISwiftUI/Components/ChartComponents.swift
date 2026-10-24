import OpenUILang
import SwiftUI

enum OpenUIChartComponents {
  static let chartNames = [
    "BarChart", "LineChart", "AreaChart", "RadarChart", "HorizontalBarChart", "PieChart",
    "RadialChart", "SingleStackedBarChart", "ScatterChart",
  ]
  static var components: [OpenUIComponent] {
    chartNames.map { name in OpenUIReference.component(name) { NativeChart(context: $0) } }
      + ["Series", "Slice", "ScatterSeries", "Point"].map { name in
        OpenUIReference.component(name) { _ in EmptyView() }
      }
  }
}

/// Accept both evaluated component references and inline schema objects, just
/// as the upstream chart data helpers do. No schema coercion happens here.
struct NativeChartData {
  struct Series {
    let name: String
    let values: [Double]
  }
  struct Point {
    let x: Double
    let y: Double
    let z: Double?
  }
  struct Scatter {
    let name: String
    let points: [Point]
  }
  let labels: [String]
  let series: [Series]
  let slices: [Double]
  let scatter: [Scatter]
  init(context: OpenUIComponentContext) {
    labels = NativeValue.array(context.value("labels")).map { value in
      if case .string(let s) = value { return s.displayString }
      return NativeValue.string(value, "category") ?? ""
    }
    series = NativeValue.array(context.value("series")).map { value in
      Series(
        name: NativeValue.string(value, "category") ?? "",
        values: Self.numbers(NativeValue.prop(value, "values")))
    }
    let values = Self.numbers(context.value("values"))
    slices =
      values.isEmpty
      ? NativeValue.array(context.value("labels")).map { NativeValue.number($0, "value") ?? 0 }
      : values
    scatter = NativeValue.array(context.value("datasets")).map { value in
      Scatter(
        name: NativeValue.string(value, "name") ?? "",
        points: NativeValue.array(NativeValue.prop(value, "points")).compactMap { point in
          guard let x = NativeValue.number(point, "x"), let y = NativeValue.number(point, "y")
          else { return nil }
          return Point(x: x, y: y, z: NativeValue.number(point, "z"))
        })
    }
  }
  static func numbers(_ value: Value?) -> [Double] {
    NativeValue.array(value).map {
      if case .number(let n) = $0, n.isFinite { return n }
      return 0
    }
  }
  func value(_ seriesIndex: Int, _ labelIndex: Int) -> Double {
    guard series.indices.contains(seriesIndex),
      series[seriesIndex].values.indices.contains(labelIndex)
    else { return 0 }
    return series[seriesIndex].values[labelIndex]
  }
  var accessibilityRows: [String] {
    if !scatter.isEmpty {
      return scatter.flatMap { s in
        s.points.map { "\(s.name): x \($0.x), y \($0.y)" + ($0.z.map { ", z \($0)" } ?? "") }
      }
    }
    if !series.isEmpty {
      return labels.indices.map { i in
        labels[i] + ": "
          + series.indices.map { "\(series[$0].name) \(value($0, i))" }.joined(separator: ", ")
      }
    }
    return labels.indices.map { "\(labels[$0]): \(slices.indices.contains($0) ? slices[$0] : 0)" }
  }
}

/// Canvas works on the package's iOS 15/macOS 12 baseline. All chart families
/// use actual plotted geometry, with axes, legends, pointer inspection and
/// complete VoiceOver data, including negative and degenerate domains.
struct NativeChart: View {
  let context: OpenUIComponentContext
  @State private var inspected: Int?
  @State private var inspectionLocation = CGPoint.zero
  @State private var pinnedInspection = false
  @State private var axisMeasurements = NativeChartAxisMeasurements()
  @ScaledMetric(relativeTo: .caption) private var axisScale: CGFloat = 1
  @Namespace private var measurementScope
  private var data: NativeChartData { NativeChartData(context: context) }
  private var name: String { context.element.typeName }
  private var palette: [Color] {
    context.theme.dataColors.isEmpty ? [context.theme.accent] : context.theme.dataColors
  }
  private var legend: [String] {
    if name == "ScatterChart" { return data.scatter.map(\.name) }
    return data.series.isEmpty ? data.labels : data.series.map(\.name)
  }
  private var drawing: NativeChartDrawing {
    NativeChartDrawing(
      data: data, name: name, variant: context.string("variant"),
      semi: context.string("appearance") == "semiCircular", palette: palette,
      secondary: context.theme.secondary, border: context.theme.border,
      gridColor: context.theme.chartGrid, axisColor: context.theme.chartAxis,
      canvasColor: context.theme.canvas, labelFont: context.theme.typography.caption,
      inspected: inspected, axisScale: axisScale, axisMeasurements: axisMeasurements)
  }
  private var measuredAxisLabels: some View {
    let labels = drawing.axisLabels
    return HStack(spacing: 0) {
      ForEach(Array((labels.left + labels.bottom).enumerated()), id: \.offset) { index, label in
        Text(label).font(context.theme.typography.caption).monospacedDigit()
          .lineLimit(1).fixedSize()
          .background(GeometryReader { geometry in
            Color.clear.preference(key: NativeChartAxisMeasurementKey.self, value: [measurementScope:
              NativeChartAxisMeasurements(
                leftWidth: index < labels.left.count ? geometry.size.width : 0,
                bottomWidth: index >= labels.left.count ? geometry.size.width : 0,
                lineHeight: geometry.size.height)])
          })
      }
    }.fixedSize().hidden().allowsHitTesting(false).accessibilityHidden(true)
  }
  /// Touch scrolling remains native until a deliberate press activates
  /// inspection. Desktop pointer dragging has no competing touch-scroll intent.
  var body: some View {
    VStack(alignment: .leading, spacing: context.theme.contentSpacing) {
      GeometryReader { geometry in
        Canvas { canvas, size in
          drawing.draw(
            in: &canvas, size: size, xLabel: context.string("xLabel"),
            yLabel: context.string("yLabel"))
        }
        .lineLimit(1).truncationMode(.middle)
        .contentShape(Rectangle())
        .modifier(NativeChartInteraction { point, pinned in
          let next = point.flatMap { drawing.inspectionIndex(at: $0, size: geometry.size) }
          if pinned && pinnedInspection && next == inspected { inspected = nil; pinnedInspection = false }
          else {
            inspected = next; pinnedInspection = pinned
            if let point { inspectionLocation = point }
          }
        })
        .accessibilityIdentifier("openui-chart-" + name)
        .accessibilityLabel([name, context.string("xLabel"), context.string("yLabel")]
          .compactMap { $0 }.joined(separator: ", "))
        .accessibilityChildren {
          ForEach(Array(data.accessibilityRows.enumerated()), id: \.offset) { _, row in Text(row) }
        }
        .overlay(alignment: .topLeading) {
          if let inspected, data.accessibilityRows.indices.contains(inspected) {
            NativeChartTooltip(text: data.accessibilityRows[inspected],
              anchor: inspectionLocation, bounds: geometry.size, theme: context.theme)
          }
        }
      }.frame(
        height: CGFloat(
          min(
            1200,
            max(100, context.number("height") ?? (name == "SingleStackedBarChart" ? 100 : 250)))))
      NativeWrappingRow(gap: 16) {
        ForEach(Array(legend.enumerated()), id: \.offset) { index, title in
          HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
              .fill(palette[index % palette.count]).frame(width: 8, height: 8)
              .accessibilityHidden(true)
            Text(title).font(context.theme.typography.caption)
              .foregroundStyle(context.theme.secondary)
          }.accessibilityElement(children: .combine)
        }
      }
    }.frame(maxWidth: .infinity, alignment: .leading)
      .background(alignment: .topLeading) { measuredAxisLabels }
      .onPreferenceChange(NativeChartAxisMeasurementKey.self) { measurements in
        let next = measurements[measurementScope] ?? NativeChartAxisMeasurements()
        if next != axisMeasurements { axisMeasurements = next }
      }
      .onChange(of: data.accessibilityRows) { _ in inspected = nil; pinnedInspection = false }
  }
}

private struct NativeChartTooltip: View {
  let text: String
  let anchor: CGPoint
  let bounds: CGSize
  let theme: OpenUITheme
  var body: some View {
    if #available(iOS 16, macOS 13, *) {
      NativeChartTooltipLayout(anchor: anchor, bounds: bounds) { label }
        .allowsHitTesting(false)
    } else {
      label.padding(8).frame(maxWidth: bounds.width, maxHeight: bounds.height, alignment: .topLeading)
        .allowsHitTesting(false)
    }
  }
  private var label: some View {
    Text(text).font(theme.typography.caption).monospacedDigit()
      .foregroundStyle(theme.foreground).fixedSize(horizontal: false, vertical: true)
      .padding(.horizontal, 10).padding(.vertical, 8)
      .background(theme.controlSurface, in: RoundedRectangle(cornerRadius: theme.controlCornerRadius))
      .overlay(RoundedRectangle(cornerRadius: theme.controlCornerRadius).strokeBorder(theme.border, lineWidth: 0.5))
      .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
      .accessibilityIdentifier("openui-chart-inspection")
  }
}

enum NativeChartTooltipPlacement {
  static func frame(size: CGSize, anchor: CGPoint, bounds: CGSize) -> CGRect {
    let margin: CGFloat = 8
    let width = min(size.width, max(1, bounds.width - 2 * margin))
    let height = min(size.height, max(1, bounds.height - 2 * margin))
    let x = max(margin, min(anchor.x - width / 2, bounds.width - width - margin))
    let above = anchor.y - height - margin
    let y = max(margin, min(above >= margin ? above : anchor.y + margin, bounds.height - height - margin))
    return CGRect(x: x, y: y, width: width, height: height)
  }
}

@available(iOS 16, macOS 13, *)
private struct NativeChartTooltipLayout: Layout {
  let anchor: CGPoint
  let bounds: CGSize
  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize { bounds }
  func placeSubviews(in rect: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    guard let view = subviews.first else { return }
    let size = view.sizeThatFits(ProposedViewSize(width: min(240, max(1, bounds.width - 16)), height: nil))
    let frame = NativeChartTooltipPlacement.frame(size: size, anchor: anchor, bounds: bounds)
    view.place(at: CGPoint(x: rect.minX + frame.minX, y: rect.minY + frame.minY), anchor: .topLeading,
      proposal: ProposedViewSize(frame.size))
  }
}

struct NativeChartAxisMeasurements: Equatable {
  var leftWidth: CGFloat = 0
  var bottomWidth: CGFloat = 0
  var lineHeight: CGFloat = 0
  func merging(_ other: Self) -> Self {
    Self(leftWidth: max(leftWidth, other.leftWidth), bottomWidth: max(bottomWidth, other.bottomWidth),
      lineHeight: max(lineHeight, other.lineHeight))
  }
}

private struct NativeChartAxisMeasurementKey: PreferenceKey {
  static let defaultValue: [Namespace.ID: NativeChartAxisMeasurements] = [:]
  static func reduce(value: inout [Namespace.ID: NativeChartAxisMeasurements], nextValue: () -> [Namespace.ID: NativeChartAxisMeasurements]) {
    value.merge(nextValue(), uniquingKeysWith: { $0.merging($1) })
  }
}

/// One layout for drawing and hit testing. Text measurement can expand the
/// axis gutters, while bounded text drawing keeps very long labels contained.
struct NativeChartLayout {
  let rect: CGRect
  let scale: CGFloat
  let lineHeight: CGFloat
  let tickOffset: CGFloat
  let bottomLabelWidth: CGFloat
  let measuredBottomLabelWidth: CGFloat
  let showsBottomLabels: Bool
  let showsXAxisTitle: Bool
  let showsYAxisTitle: Bool

  init(size: CGSize, scale: CGFloat = 1, measurements: NativeChartAxisMeasurements = .init()) {
    let scale = max(1, scale)
    let lineHeight = max(16 * scale, measurements.lineHeight)
    let tickOffset = max(12 * scale, lineHeight / 2 + 4 * scale)
    let right = min(12 * scale, size.width)
    let left = min(max(44 * scale, measurements.leftWidth + 8 * scale),
      max(0, size.width - right - min(80, size.width)))
    let top = min(max(18 * scale, lineHeight + 2 * scale), max(0, size.height - 40))
    let bottom = min(max(40 * scale, tickOffset + lineHeight * 1.5 + 4 * scale),
      max(0, size.height - top - 40))
    rect = CGRect(x: left, y: top, width: max(1, size.width - left - right),
      height: max(1, size.height - top - bottom))
    self.scale = scale
    self.lineHeight = lineHeight
    self.tickOffset = tickOffset
    bottomLabelWidth = max(56 * scale, measurements.bottomWidth + 12 * scale)
    measuredBottomLabelWidth = measurements.bottomWidth > 0 ? measurements.bottomWidth : 44 * scale
    showsXAxisTitle = bottom >= lineHeight + 2 * scale
    showsYAxisTitle = top >= lineHeight + 2
    showsBottomLabels = bottom >= tickOffset + lineHeight * 1.5 + 4 * scale
  }

  struct CategoryLabel {
    let index: Int
    let x: CGFloat
    let anchor: UnitPoint
    let width: CGFloat
  }

  func categoryLabels(count: Int) -> [CategoryLabel] {
    guard count > 0, showsBottomLabels else { return [] }
    let capacity = max(1, Int(rect.width / max(1, measuredBottomLabelWidth + 8 * scale)))
    let visibleCount = min(count, capacity)
    let indices = visibleCount == 1 ? [0] : (0..<visibleCount).map {
      Int((Double($0) * Double(count - 1) / Double(visibleCount - 1)).rounded())
    }
    let pitch = rect.width / CGFloat(count)
    let centers = indices.map { rect.minX + pitch * (CGFloat($0) + 0.5) }
    return indices.enumerated().map { offset, index in
      let center = centers[offset]
      let left = offset == 0 ? rect.minX : (centers[offset - 1] + center) / 2 + 2 * scale
      let right = offset == centers.count - 1 ? rect.maxX : (center + centers[offset + 1]) / 2 - 2 * scale
      if offset == 0, measuredBottomLabelWidth / 2 > center - left {
        return CategoryLabel(index: index, x: left, anchor: .leading, width: max(1, right - left))
      }
      if offset == centers.count - 1, measuredBottomLabelWidth / 2 > right - center {
        return CategoryLabel(index: index, x: right, anchor: .trailing, width: max(1, right - left))
      }
      return CategoryLabel(index: index, x: center, anchor: .center,
        width: max(1, min(center - left, right - center) * 2))
    }
  }

}

struct NativeChartDrawing {
  let data: NativeChartData
  let name: String
  let variant: String?
  let semi: Bool
  let palette: [Color]
  let secondary: Color
  let border: Color
  var gridColor: Color? = nil
  var axisColor: Color? = nil
  var canvasColor: Color = .white
  var labelFont: Font = .caption2
  var inspected: Int? = nil
  var axisScale: CGFloat = 1
  var axisMeasurements = NativeChartAxisMeasurements()
  private var gridColorValue: Color { gridColor ?? border }
  private var axisColorValue: Color { axisColor ?? secondary }
  private func color(_ index: Int) -> Color {
    palette.isEmpty ? secondary : palette[index % palette.count]
  }
  /// Inspection and drawing share the projection, including negative domains
  /// and bubble sizes. A scatter chart does not have categorical labels.
  func inspectionIndex(at location: CGPoint, size: CGSize) -> Int? {
    if name == "ScatterChart" {
      return NativeScatterProjection(data: data, layout: layout(size)).nearestIndex(to: location)
    }
    guard !data.labels.isEmpty else { return nil }
    let rect = layout(size).rect
    if ["BarChart", "HorizontalBarChart", "LineChart", "AreaChart"].contains(name),
      !rect.contains(location) { return nil }
    let fraction = name == "HorizontalBarChart"
      ? (location.y - rect.minY) / rect.height
      : (location.x - rect.minX) / rect.width
    return min(data.labels.count - 1, max(0, Int(fraction * CGFloat(data.labels.count))))
  }
  func draw(in canvas: inout GraphicsContext, size: CGSize, xLabel: String?, yLabel: String?) {
    guard size.width > 0, size.height > 0 else { return }
    switch name {
    case "PieChart", "RadialChart", "SingleStackedBarChart": circular(&canvas, size)
    case "RadarChart": radar(&canvas, size)
    case "ScatterChart": scatter(&canvas, size)
    default: cartesian(&canvas, size)
    }
    let chartLayout = layout(size)
    if let xLabel, chartLayout.showsXAxisTitle {
      text(
        xLabel, at: CGPoint(x: size.width / 2, y: size.height - 2 * axisScale), canvas: &canvas,
        anchor: .bottom, maxWidth: size.width
      )
    }
    if let yLabel, chartLayout.showsYAxisTitle {
      text(yLabel, at: CGPoint(x: 4, y: 2), canvas: &canvas, anchor: .topLeading,
        maxWidth: max(1, size.width - 8))
    }
  }
  private func text(
    _ value: String, at point: CGPoint, canvas: inout GraphicsContext, anchor: UnitPoint = .center,
    maxWidth: CGFloat? = nil
  ) {
    let label = Text(value).font(labelFont).monospacedDigit().foregroundColor(axisColorValue)
    if let maxWidth {
      let resolved = canvas.resolve(label)
      let available = max(1, maxWidth)
      let measured = resolved.measure(in: CGSize(width: available, height: .greatestFiniteMagnitude))
      let width = min(available, measured.width)
      canvas.draw(resolved, in: CGRect(
        x: point.x - width * anchor.x, y: point.y - measured.height * anchor.y,
        width: width, height: measured.height))
    } else {
      canvas.draw(label, at: point, anchor: anchor)
    }
  }
  private func number(_ value: Double) -> String { String(format: "%.3g", value) }
  func layout(_ size: CGSize) -> NativeChartLayout {
    NativeChartLayout(size: size, scale: axisScale, measurements: axisMeasurements)
  }
  private var domain: (low: Double, high: Double) {
    let stacked = ["BarChart", "HorizontalBarChart"].contains(name) && variant == "stacked"
    var low = 0.0
    var high = 0.0
    for i in data.labels.indices {
      let values = data.series.indices.map { data.value($0, i) }
      low = min(low, stacked ? values.filter { $0 < 0 }.reduce(0, +) : values.min() ?? 0)
      high = max(high, stacked ? values.filter { $0 > 0 }.reduce(0, +) : values.max() ?? 0)
    }
    return (low, high == low ? low + 1 : high)
  }
  var axisLabels: (left: [String], bottom: [String]) {
    func ticks(_ low: Double, _ high: Double) -> [String] {
      // The grid can reduce from four intervals to one as text grows. Measure
      // every possible displayed value, including thirds in scientific notation.
      var labels: [String] = []
      for count in 1...4 {
        for index in 0...count {
          let label = number(low + (high - low) * Double(index) / Double(count))
          if !labels.contains(label) { labels.append(label) }
        }
      }
      return labels
    }
    if name == "ScatterChart" {
      let projection = NativeScatterProjection(data: data, size: .zero)
      return (ticks(projection.yMin, projection.yMax), ticks(projection.xMin, projection.xMax))
    }
    guard ["BarChart", "HorizontalBarChart", "LineChart", "AreaChart"].contains(name)
      else { return ([], []) }
    let bounds = domain
    let numeric = ticks(bounds.low, bounds.high)
    return name == "HorizontalBarChart" ? (data.labels, numeric) : (numeric, data.labels)
  }
  private func grid(
    _ canvas: inout GraphicsContext, rect: CGRect, low: Double, high: Double,
    horizontal: Bool = false, layout: NativeChartLayout
  ) {
    let available = horizontal ? rect.width : rect.height
    let spacing = horizontal ? layout.bottomLabelWidth : layout.lineHeight + 10 * layout.scale
    let count = max(1, min(4, Int(available / max(1, spacing))))
    for i in 0...count {
      let fraction = Double(i) / Double(count)
      var line = Path()
      if horizontal {
        let x = rect.minX + rect.width * fraction
        line.move(to: CGPoint(x: x, y: rect.minY))
        line.addLine(to: CGPoint(x: x, y: rect.maxY))
        if layout.showsBottomLabels {
          text(
            number(low + (high - low) * fraction), at: CGPoint(x: x, y: rect.maxY + layout.tickOffset),
            canvas: &canvas, anchor: i == 0 ? .leading : i == count ? .trailing : .center,
            maxWidth: rect.width / CGFloat(count))
        }
      } else {
        let y = rect.maxY - rect.height * fraction
        line.move(to: CGPoint(x: rect.minX, y: y))
        line.addLine(to: CGPoint(x: rect.maxX, y: y))
        text(
          number(low + (high - low) * fraction), at: CGPoint(x: rect.minX - 6, y: y),
          canvas: &canvas, anchor: .trailing, maxWidth: max(1, rect.minX - 6))
      }
      let isZero = abs(low + (high - low) * fraction) < 0.000_001
      canvas.stroke(
        line, with: .color(isZero ? axisColorValue.opacity(0.35) : gridColorValue),
        lineWidth: isZero ? 0.75 : 0.5)
    }
  }
  private func cartesian(_ canvas: inout GraphicsContext, _ size: CGSize) {
    guard !data.labels.isEmpty, !data.series.isEmpty else { return }
    let layout = self.layout(size)
    let rect = layout.rect
    let count = data.labels.count
    let seriesCount = data.series.count
    let horizontal = name == "HorizontalBarChart"
    let bars = name == "BarChart" || horizontal
    let stacked = bars && variant == "stacked"
    let (low, high) = domain
    grid(&canvas, rect: rect, low: low, high: high, horizontal: horizontal, layout: layout)
    let numeric = { (v: Double) -> CGFloat in
      let f = CGFloat((v - low) / (high - low))
      return horizontal ? rect.minX + rect.width * f : rect.maxY - rect.height * f
    }
    let pitch = (horizontal ? rect.height : rect.width) / CGFloat(count)
    if horizontal {
      let labelStride = max(1, Int(ceil(CGFloat(count) / max(1,
        rect.height / (layout.lineHeight + 12 * layout.scale)))))
      for i in 0..<count where i % labelStride == 0 {
        text(
          data.labels[i], at: CGPoint(x: rect.minX - 6, y: rect.minY + pitch * (CGFloat(i) + 0.5)),
          canvas: &canvas, anchor: .trailing, maxWidth: max(1, rect.minX - 6))
      }
    } else {
      for label in layout.categoryLabels(count: count) {
        text(data.labels[label.index], at: CGPoint(x: label.x, y: rect.maxY + layout.tickOffset),
          canvas: &canvas, anchor: label.anchor, maxWidth: label.width)
      }
    }
    if let inspected, (0..<count).contains(inspected) {
      let band = horizontal
        ? CGRect(x: rect.minX, y: rect.minY + pitch * CGFloat(inspected), width: rect.width, height: pitch)
        : CGRect(x: rect.minX + pitch * CGFloat(inspected), y: rect.minY, width: pitch, height: rect.height)
      canvas.fill(Path(roundedRect: band, cornerRadius: 4), with: .color(axisColorValue.opacity(0.06)))
    }
    if bars {
      for i in 0..<count {
        var positive = 0.0
        var negative = 0.0
        for s in 0..<seriesCount {
          let value = data.value(s, i)
          let base = stacked ? (value >= 0 ? positive : negative) : 0
          let a = numeric(base)
          let b = numeric(base + value)
          let breadth = pitch * 0.75 / CGFloat(stacked ? 1 : seriesCount)
          let category =
            (horizontal ? rect.minY : rect.minX) + pitch * (CGFloat(i) + 0.125)
            + (stacked ? 0 : CGFloat(s) * breadth)
          let bar =
            horizontal
            ? CGRect(x: min(a, b), y: category, width: abs(b - a), height: breadth)
            : CGRect(x: category, y: min(a, b), width: breadth, height: abs(b - a))
          let gap: CGFloat = stacked ? 0 : min(2, breadth * 0.12)
          let insetBar = bar.insetBy(dx: horizontal ? 0 : gap, dy: horizontal ? gap : 0)
          let radius = stacked ? 0 : min(4, breadth * 0.2)
          canvas.fill(
            Path(roundedRect: insetBar, cornerRadius: radius),
            with: .color(color(s).opacity(inspected == nil || inspected == i ? 1 : 0.4)))
          if value >= 0 { positive += value } else { negative += value }
        }
      }
    } else {
      for s in 0..<seriesCount {
        let points = (0..<count).map {
          CGPoint(x: rect.minX + pitch * (CGFloat($0) + 0.5), y: numeric(data.value(s, $0)))
        }
        let line = linePath(points)
        if name == "AreaChart", let first = points.first, let last = points.last {
          var area = line
          area.addLine(to: CGPoint(x: last.x, y: numeric(0)))
          area.addLine(to: CGPoint(x: first.x, y: numeric(0)))
          area.closeSubpath()
          canvas.fill(area, with: .color(color(s).opacity(0.12)))
        }
        canvas.stroke(
          line, with: .color(color(s)),
          style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        if let inspected, points.indices.contains(inspected) {
          let point = points[inspected]
          let marker = Path(ellipseIn: CGRect(x: point.x - 4, y: point.y - 4, width: 8, height: 8))
          canvas.fill(marker, with: .color(canvasColor))
          canvas.stroke(marker, with: .color(color(s)), lineWidth: 2)
        } else if count == 1, let point = points.first {
          canvas.fill(
            Path(ellipseIn: CGRect(x: point.x - 3, y: point.y - 3, width: 6, height: 6)),
            with: .color(color(s)))
        }
      }
    }
  }
  private func linePath(_ points: [CGPoint]) -> Path {
    var line = Path()
    guard let first = points.first else { return line }
    line.move(to: first)
    for i in 1..<points.count {
      let previous = points[i - 1]
      let current = points[i]
      if variant == "step" {
        let middle = (previous.x + current.x) / 2
        line.addLine(to: CGPoint(x: middle, y: previous.y))
        line.addLine(to: CGPoint(x: middle, y: current.y))
        line.addLine(to: current)
      } else if variant == "natural" {
        let before = points[max(0, i - 2)]
        let after = points[min(points.count - 1, i + 1)]
        line.addCurve(
          to: current,
          control1: CGPoint(
            x: previous.x + (current.x - before.x) / 6, y: previous.y + (current.y - before.y) / 6),
          control2: CGPoint(
            x: current.x - (after.x - previous.x) / 6, y: current.y - (after.y - previous.y) / 6))
      } else {
        line.addLine(to: current)
      }
    }
    return line
  }
  private func circular(_ canvas: inout GraphicsContext, _ size: CGSize) {
    let values = data.labels.indices.map {
      max(0, data.slices.indices.contains($0) ? data.slices[$0] : 0)
    }
    let total = values.reduce(0, +)
    guard total > 0 else { return }
    if name == "SingleStackedBarChart" {
      var barCanvas = canvas
      barCanvas.clip(to: Path(roundedRect:
        CGRect(x: 4, y: size.height / 2 - 14, width: max(0, size.width - 8), height: 28),
        cornerRadius: 6))
      var x: CGFloat = 4
      for i in values.indices {
        let width = (size.width - 8) * values[i] / total
        barCanvas.fill(
          Path(CGRect(x: x, y: size.height / 2 - 14, width: width, height: 28)),
          with: .color(color(i)))
        x += width
      }
      return
    }
    let center = CGPoint(x: size.width / 2, y: semi ? size.height * 0.82 : size.height / 2)
    let radius = max(1, min(size.width / 2 - 12, semi ? size.height * 0.78 : size.height / 2 - 12))
    var start = semi ? -180.0 : -90.0
    let sweep = semi ? 180.0 : 360.0
    for i in values.indices {
      if name == "RadialChart" {
        let thickness = radius / CGFloat(max(1, values.count)) * 0.75
        let r = radius - CGFloat(i) * radius / CGFloat(max(1, values.count)) - thickness / 2
        var track = Path()
        track.addArc(
          center: center, radius: r, startAngle: .degrees(-90), endAngle: .degrees(270),
          clockwise: false)
        canvas.stroke(track, with: .color(gridColorValue), lineWidth: thickness)
        var arc = Path()
        arc.addArc(
          center: center, radius: r, startAngle: .degrees(-90),
          endAngle: .degrees(-90 + 360 * values[i] / (values.max() ?? 1)), clockwise: false)
        canvas.stroke(
          arc, with: .color(color(i)), style: StrokeStyle(lineWidth: thickness, lineCap: .round))
      } else {
        let end = start + sweep * values[i] / total
        var sector = Path()
        if variant == "donut" {
          let inner = radius * 0.6
          sector.addArc(
            center: center, radius: radius, startAngle: .degrees(start), endAngle: .degrees(end),
            clockwise: false)
          sector.addArc(
            center: center, radius: inner, startAngle: .degrees(end), endAngle: .degrees(start),
            clockwise: true)
        } else {
          sector.move(to: center)
          sector.addArc(
            center: center, radius: radius, startAngle: .degrees(start), endAngle: .degrees(end),
            clockwise: false)
        }
        sector.closeSubpath()
        canvas.fill(sector, with: .color(color(i)))
        canvas.stroke(sector, with: .color(canvasColor), lineWidth: 1.5)
        start = end
      }
    }
  }
  private func radar(_ canvas: inout GraphicsContext, _ size: CGSize) {
    guard !data.labels.isEmpty, !data.series.isEmpty else { return }
    let center = CGPoint(x: size.width / 2, y: size.height / 2)
    let radius = max(1, min(size.width / 2 - 48, size.height / 2 - 24))
    let high = max(1, data.series.flatMap(\.values).max() ?? 1)
    let count = data.labels.count
    let point = { (i: Int, value: Double) -> CGPoint in
      let angle = Double(i) * 2 * Double.pi / Double(count) - Double.pi / 2
      let r = radius * max(0, value) / high
      return CGPoint(x: center.x + cos(angle) * r, y: center.y + sin(angle) * r)
    }
    for step in 1...4 {
      var polygon = Path()
      for i in 0..<count {
        let p = point(i, high * Double(step) / 4)
        if i == 0 { polygon.move(to: p) } else { polygon.addLine(to: p) }
      }
      polygon.closeSubpath()
      canvas.stroke(polygon, with: .color(gridColorValue), lineWidth: 0.5)
    }
    for i in 0..<count {
      var axis = Path()
      axis.move(to: center)
      axis.addLine(to: point(i, high))
      canvas.stroke(axis, with: .color(gridColorValue), lineWidth: 0.5)
      text(data.labels[i], at: point(i, high * 1.12), canvas: &canvas)
    }
    for s in data.series.indices {
      var polygon = Path()
      for i in 0..<count {
        let p = point(i, data.value(s, i))
        if i == 0 { polygon.move(to: p) } else { polygon.addLine(to: p) }
      }
      polygon.closeSubpath()
      canvas.fill(polygon, with: .color(color(s).opacity(0.15)))
      canvas.stroke(polygon, with: .color(color(s)), lineWidth: 2)
    }
  }
  private func scatter(_ canvas: inout GraphicsContext, _ size: CGSize) {
    let layout = self.layout(size)
    let projection = NativeScatterProjection(data: data, layout: layout)
    guard !projection.points.isEmpty else { return }
    let rect = projection.rect
    grid(&canvas, rect: rect, low: projection.yMin, high: projection.yMax, layout: layout)
    let count = max(1, min(4, Int(rect.width / layout.bottomLabelWidth)))
    for i in 0...count where layout.showsBottomLabels {
      let fraction = Double(i) / Double(count)
      text(
        number(projection.xMin + (projection.xMax - projection.xMin) * fraction),
        at: CGPoint(x: rect.minX + rect.width * fraction, y: rect.maxY + layout.tickOffset),
        canvas: &canvas, anchor: i == 0 ? .leading : i == count ? .trailing : .center,
        maxWidth: rect.width / CGFloat(count))
    }
    for point in projection.points {
      let selected = inspected == point.rowIndex
      let opacity = inspected == nil || selected ? 0.85 : 0.35
      let circle = Path(ellipseIn: CGRect(
        x: point.position.x - point.radius, y: point.position.y - point.radius,
        width: point.radius * 2, height: point.radius * 2))
      canvas.fill(circle, with: .color(color(point.seriesIndex).opacity(opacity)))
      if selected {
        let ring = Path(ellipseIn: CGRect(
          x: point.position.x - point.radius - 3, y: point.position.y - point.radius - 3,
          width: point.radius * 2 + 6, height: point.radius * 2 + 6))
        canvas.stroke(ring, with: .color(color(point.seriesIndex)), lineWidth: 1.5)
      }
    }
  }
}

/// A single geometry source for scatter rendering and pointer inspection.
/// Row indices intentionally match accessibilityRows, independent of labels.
struct NativeScatterProjection {
  struct Point {
    let rowIndex: Int
    let seriesIndex: Int
    let position: CGPoint
    let radius: CGFloat
  }
  let rect: CGRect
  let xMin: Double
  let xMax: Double
  let yMin: Double
  let yMax: Double
  let points: [Point]

  init(data: NativeChartData, size: CGSize) {
    self.init(data: data, layout: NativeChartLayout(size: size))
  }

  init(data: NativeChartData, layout: NativeChartLayout) {
    let rawPoints = data.scatter.flatMap(\.points)
    let rect = layout.rect
    let xMin = min(0, rawPoints.map(\.x).min() ?? 0)
    let yMin = min(0, rawPoints.map(\.y).min() ?? 0)
    let xMax = max(xMin + 1, rawPoints.map(\.x).max() ?? 1)
    let yMax = max(yMin + 1, rawPoints.map(\.y).max() ?? 1)
    let maxZ = max(1, rawPoints.compactMap(\.z).max() ?? 1)
    self.rect = rect
    self.xMin = xMin; self.xMax = xMax
    self.yMin = yMin; self.yMax = yMax
    var projected: [Point] = []
    for (seriesIndex, series) in data.scatter.enumerated() {
      for point in series.points {
        projected.append(Point(
          rowIndex: projected.count, seriesIndex: seriesIndex,
          position: CGPoint(
            x: rect.minX + (point.x - xMin) / (xMax - xMin) * rect.width,
            y: rect.maxY - (point.y - yMin) / (yMax - yMin) * rect.height),
          radius: point.z.map { 3 + 9 * sqrt(max(0, $0) / maxZ) } ?? 4))
      }
    }
    points = projected
  }

  func nearestIndex(to location: CGPoint) -> Int? {
    // Edge points remain reachable, while axes and empty plot space do not
    // report a distant observation as if it had been touched.
    guard rect.insetBy(dx: -16, dy: -16).contains(location) else { return nil }
    var result: (index: Int, distance: CGFloat)?
    for point in points {
      let distance = hypot(location.x - point.position.x, location.y - point.position.y)
      guard distance <= max(22, point.radius + 8) else { continue }
      if let result, distance >= result.distance { continue }
      result = (point.rowIndex, distance)
    }
    return result?.index
  }
}
