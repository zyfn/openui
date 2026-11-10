import OpenUILang

extension NativeChartStreamingPresentation {
  /// Only completed literal/data boundaries become samples. Expressions whose
  /// boundaries cannot be attributed safely keep the previous presentation.
  static func staged(context: OpenUIComponentContext, current prepared: NativeChartData? = nil) -> NativeChartData? {
    let name = context.element.typeName
    let ready = context.element.sourceReadiness
    let current = prepared ?? NativeChartData(context: context).prepared(for: name)
    if context.element.isSourceComplete { return current }
    if ["PieChart", "RadialChart", "SingleStackedBarChart", "RadarChart"].contains(name) {
      let fields = name == "RadarChart" ? ["labels", "series"] : ["labels", "values"]
      guard ready.closed, fields.allSatisfy({ ready[$0].complete }) else { return nil }
      return current
    }
    if name == "ScatterChart" {
      let rows = NativeValue.array(context.value("datasets"))
      guard aligned(rows, ready["datasets"]) else { return nil }
      var result = NativeChartData()
      result.isProgressive = true
      for (index, row) in rows.enumerated() {
        let rowReady = metadata(row, fallback: ready["datasets"][index])
        guard rowReady["name"].complete else { break }
        let points = NativeValue.array(NativeValue.prop(row, "points"))
        var known: [NativeChartData.Point] = []
        if aligned(points, rowReady["points"]) {
          for (i, point) in points.enumerated() {
            guard metadata(point, fallback: rowReady["points"][i]).complete,
              let x = NativeValue.number(point, "x"), let y = NativeValue.number(point, "y") else { break }
            known.append(.init(x: x, y: y, z: NativeValue.number(point, "z")))
          }
        }
        result.scatter.append(.init(name: NativeValue.string(row, "name") ?? "", points: known))
      }
      return result.scatter.isEmpty ? nil : result.prepared(for: name)
    }
    guard ["BarChart", "HorizontalBarChart", "LineChart", "AreaChart"].contains(name),
      ready["labels"].complete else { return nil }
    let rows = NativeValue.array(context.value("series"))
    guard aligned(rows, ready["series"]) else { return nil }
    // Matrix rows are atomic: no partially received cell may become a zero.
    if case .array = rows.first {
      var count = 0
      for i in rows.indices {
        guard ready["series"][i].complete else { break }
        count += 1
      }
      var result = current
      result.labels = Array(result.labels.prefix(count))
      result.series = result.series.map { .init(name: $0.name, values: Array($0.values.prefix(count))) }
      result.isProgressive = true
      return result
    }
    var pairs: [ObjectField] = []
    for (index, row) in rows.enumerated() {
      let rowReady = metadata(row, fallback: ready["series"][index])
      guard rowReady["category"].complete else { break }
      let values = NativeValue.array(NativeValue.prop(row, "values"))
      var count = 0
      if aligned(values, rowReady["values"]) {
        for i in values.indices {
          guard rowReady["values"][i].complete else { break }
          count += 1
        }
      }
      pairs.append(.init(key: NativeValue.string(row, "category") ?? "", value: .array(Array(values.prefix(count)))))
    }
    var result = current
    let keyed = OpenUIObject(pairs)
    let colors = NativeChartData.sourceColorIndices(pairs.map(\.key))
    result.colorIndices = keyed.map { colors[$0.key] ?? 0 }
    result.series = keyed.map {
      .init(name: $0.key.displayString, values: NativeChartData.numbers($0.value))
    }
    result.isProgressive = true
    return result.series.isEmpty ? nil : result.prepared(for: name)
  }

  private static func aligned(_ values: [Value], _ source: NativeSourceReadiness) -> Bool {
    source.complete || source.expectedCount == values.count
  }
  private static func metadata(_ value: Value, fallback: NativeSourceReadiness) -> NativeSourceReadiness {
    // The parent's path owns the boundary. Reused element objects can occur
    // through multiple references with different source completion states.
    return fallback
  }
}

/// One immutable evaluated element owns one data projection. Axis, legend,
/// Canvas and accessibility reads reuse it during the same render pass.
final class NativeChartPresentationCache {
  private var element: EvaluatedElement?
  private var cached: (current: NativeChartData, staged: NativeChartData?) = (NativeChartData(), nil)
  func values(_ context: OpenUIComponentContext) -> (current: NativeChartData, staged: NativeChartData?) {
    if element !== context.element {
      let current = NativeChartData(context: context).prepared(for: context.element.typeName)
      cached = (current, NativeChartStreamingPresentation.staged(context: context, current: current))
      element = context.element
    }
    return cached
  }
}
