@_spi(RuntimeInspection) import OpenUILang
import SwiftUI

enum NativeChartNumber {
  static func percentage(_ value: Double, total: Double) -> String {
    total == 0 ? "0%" : jsNumberToFixed(value / total * 100, digits: 1) + "%"
  }
  static func tooltip(_ value: Double, locale: Locale) -> String {
    let magnitude = abs(value)
    if magnitude < 100_000 { return jsNumberLocalized(value, locale: locale.identifier) }
    let units = ["", "K", "M", "B", "T"]
    var index = 0, scaled = magnitude
    while scaled >= 1000 && index < units.count - 1 { scaled /= 1000; index += 1 }
    return (value < 0 ? "-" : "") + jsNumberString(floor(scaled * 10) / 10) + units[index]
  }
  static func tick(_ value: Double) -> String {
    let magnitude = abs(value)
    for (scale, suffix) in [(1e12, "T"), (1e9, "B"), (1e6, "M"), (1e3, "K")] where magnitude >= scale {
      return jsNumberToFixed(value / scale, digits: magnitude >= 10 * scale ? 0 : 1) + suffix
    }
    return value.truncatingRemainder(dividingBy: 1) != 0
      ? jsNumberToFixed(value, digits: 2) : jsNumberString(value)
  }
}

/// Same last-visible guard as upstream useSeriesVisibility. Hidden keys survive
/// data swaps; only keys present in the current data participate in the guard.
struct NativeChartVisibility {
  private(set) var hidden = Set<OpenUIString>()
  mutating func toggle(_ key: String, current: [String]) {
    let key = OpenUIString(key)
    if hidden.contains(key) { hidden.remove(key); return }
    let hiddenCurrent = current.filter { hidden.contains(OpenUIString($0)) }.count
    guard hiddenCurrent < current.count - 1 else { return }
    hidden.insert(key)
  }
}

struct NativeChartInspection {
  struct Row: Identifiable {
    let id: OpenUIString
    let label: String?
    let value: String
    let colorIndex: Int?
  }
  let title: String
  var colorIndex: Int? = nil
  let rows: [Row]
}

extension NativeChartData {
  func inspection(at index: Int, locale: Locale) -> NativeChartInspection? {
    guard index >= 0 else { return nil }
    func number(_ value: Double) -> String { NativeChartNumber.tooltip(value, locale: locale) }
    func colorIndex(_ index: Int) -> Int {
      colorIndices.indices.contains(index) ? colorIndices[index] : index
    }
    if !scatter.isEmpty {
      var remaining = index
      for (seriesIndex, series) in scatter.enumerated() {
        guard remaining < series.points.count else { remaining -= series.points.count; continue }
        let point = series.points[remaining]
        var rows: [NativeChartInspection.Row] = [
          .init(id: "x", label: "x", value: number(point.x), colorIndex: nil),
          .init(id: "y", label: "y", value: number(point.y), colorIndex: nil),
        ]
        if let z = point.z { rows.append(.init(id: "z", label: "z", value: number(z), colorIndex: nil)) }
        return .init(title: series.name, colorIndex: colorIndex(seriesIndex), rows: rows)
      }
      return nil
    }
    guard labels.indices.contains(index) else { return nil }
    if !series.isEmpty {
      return .init(title: labels[index], rows: series.enumerated().map { seriesIndex, series in
        .init(id: OpenUIString(series.name), label: series.name,
          value: number(value(seriesIndex, index)), colorIndex: colorIndex(seriesIndex))
      })
    }
    return .init(title: labels[index], rows: [
      .init(id: "value", label: nil, value: number(slices.indices.contains(index) ? slices[index] : 0),
        colorIndex: colorIndex(index)),
    ])
  }
  func prepared(for name: String) -> Self {
    var result = self
    if ["PieChart", "RadialChart"].contains(name), !slices.isEmpty {
      let order = labels.indices.sorted {
        let a = slices.indices.contains($0) ? slices[$0] : 0
        let b = slices.indices.contains($1) ? slices[$1] : 0
        return a == b ? $0 < $1 : a > b
      }
      result.labels = order.map { labels[$0] }
      result.slices = order.map { slices.indices.contains($0) ? slices[$0] : 0 }
    }
    result.colorIndices = Array(result.legendNames(for: name).indices)
    return result
  }

  func legendNames(for name: String) -> [String] {
    if name == "ScatterChart" { return scatter.map(\.name) }
    return ["PieChart", "RadialChart", "SingleStackedBarChart"].contains(name) ? labels : series.map(\.name)
  }

  func excluding(_ hidden: Set<OpenUIString>, for name: String) -> Self {
    var result = self
    let keys = legendNames(for: name)
    let indices = keys.indices.filter { !hidden.contains(OpenUIString(keys[$0])) }
    result.colorIndices = indices.map { colorIndices.indices.contains($0) ? colorIndices[$0] : $0 }
    if name == "ScatterChart" { result.scatter = indices.map { scatter[$0] } }
    else if !["PieChart", "RadialChart", "SingleStackedBarChart"].contains(name) { result.series = indices.map { series[$0] } }
    else {
      result.labels = indices.map { labels[$0] }
      result.slices = indices.map { slices.indices.contains($0) ? slices[$0] : 0 }
    }
    return result
  }

  func hasContent(for name: String) -> Bool {
    if name == "ScatterChart" { return !scatter.isEmpty }
    if ["PieChart", "RadialChart", "SingleStackedBarChart"].contains(name) {
      return !labels.isEmpty && !slices.isEmpty
    }
    return !labels.isEmpty
  }
}

/// Touch hit testing uses the geometry actually painted, including unequal
/// slices and donut holes, instead of dividing the viewport into equal columns.
enum NativePolarInspection {
  static func index(at point: CGPoint, size: CGSize, values: [Double], name: String,
                    donut: Bool, semi: Bool) -> Int? {
    let values = values.map { max(0, $0) }
    let total = values.reduce(0, +)
    guard total > 0, !values.isEmpty else { return nil }
    var fraction: Double
    if name == "SingleStackedBarChart" {
      let bar = CGRect(x: 4, y: size.height / 2 - 14, width: max(0, size.width - 8), height: 28)
      guard bar.contains(point), bar.width > 0 else { return nil }
      fraction = (point.x - bar.minX) / bar.width
    } else {
      let center = CGPoint(x: size.width / 2, y: semi ? size.height * 0.82 : size.height / 2)
      let radius = max(1, min(size.width / 2 - 12, semi ? size.height * 0.78 : size.height / 2 - 12))
      let dx = point.x - center.x, dy = point.y - center.y
      let distance = hypot(dx, dy)
      guard distance <= radius else { return nil }
      let angle = atan2(dy, dx) * 180 / .pi
      if name == "RadialChart" {
        let slot = radius / CGFloat(values.count)
        let thickness = slot * 0.75
        let turn = (angle + 90 + 360).truncatingRemainder(dividingBy: 360) / 360
        for index in values.indices {
          let r = radius - CGFloat(index) * slot - thickness / 2
          if abs(distance - r) <= thickness / 2, turn <= values[index] / (values.max() ?? 1) { return index }
        }
        return nil
      }
      if donut && distance < radius * 0.6 { return nil }
      let start = semi ? -180.0 : -90.0
      let sweep = semi ? 180.0 : 360.0
      let delta = (angle - start + 360).truncatingRemainder(dividingBy: 360)
      guard delta <= sweep else { return nil }
      fraction = delta / sweep
    }
    var boundary = 0.0
    for index in values.indices {
      boundary += values[index] / total
      if values[index] > 0, fraction <= boundary { return index }
    }
    return nil
  }
}
