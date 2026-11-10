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
      guard let sources = entries(rows, ready["datasets"], expectedType: "ScatterSeries") else { return nil }
      var result = NativeChartData()
      result.isProgressive = true
      for source in sources {
        let rowReady = source.readiness
        guard rowReady["name"].complete, let name = source.string("name") else { break }
        let points = NativeValue.array(NativeValue.prop(source.value ?? .null, "points"))
        var known: [NativeChartData.Point] = []
        if aligned(points, rowReady["points"]) {
          for (i, point) in points.enumerated() {
            guard rowReady["points"][i].complete,
              let x = NativeValue.number(point, "x"), let y = NativeValue.number(point, "y") else { break }
            known.append(.init(x: x, y: y, z: NativeValue.number(point, "z")))
          }
        }
        result.scatter.append(.init(name: name, points: known))
      }
      return result.scatter.isEmpty ? nil : result.prepared(for: name)
    }
    guard ["BarChart", "HorizontalBarChart", "LineChart", "AreaChart"].contains(name),
      ready["labels"].complete else { return nil }
    let rows = NativeValue.array(context.value("series"))
    // Matrix rows are atomic: no partially received cell may become a zero.
    if case .array = rows.first {
      guard aligned(rows, ready["series"]) else { return nil }
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
    guard let sources = entries(rows, ready["series"], expectedType: "Series") else { return nil }
    var pairs: [ObjectField] = []
    for source in sources {
      let rowReady = source.readiness
      guard rowReady["category"].complete, let category = source.string("category") else { break }
      let values = NativeValue.array(NativeValue.prop(source.value ?? .null, "values"))
      var count = 0
      if aligned(values, rowReady["values"]) {
        for i in values.indices {
          guard rowReady["values"][i].complete else { break }
          count += 1
        }
      }
      let key = OpenUIString(category)
      // A later duplicate series replaces values only after that replacement
      // is complete; it must not erase an already readable series with zeros.
      if pairs.contains(where: { $0.key == key }), !rowReady["values"].complete { continue }
      pairs.append(.init(key: key, value: .array(Array(values.prefix(count)))))
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
  private struct Entry {
    let value: Value?
    let readiness: NativeSourceReadiness
    func string(_ key: String) -> String? {
      if let value { return NativeValue.string(value, key) }
      if case .string(let text) = readiness.placeholder?.properties[OpenUIString(key)] { return text.displayString }
      return nil
    }
  }
  private static func entries(_ values: [Value], _ source: NativeSourceReadiness, expectedType: String) -> [Entry]? {
    if let slots = source.valueIndices, slots.compactMap({ $0 }) == Array(values.indices) {
      return slots.enumerated().map { position, index in
        if let index { return Entry(value: values[index], readiness: source[index]) }
        let pending = source.pendingChildren[position]
        return Entry(value: nil, readiness: pending?.placeholder?.typeName == expectedType
          ? pending! : .init(complete: false, closed: false))
      }
    }
    guard aligned(values, source) else { return nil }
    return values.indices.map { Entry(value: values[$0], readiness: source[$0]) }
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
