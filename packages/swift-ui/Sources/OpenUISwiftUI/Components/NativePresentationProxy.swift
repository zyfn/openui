import OpenUILang
import SwiftUI

/// Data-free view proxies for opt-in standard renderers. They never enter the
/// Store, parsed root, action evaluator, prompt or serialized Lang document.
enum NativePresentationProxy {
  static let textNames: Set<String> = ["TextContent", "CardHeader", "InlineHeader", "Text", "BoldText", "CodeBlock"]
  static let supportedNames: Set<String> = textNames.union([
    "BarChart", "LineChart", "AreaChart", "HorizontalBarChart", "RadarChart", "PieChart",
    "RadialChart", "SingleStackedBarChart", "ScatterChart", "Table",
    "Image", "ImageBlock", "ImageText", "ImageTextLarge", "Button", "Icon",
  ])
  static func primaryTextField(_ name: String) -> String? {
    switch name {
    case "TextContent": return "text"
    // Both CardHeader fields are optional. A subtitle-only or intentionally
    // empty header is valid and must remain owned by its normal renderer.
    case "CardHeader": return nil
    case "InlineHeader": return "heading"
    case "CodeBlock": return "codeString"
    case "Text", "BoldText": return "value"
    default: return nil
    }
  }

  static func element(_ source: NativeSourceReadiness, registry: ComponentRegistry) -> EvaluatedElement? {
    guard let hint = source.placeholder, registry.supportsPresentationPlaceholder(hint.typeName) else { return nil }
    // Only committed layout scalars are supplied. Required data/actions stay
    // absent, so a proxy cannot fabricate samples, fetch media or be activated.
    let layoutKeys: Set<String> = ["height", "imageSize", "size", "iconSize", "variant", "appearance", "layout", "direction", "gap", "align", "justify", "wrap", "id", "key", "resourceId"]
    let allowed = layoutKeys.union(registry.presentationLayoutFields(hint.typeName))
    let properties = hint.properties.filter { field in
      guard allowed.contains(field.key.displayString) else { return false }
      switch field.value {
      case .string, .boolean, .null: return true
      case .number(let number): return number.isFinite
      default: return false
      }
    }
    let fields = properties.map { ($0.key.displayString, $0.value) }
    let known = Dictionary(properties.keys.map { ($0, NativeSourceReadiness(complete: true, closed: true)) },
      uniquingKeysWith: { _, last in last })
    let readiness = NativeSourceReadiness(complete: false, closed: source.closed,
      children: source.children.merging(known, uniquingKeysWith: { _, committed in committed }),
      queryDependencies: source.queryDependencies, placeholder: hint)
    return EvaluatedElement(typeName: hint.typeName, props: fields, statementId: hint.statementId,
      partial: true, isSourceComplete: false, sourceReadiness: readiness)
  }

  static func children(_ value: Value, source: NativeSourceReadiness, registry: ComponentRegistry) -> [OpenUIRenderChild] {
    OpenUIRenderChild.children(of: expandedValue(value, source: source, registry: registry))
  }

  static func expandedValue(_ value: Value, source: NativeSourceReadiness, registry: ComponentRegistry) -> Value {
    func expanded(_ value: Value, _ source: NativeSourceReadiness, depth: Int = 0) -> Value {
      guard depth < 256 else { return value }
      if case .array(let values) = value {
        if let slots = source.valueIndices, slots.compactMap({ $0 }) == Array(values.indices) {
          return .array(slots.enumerated().map { position, index in
            if let index { return expanded(values[index], source[index], depth: depth + 1) }
            return source.pendingChildren[position].flatMap { element($0, registry: registry) }.map(Value.element) ?? .null
          })
        }
        guard !source.children.isEmpty else { return value }
        return .array(values.enumerated().map { expanded($0.element, source[$0.offset], depth: depth + 1) })
      }
      if value.isNullish, let proxy = element(source, registry: registry) { return .element(proxy) }
      return value
    }
    return expanded(value, source)
  }
}

/// Minimum reading space for a known text role, never guessed paragraph counts.
struct NativeTextPlaceholder: View {
  let context: OpenUIComponentContext
  @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1
  private var style: NativeRichTextStyle {
    switch context.element.typeName {
    case "TextContent": return .textContent(context.presentationString("size"), theme: context.theme)
    case "CardHeader", "InlineHeader": return context.theme.objectTitleStyle().richText()
    case "CodeBlock": return .init(font: context.theme.textCodeDefault, role: .code)
    default: return context.theme.inlineTextStyle(context.presentationString("size"),
      emphasized: context.element.typeName == "BoldText", numeric: context.string("variant") == "number")
    }
  }
  var body: some View {
    let loading = !context.hasDataFailure && (context.isStreaming || context.hasPendingData)
    let height = (style.font ?? context.theme.textBodyDefault).resolved(for: style.role).measuredLineHeight(scale: scale)
    Group {
      if loading {
        NativePendingContent(loading: true)
      } else {
        Text("Content unavailable", bundle: NativeControlResources.bundle)
          .nativeTextStyle(context.theme.textStyle(.supporting)).frame(minHeight: height)
      }
    }
    .frame(idealWidth: context.presentation.minimumTextColumnWidth, maxWidth: .infinity, alignment: .leading)
    .allowsHitTesting(false)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Text(loading ? "Loading data" : "Content unavailable", bundle: NativeControlResources.bundle))
  }
}
