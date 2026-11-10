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
    default: return []
    }
  }
  static func ready(_ source: NativeSourceReadiness, fields: [String]) -> Bool {
    fields.allSatisfy { source[$0].complete }
  }
  static func collectionShapeReady(_ source: NativeSourceReadiness, count: Int) -> Bool {
    source.complete || (source.closed && source.expectedCount == count)
  }
}

/// Preserve a readable leading text prefix while its enclosing layout is still
/// unknown. Never skip an unresolved/complex item to expose later content first.
struct NativeDeferredLayout: View {
  let context: OpenUIComponentContext
  private func readable(_ value: Value, depth: Int = 0) -> Bool {
    guard depth < 128 else { return false }
    guard case .element(let element) = value else { return false }
    if NativePresentationProxy.textNames.contains(element.typeName) || element.typeName == "MarkDownRenderer" { return true }
    if element.typeName == "Stack", let children = PropValue.value(element, "children"), case .array(let values) = children {
      return !values.isEmpty && values.allSatisfy { readable($0, depth: depth + 1) }
    }
    return false
  }
  var body: some View {
    let children = context.presentationChildren()
    let source = context.element.sourceReadiness["children"]
    let hasOmittedSlots = source.valueIndices?.contains(where: { $0 == nil }) == true
    let prefix = hasOmittedSlots ? [] : Array(children.prefix { readable($0.value) })
    VStack(alignment: .leading, spacing: context.theme.spaceM) {
      ForEach(prefix) { child in context.render(child.value) }
      if prefix.isEmpty || prefix.count < children.count {
        NativePendingContent(loading: !context.hasDataFailure && (context.isStreaming || context.hasPendingData),
          terminalMessage: context.hasDataFailure ? "Content unavailable" : "Content is incomplete")
      }
    }.frame(maxWidth: .infinity, alignment: .leading)
  }
}

private struct NativeMediaWidthReadyKey: EnvironmentKey { static let defaultValue = true }
extension EnvironmentValues {
  var openUIMediaWidthReady: Bool {
    get { self[NativeMediaWidthReadyKey.self] }
    set { self[NativeMediaWidthReadyKey.self] = newValue }
  }
}

/// Compact local feedback. It has no invented content geometry and never
/// replaces an already populated chart during a data refresh.
struct NativePendingContent: View {
  let loading: Bool
  var message: LocalizedStringKey = "Loading content"
  var terminalMessage: LocalizedStringKey = "Content is incomplete"
  @Environment(\.openUITheme) private var theme
  var body: some View {
    HStack(spacing: theme.spaceS) {
      if loading { NativeDelayedPresentation(active: true) { visible in
        if visible { NativeLoadingIndicator() }
      }.frame(width: theme.textLabelSm.size) }
      Text(loading ? message : terminalMessage, bundle: NativeControlResources.bundle)
        .nativeTextStyle(theme.textStyle(.supporting))
    }
    .padding(.vertical, theme.spaceS)
    .frame(maxWidth: .infinity, alignment: .leading)
    .allowsHitTesting(false)
    .accessibilityElement(children: .combine)
  }
}
