import OpenUILang
import SwiftUI

/// Presentation dependencies of standard layout families. These are existing
/// parameters, not additional Lang fields or a policy inferred from content.
enum NativeLayoutContract {
  static func fields(for name: String) -> [String] {
    switch name {
    case "Stack": return ["direction", "gap", "align", "justify", "wrap"]
    case "Card": return ["variant", "direction", "gap", "align", "justify", "wrap"]
    case "Buttons": return ["direction"]
    case "IconText": return ["layout", "iconSize", "iconVariant"]
    case "ImageText": return ["layout", "imageSize"]
    case "CompositeCardBlock", "VisualCardBlock", "ContextCardBlock", "OverviewCardBlock", "SnippetCardBlock": return ["layout", "responsive", "gap"]
    case "Carousel": return ["variant"]
    case "LineChart", "BarChart", "HorizontalBarChart", "AreaChart", "ScatterChart", "RadarChart",
         "PieChart", "RadialChart", "SingleStackedBarChart":
      return ["height", "variant", "appearance", "xLabel", "yLabel"]
    default: return []
    }
  }
  static func ready(_ source: NativeSourceReadiness, fields: [String]) -> Bool {
    fields.allSatisfy { source[$0].complete }
  }
  static func collectionShapeReady(_ source: NativeSourceReadiness, count: Int) -> Bool {
    source.complete || (source.closed && source.expectedCount.map { $0 >= count } == true)
  }

  /// Every contributor to a row must be known before exposing fluid media.
  /// Native Card has a copy-independent width basis, so its text can continue
  /// streaming without holding back already allocated image regions.
  static func rowWidthReady(_ value: Value, source: NativeSourceReadiness, registry: ComponentRegistry) -> Bool {
    switch value {
    case .array(let values):
      guard source.complete || source.closed else { return false }
      guard source.valueIndices?.contains(where: { $0 == nil }) != true else { return false }
      if let count = source.expectedCount, count != values.count { return false }
      return values.enumerated().allSatisfy { rowWidthReady($0.element, source: source[$0.offset], registry: registry) }
    case .element(let element):
      let fields = registry.presentationLayoutFields(element.typeName)
      if element.typeName == "Card", !fields.isEmpty {
        return ready(element.sourceReadiness, fields: fields)
      }
      return element.isSourceComplete
    default: return source.complete
    }
  }
}

/// Preserve a readable leading text prefix while its enclosing layout is still
/// unknown. Never skip an unresolved/complex item to expose later content first.
extension NativeLayoutContract {
  static func readingPrefix(_ value: Value, depth: Int = 0) -> (value: Value, blocked: Bool) {
    guard depth < 128 else { return (.null, true) }
    switch value {
    case .array(let values):
      var prefix: [Value] = []
      for child in values {
        let next = readingPrefix(child, depth: depth + 1)
        prefix.append(next.value)
        if next.blocked { return (.array(prefix), true) }
      }
      return (.array(prefix), false)
    case .element(let element):
      // Nested containers inherit the unresolved ancestor state and apply this
      // same prefix rule without discarding their already mounted text.
      if NativePresentationProxy.textNames.contains(element.typeName)
          || ["MarkDownRenderer", "Stack", "Card"].contains(element.typeName) { return (value, false) }
      return (.null, true)
    case .string, .number, .boolean: return (value, false)
    default: return (.null, true)
    }
  }
}

private struct NativeMediaWidthReadyKey: EnvironmentKey { static let defaultValue = true }
private struct NativeAncestorLayoutReadyKey: EnvironmentKey { static let defaultValue = true }
extension EnvironmentValues {
  var openUIAncestorLayoutReady: Bool {
    get { self[NativeAncestorLayoutReadyKey.self] }
    set { self[NativeAncestorLayoutReadyKey.self] = newValue }
  }
  var openUIMediaWidthReady: Bool {
    get { self[NativeMediaWidthReadyKey.self] }
    set { self[NativeMediaWidthReadyKey.self] = newValue }
  }
}

/// Compact local feedback. It has no invented content geometry and never
/// replaces an already populated chart during a data refresh.
struct NativePendingContent: View {
  let loading: Bool
  /// Accessibility-only resource state; the renderer does not narrate an
  /// Agent's business activity while source/layout information is arriving.
  var message: LocalizedStringKey = "Loading"
  var terminalMessage: LocalizedStringKey = "Content is incomplete"
  @Environment(\.openUITheme) private var theme
  @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1
  var body: some View {
    HStack(spacing: theme.spaceS) {
      if loading {
        NativeDelayedPresentation(active: true) { visible in
          if visible { NativeLoadingIndicator() }
        }.frame(width: theme.textLabelSm.size * scale,
          height: theme.textStyle(.supporting).font.measuredLineHeight(scale: scale))
      } else {
        Text(terminalMessage, bundle: NativeControlResources.bundle)
          .nativeTextStyle(theme.textStyle(.supporting))
      }
    }
    .padding(.vertical, theme.spaceS)
    .frame(maxWidth: .infinity, alignment: .leading)
    .allowsHitTesting(false)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Text(loading ? message : terminalMessage, bundle: NativeControlResources.bundle))
  }
}
