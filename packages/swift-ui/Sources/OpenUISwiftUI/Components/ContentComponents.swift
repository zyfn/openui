import OpenUILang
import SwiftUI


struct NativeHeading: View {
  let context: OpenUIComponentContext
  let compact: Bool
  var body: some View {
    VStack(alignment: .leading, spacing: context.theme.componentStyle.titleDetailGap) {
      if let title = context.string(compact ? "heading" : "title") {
        Text(title).nativeTextStyle(context.theme.objectTitleStyle()).accessibilityAddTraits(
          .isHeader)
      }
      if let detail = context.string(compact ? "description" : "subtitle") {
        Text(detail).nativeTextStyle(context.theme.textStyle(.supporting))
      }
    }.fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading)
  }
}

struct NativeMarkdown: View {
  let context: OpenUIComponentContext
  var body: some View {
    let surface = NativeContentSurface(context.string("variant"), fallback: .clear)
    NativeMarkdownText(text: context.string("textMarkdown") ?? "")
      .padding(
        context.string("variant") == "clear" || context.string("variant") == nil
          ? 0 : context.theme.spaceM
      )
      .background(
        surface.fill(context.theme),
        in: RoundedRectangle(cornerRadius: context.theme.radiusM))
      .overlay {
        RoundedRectangle(cornerRadius: context.theme.radiusM)
          .strokeBorder(surface.bordered
            ? context.presentation.resolvedCardBorderColor(with: context.theme) : .clear,
            lineWidth: context.presentation.borderWidth)
          .allowsHitTesting(false)
      }
  }
}

private func semanticColor(_ variant: String?, theme: OpenUIThemeValues) -> Color {
  switch variant {
  case "danger", "error": return theme.textDangerPrimary
  case "success": return theme.textSuccessPrimary
  case "warning": return theme.textAlertPrimary
  case "info": return theme.textInfoPrimary
  default: return theme.textNeutralSecondary
  }
}

struct NativeCallout: View {
  let context: OpenUIComponentContext
  let reactive: Bool
  @EnvironmentObject private var state: OpenUIState
  private var binding: Binding<Value>? { reactive ? context.binding("visible") : nil }
  private var visible: Bool {
    binding.map { $0.wrappedValue == .boolean(true) || $0.wrappedValue == .string("true") } ?? true
  }
  private var statusIcon: String? {
    switch context.string("variant") {
    case "success": return "checkmark.circle"
    case "warning": return "exclamationmark.circle"
    case "error", "danger": return "xmark.circle"
    default: return nil
    }
  }
  private var hasCopy: Bool {
    [context.string("title"), context.string("description")].contains {
      !($0 ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
  }
  var body: some View {
    Group {
      if visible && hasCopy {
        HStack(alignment: .firstTextBaseline, spacing: context.theme.spaceM) {
          if let statusIcon {
            Image(systemName: statusIcon)
              .openUIFont(context.theme.textLabelDefaultHeavy, role: .control)
              .foregroundStyle(semanticColor(context.string("variant"), theme: context.theme))
              .accessibilityHidden(true)
          }
          VStack(alignment: .leading, spacing: context.theme.componentStyle.titleDetailGap) {
            if let title = context.string("title"), !title.isEmpty {
              Text(title).openUIFont(context.theme.textBodyDefaultHeavy, role: .title)
            }
            if let detail = context.string("description"), !detail.isEmpty {
              NativeMarkdownText(text: detail, style: .init(font: context.theme.textBodyDefault,
                color: context.theme.textNeutralPrimary))
            }
          }
        }
        .padding(.leading, statusIcon == nil ? context.theme.spaceML : 0)
        .padding(.vertical, context.theme.spaceS)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(alignment: .leading) {
          if statusIcon == nil {
            RoundedRectangle(cornerRadius: context.theme.radius3xs, style: .continuous)
              .fill(context.theme.borderDefault).frame(width: 3)
              .padding(.vertical, context.theme.space2xs).accessibilityHidden(true)
          }
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(Text(statusLabel, bundle: NativeControlResources.bundle))
      }
    }.task(id: "\(state.sourceRevision):\(visible):\(context.canInteract)") {
      guard visible, context.canInteract, binding != nil else { return }
      do { try await Task.sleep(nanoseconds: 3_000_000_000) } catch { return }
      guard !Task.isCancelled else { return }
      binding?.wrappedValue = .boolean(false)
    }
  }
  private var statusLabel: LocalizedStringKey {
    switch context.string("variant") {
    case "success": return "Success"
    case "warning": return "Warning"
    case "error", "danger": return "Error"
    default: return "Information"
    }
  }
}

struct NativeImageBlock: View {
  let context: OpenUIComponentContext
  var body: some View {
    NativeRemoteImage(src: context.string("src"), alt: context.string("alt") ?? "",
      layout: .aspect(context.presentation.coverAspectRatio))
      .clipShape(RoundedRectangle(cornerRadius: context.theme.radiusM, style: .continuous))
  }
}

enum NativeValue {
  static func string(_ value: Value?) -> String {
    if case .string(let text) = value { return text.displayString }
    return ""
  }
  static func prop(_ value: Value?, _ key: String) -> Value? {
    switch value {
    case .element(let e): return PropValue.value(e, key)
    case .object(let o): return o[OpenUIString(key)]
    default: return nil
    }
  }
  static func string(_ value: Value?, _ key: String) -> String? {
    guard case .string(let text) = prop(value, key) else { return nil }
    return text.displayString
  }
  static func number(_ value: Value?, _ key: String) -> Double? {
    guard case .number(let n) = prop(value, key), n.isFinite else { return nil }
    return n
  }
  static func array(_ value: Value?) -> [Value] {
    if case .array(let list) = value { return list.values }
    return []
  }
}

/// The upstream TextBlock family renders inline Markdown. Keep this native
/// presentation adapter shared; it does not interpret or rewrite OpenUI Lang.
enum NativeInlineMarkdown {
  static func attributed(_ value: String) -> AttributedString {
    (try? AttributedString(
      markdown: value, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
      ?? AttributedString(value)
  }
  static func text(_ value: String) -> Text { Text(attributed(value)) }
}

struct NativeInlineText: View {
  let context: OpenUIComponentContext
  let bold: Bool
  private var style: NativeRichTextStyle {
    context.theme.inlineTextStyle(context.string("size") ?? "sm",
      emphasized: bold, numeric: context.string("variant") == "number")
  }
  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      NativeMarkdownText(text: context.string("value") ?? "", mode: .inline, style: style)
      if let sub = context.string("subtext") {
        NativeMarkdownText(text: sub, mode: .inline,
          style: context.theme.textStyle(.supporting).richText(
            numeric: context.string("subtextVariant") == "number", color: subtextColor(sub)))
      }
    }.fixedSize(horizontal: false, vertical: true)
  }
  private func subtextColor(_ value: String) -> Color {
    guard context.string("subtextVariant") == "metric" else { return context.theme.textNeutralSecondary }
    if value.hasPrefix("+") { return semanticColor("success", theme: context.theme) }
    if value.hasPrefix("-") { return semanticColor("danger", theme: context.theme) }
    return context.theme.textNeutralSecondary
  }
}
private struct NativeCardHeaderInsetKey: EnvironmentKey { static let defaultValue: CGFloat = 0 }
extension EnvironmentValues {
  fileprivate var openUICardHeaderInset: CGFloat {
    get { self[NativeCardHeaderInsetKey.self] }
    set { self[NativeCardHeaderInsetKey.self] = newValue }
  }
}

struct NativeMediaText: View {
  @Environment(\.openUICardHeaderInset) private var cardHeaderInset
  @Environment(\.multilineTextAlignment) private var textAlignment
  @ScaledMetric(relativeTo: .body) private var iconScale: CGFloat = 1
  enum Media { case icon, thumbnail, banner }
  let context: OpenUIComponentContext
  let media: Media
  private var vertical: Bool { context.string("layout") == "vertical" }
  private var centered: Bool { vertical && textAlignment == .center }
  private var adaptiveThumbnail: NativeAdaptiveThumbnail? {
    guard media == .thumbnail, explicitImageSize == nil else { return nil }
    return .init(preferred: imageSize,
      minimum: context.presentation.minimumInlineThumbnailSize,
      readingWidth: context.presentation.minimumTextColumnWidth * iconScale)
  }
  var body: some View {
    Group {
      if media == .banner {
        VStack(alignment: .leading, spacing: context.theme.spaceM) {
          NativeRemoteImage(
            src: context.string("src"), alt: context.string("alt") ?? context.string("title") ?? "",
            layout: .aspect(context.presentation.coverAspectRatio), contentMode: .fit)
            .background(context.theme.sunkLight)
            .clipShape(RoundedRectangle(cornerRadius: cardHeaderInset > 0 ? 0 : context.theme.radiusM, style: .continuous))
            .padding(.horizontal, -cardHeaderInset)
            .padding(.top, -cardHeaderInset)
          words
        }.frame(maxWidth: .infinity, alignment: .leading)
      } else {
        NativeMediaRow(axis: vertical ? .vertical : .horizontal,
          gap: context.theme.spaceM * (media == .icon ? iconScale : 1),
          centered: !vertical ? true : centered,
          adaptiveThumbnail: adaptiveThumbnail,
          media: { leadingMedia }, copy: {
            words.frame(maxWidth: .infinity, alignment: centered ? .center : .leading)
              .multilineTextAlignment(centered ? .center : .leading)
          })
      }
    }
  }
  @ViewBuilder private var leadingMedia: some View {
    if media == .icon {
      let style = NativeIconTextStyle(variant: context.presentationString("iconVariant"), theme: context.theme)
      context.slot("icon").environment(\.openUIIconSize, glyphSize)
        .foregroundStyle(style.foreground)
        .frame(width: (glyphSize + style.inset * 2) * iconScale, height: (glyphSize + style.inset * 2) * iconScale)
        .background(style.background,
          in: RoundedRectangle(cornerRadius: context.theme.radiusM))
        .accessibilityIdentifier("openui.icon-text.badge")
    } else {
      NativeRemoteImage(
        src: context.string("src"), alt: context.string("alt") ?? context.string("title") ?? "",
        layout: explicitImageSize.map { .thumbnail(CGSize(width: $0, height: $0)) } ?? .aspect(1))
        .frame(idealWidth: imageSize)
        .clipShape(RoundedRectangle(cornerRadius: context.theme.radiusM, style: .continuous))
    }
  }
  private var glyphSize: CGFloat { NativeIconTextMetrics.glyph(context.presentationString("iconSize")) }
  private var explicitImageSize: CGFloat? {
    if let size = context.presentationNumber("imageSize"), size.isFinite, size > 0 { return CGFloat(size) }
    return nil
  }
  private var imageSize: CGFloat {
    if let explicitImageSize { return explicitImageSize }
    let preferred = context.presentation.inlineThumbnailSize
    return preferred.isFinite && preferred > 0 ? preferred : OpenUIPresentation.defaults.inlineThumbnailSize
  }
  private var words: some View {
    VStack(alignment: centered ? .center : .leading, spacing: context.theme.componentStyle.titleDetailGap) {
      NativeMarkdownText(text: context.string("title") ?? "", mode: .inline,
        style: context.theme.objectTitleStyle(emphasized: media == .banner || context.flag("bold") == true).richText())

      if let sub = context.string("subtitle") {
        NativeMarkdownText(text: sub, mode: .inline, style: context.theme.textStyle(.supporting).richText())
      }
    }.fixedSize(horizontal: false, vertical: true)
  }
}

struct NativeIconButton: View {
  let context: OpenUIComponentContext
  var body: some View {
    OpenUIActionSurface(
      context: context, message: context.string("name") ?? "", action: context.value("action"),
      useNativeStyle: true, validateForm: context.string("variant") == "primary",
      showsProgress: true
    ) {
      context.slot("icon").frame(minWidth: 20, minHeight: 20)
    }.buttonStyle(
      NativeActionButtonStyle(
        theme: context.theme, variant: context.string("variant") ?? "secondary",
        size: context.string("size"), destructive: false,
        iconOnly: true, circular: context.string("shape") == "circle")
    )
    .accessibilityLabel(context.string("name") ?? "")
  }
}
struct NativeTag: View {
  let context: OpenUIComponentContext
  var body: some View {
    NativeTagPill(text: context.string("text") ?? "", size: context.string("size"),
      variant: context.string("variant"), theme: context.theme) { context.slot("icon") }
  }
}
struct NativeTagBlock: View {
  let context: OpenUIComponentContext
  var body: some View {
    NativeWrappingRow(gap: context.theme.spacing("s")) {
      ForEach(context.children("tags")) { tag in
        NativeTagPill(text: NativeValue.string(tag.value), size: context.string("size"),
          variant: nil, theme: context.theme) { EmptyView() }
      }
    }
  }
}
struct NativeWrappingRow<Content: View>: View {
  var gap: CGFloat = 12
  var rowGap: CGFloat? = nil
  @ViewBuilder let content: Content
  var body: some View {
    OpenUIFlexLayout(direction: "row", gap: gap, align: "start", justify: "start", wrap: true, rowGap: rowGap) { content }
  }
}

struct NativeEntityList: View {
  let context: OpenUIComponentContext
  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      if context.string("size") != "small", let header = context.value("header"), header != .null {
        row(header, kind: .header)
        separator
      }
      let rows = context.children("rows")
      ForEach(Array(rows.enumerated()), id: \.element.id) { index, item in
        row(item.value, kind: .body)
        if index < rows.count - 1 {
          separator
        }
      }
      if context.string("size") != "small", let footer = context.value("footer"), footer != .null {
        separator
        row(footer, kind: .footer)
      }
    }
  }
  private var separator: some View {
    Rectangle().fill(context.theme.borderDefault)
      .frame(height: context.presentation.borderWidth).accessibilityHidden(true)
  }
  private enum RowKind { case header, body, footer }
  private func row(_ value: Value, kind: RowKind) -> some View {
    let small = context.string("size") == "small"
    let numeric = NativeValue.string(value, "rightVariant") == "number"
    return NativeLabelValueLayout(
      gap: context.theme.spacing("m"), minimumLabelWidth: context.presentation.minimumTextColumnWidth, equalColumns: true
    ) {
      NativeMarkdownText(text: NativeValue.string(value, "left") ?? "", mode: .inline,
        style: context.theme.entityLabelStyle(compact: small))
      NativeMarkdownText(text: NativeValue.string(value, "right") ?? "", mode: .inline,
        style: context.theme.entityValueStyle(compact: small, numeric: numeric,
          header: kind == .header, footer: kind == .footer))
      // Text wraps in its own stable column; numeric values keep trailing alignment.
      .multilineTextAlignment(numeric ? .trailing : .leading)
    }
    .padding(.vertical, context.theme.spacing(kind == .body ? "s" : "m")).textSelection(.enabled)
    .accessibilityIdentifier("openui.entity-list.row")
  }
}
private struct NativeListPresentation {
  var imageWidth: CGFloat?
  var compact = false
  var axis = NativeMediaRowAxis.horizontal
}
private struct NativeListPresentationKey: EnvironmentKey {
  static let defaultValue = NativeListPresentation()
}
extension EnvironmentValues {
  fileprivate var openUIListPresentation: NativeListPresentation {
    get { self[NativeListPresentationKey.self] }
    set { self[NativeListPresentationKey.self] = newValue }
  }
}

struct NativeListBlock: View {
  let context: OpenUIComponentContext
  @Environment(\.displayScale) private var displayScale
  @ScaledMetric(relativeTo: .body) private var textScale: CGFloat = 1
  @Namespace private var scope
  @State private var containerWidth: CGFloat?
  private var imageList: Bool { context.string("variant") == "image" }
  private var compact: Bool { context.string("size") == "small" }
  private var mediaLayout: NativeListMediaLayout {
    NativeListMediaLayout(width: containerWidth,
      preferredImageWidth: compact ? context.presentation.compactThumbnailSize : context.presentation.thumbnailSize,
      minimumImageWidth: context.presentation.inlineThumbnailSize,
      textWidth: context.presentation.minimumTextColumnWidth * textScale,
      gap: context.theme.spaceM)
  }
  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      ForEach(Array(context.children("items").enumerated()), id: \.element.id) { index, item in
        if index > 0 {
          Rectangle().fill(context.theme.borderDefault).frame(height: 1 / displayScale)
            .padding(.vertical, context.theme.spacing(compact ? "s" : "m"))
        }
        HStack(alignment: .top, spacing: context.theme.spaceM) {
          if !imageList {
            Text("\(index + 1)").openUIFont(context.theme.textBodySm.monospacedDigit()).foregroundStyle(
              context.theme.textNeutralSecondary
            ).frame(minWidth: 22)
          }
          context.render(item.value)
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(GeometryReader { geometry in
      Color.clear.preference(key: NativeListContainerWidths.self, value: [scope: geometry.size.width])
    })
    .onPreferenceChange(NativeListContainerWidths.self) { values in
      guard let width = values[scope], width.isFinite, width > 0 else { return }
      if containerWidth.map({ abs($0 - width) > 0.5 }) ?? true { containerWidth = width }
    }
    .environment(\.openUIListPresentation, NativeListPresentation(
      imageWidth: imageList ? mediaLayout.imageWidth : 0,
      compact: compact, axis: mediaLayout.axis))
  }
}
private struct NativeListContainerWidths: PreferenceKey {
  static let defaultValue: [Namespace.ID: CGFloat] = [:]
  static func reduce(value: inout [Namespace.ID: CGFloat], nextValue: () -> [Namespace.ID: CGFloat]) {
    value.merge(nextValue(), uniquingKeysWith: { _, next in next })
  }
}
struct NativeListItem: View {
  let context: OpenUIComponentContext
  @Environment(\.openUIListPresentation) private var presentation
  private var imageWidth: CGFloat { presentation.imageWidth ?? context.presentation.inlineThumbnailSize }
  private var hasImage: Bool {
    imageWidth > 0 && context.value("image") != nil && context.value("image") != .null
  }
  private var hasAction: Bool {
    context.value("action") != nil && context.value("action") != .null
  }
  var body: some View {
    Group {
      if hasAction {
        OpenUIActionSurface(
          context: context, message: context.string("title") ?? "", action: context.value("action")
        ) { content }
      } else {
        content
      }
    }
  }
  @ViewBuilder private var content: some View {
    Group {
      if hasImage {
        NativeMediaRow(axis: presentation.axis, gap: context.theme.spaceM,
          media: { photo }, copy: { words })
      } else { words }
    }.fixedSize(horizontal: false, vertical: true).contentShape(Rectangle())
  }
  @ViewBuilder private var photo: some View {
    if let image = context.value("image"), image != .null {
      NativeRemoteImage(
        src: NativeValue.string(image, "src"), alt: NativeValue.string(image, "alt") ?? "",
        layout: .thumbnail(CGSize(width: imageWidth, height: imageWidth))
      )
      .frame(width: imageWidth, height: imageWidth)
      .clipShape(RoundedRectangle(cornerRadius: context.theme.radiusM, style: .continuous))
    }
  }
  private var words: some View {
    HStack(alignment: .center, spacing: context.theme.spaceM) {
      VStack(alignment: .leading, spacing: context.theme.componentStyle.titleDetailGap) {
        Text(context.string("title") ?? "").openUIFont(presentation.compact
          ? context.theme.textBodySmHeavy : context.theme.textBodyDefaultHeavy, role: .title)
        if let detail = context.string("subtitle") {
          Text(detail).nativeTextStyle(context.theme.textStyle(.supporting))
        }
        if hasAction, let label = context.string("actionLabel"), !label.isEmpty {
          Text(label).nativeTextStyle(context.theme.textStyle(.compactAction))
            .padding(.top, 2).accessibilityHidden(true)
        }
      }.frame(maxWidth: .infinity, alignment: .leading)
      if hasAction {
        Image(systemName: "chevron.right").openUIFont(context.theme.textBodyXs.weight(.semibold))
          .foregroundStyle(context.theme.textNeutralSecondary).accessibilityHidden(true)
      }
    }.fixedSize(horizontal: false, vertical: true)
  }
}
struct NativeSteps: View {
  let context: OpenUIComponentContext
  @Environment(\.displayScale) private var displayScale
  @ScaledMetric(relativeTo: .body) private var markerDiameter: CGFloat = 28
  var body: some View {
    let items = context.children("items")
    VStack(alignment: .leading, spacing: 0) {
      ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
        HStack(alignment: .top, spacing: context.theme.spacing("m")) {
          NativeStepMarker(number: index + 1, theme: context.theme, diameter: markerDiameter)
          VStack(alignment: .leading, spacing: context.theme.spacing("xs")) {
            Text(NativeValue.string(item.value, "title") ?? "").openUIFont(context.theme.textBodyDefaultHeavy, role: .title)
            NativeMarkdownText(text: NativeValue.string(item.value, "details") ?? "",
              style: context.theme.textStyle(.supporting).richText())
          }
        }
        .padding(.bottom, index < items.count - 1 ? context.theme.spacing("m") : 0)
        .background(alignment: .topLeading) {
          if index < items.count - 1 {
            Rectangle().fill(context.theme.borderInteractive)
              .frame(width: 1.5 / displayScale)
              .padding(.top, markerDiameter + context.theme.spacing("xs")).offset(x: markerDiameter / 2)
              .accessibilityHidden(true)
          }
        }
      }
    }
  }
}
/// The badge follows its text's measured size, including custom fonts and Dynamic Type.
struct NativeStepMarker: View {
  let number: Int
  let theme: OpenUIThemeValues
  let diameter: CGFloat
  var body: some View {
    Text("\(number)").openUIFont(theme.textBodySmHeavy, role: .detail)
      .fixedSize().frame(minWidth: diameter, minHeight: diameter)
      .background(theme.sunk, in: Circle())
      .accessibilityIdentifier("openui.steps.marker")
  }
}

struct NativeCarousel: View {
  let context: OpenUIComponentContext
  @State private var page = 0
  // Carousel's outer array contains pages; each inner array is one page.
  // Rendering-child flattening is appropriate inside a page, never between pages.
  private var pages: [Value] { NativeValue.array(context.value("children")) }
  var body: some View {
    NativePager(ids: Array(pages.indices), selection: $page, enabled: true, identifier: "openui.carousel") { index in
      VStack(alignment: .leading, spacing: context.theme.spacing("s")) { context.render(pages[index]) }
        .modifier(OpenUICardSurface(theme: context.theme, variant: context.string("variant")))
    }
  }
}
struct NativeModal: View {
  let context: OpenUIComponentContext
  @EnvironmentObject private var state: OpenUIState
  @Environment(\.dynamicTypeSize) private var typeSize
  @State private var contentHeight: CGFloat = 420
  private var presented: Binding<Bool> {
    Binding(
      get: {
        if let binding = context.presentationBinding("open") {
          return binding.wrappedValue == .boolean(true) || binding.wrappedValue == .string("true")
        }
        let value = context.presentationFieldValue("open", fallback: context.value("open") ?? .undefined)
        return value == .boolean(true) || value == .string("true")
      },
      set: { open in
        guard context.isCurrentPresentation else { return }
        if let binding = context.presentationBinding("open") {
          binding.wrappedValue = .boolean(open)
        } else {
          context.setPresentationFieldValue("open", value: .boolean(open))
        }
      })
  }
  var body: some View {
    Color.clear.frame(width: 0, height: 0)
      .sheet(isPresented: presented) {
        VStack(alignment: .leading, spacing: context.theme.spacing("ml")) {
          HStack {
            Text(context.string("title") ?? "").openUIFont(context.theme.textBodyDefaultHeavy, role: .title).accessibilityAddTraits(.isHeader)
            Spacer()
            Button {
              presented.wrappedValue = false
            } label: {
              Image(systemName: "xmark").openUIFont(context.theme.textLabelDefaultHeavy, role: .control).openUIControlTarget()
            }
            .buttonStyle(.plain).keyboardShortcut(.cancelAction)
            .accessibilityLabel(Text("Close", bundle: NativeControlResources.bundle))
          }
          .background(GeometryReader { geometry in
            Color.clear.preference(key: NativeModalSizes.self, value: [0: geometry.size.height])
          })
          ScrollView {
            context.slot().frame(maxWidth: .infinity, alignment: .leading)
              .fixedSize(horizontal: false, vertical: true)
              .background(GeometryReader { geometry in
                Color.clear.preference(key: NativeModalSizes.self, value: [1: geometry.size.height])
              })
          }
        }.padding(context.theme.spaceM).frame(
          idealWidth: context.string("size") == "lg"
            ? 720 : context.string("size") == "sm" ? 360 : 520, idealHeight: 420
        )
        .onPreferenceChange(NativeModalSizes.self) { parts in
          guard let header = parts[0], let body = parts[1] else { return }
          let height = header + body + context.theme.spaceML + context.theme.spaceM * 2
          if height.isFinite, height > 0, abs(height - contentHeight) > 0.5 { contentHeight = height }
        }
        .environment(\.dynamicTypeSize, typeSize)
        #if os(iOS)
        .presentationDetents(context.string("size") == "lg" ? [.large] : [
          .height(min(420, max(context.presentation.minimumControlTargetSize * 2, contentHeight))), .large
        ])
        .presentationDragIndicator(.visible)
        #endif
      }
  }
}

private struct NativeModalSizes: PreferenceKey {
  static let defaultValue: [Int: CGFloat] = [:]
  static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
    value.merge(nextValue(), uniquingKeysWith: { _, next in next })
  }
}

private struct NativeCardActionKey: EnvironmentKey {
  static let defaultValue = false
}
fileprivate struct NativeCardGroupAction {
  let message: String
  let action: Value
}
private struct NativeCardGroupActionKey: EnvironmentKey {
  static let defaultValue: NativeCardGroupAction? = nil
}
extension EnvironmentValues {
  fileprivate var openUICardGroupAction: NativeCardGroupAction? {
    get { self[NativeCardGroupActionKey.self] }
    set { self[NativeCardGroupActionKey.self] = newValue }
  }
  var openUICardIsAction: Bool {
    get { self[NativeCardActionKey.self] }
    set { self[NativeCardActionKey.self] = newValue }
  }
}

struct NativeCardItem: View {
  let context: OpenUIComponentContext
  let kind: String
  private var summary: Bool { kind == "Overview" || kind == "Snippet" }
  private var centeredOverview: Bool {
    guard kind == "Overview", case .element(let top) = context.value("top") else { return false }
    return ["IconText", "ImageText"].contains(top.typeName) && PropValue.string(top, "layout") == "vertical"
  }
  private var copyAlignment: Alignment { centeredOverview ? .center : .leading }
  private var itemTheme: OpenUIThemeValues {
    var theme = context.theme
    // The official families share tokens, not an identical outline: Context
    // uses radius-xl, compact fact cards radius-2xl, photo cards radius-3xl.
    theme.radius3xl = context.theme.cardRadius(for: kind)
    // Insets are owned by the component recipe; do not mutate a shared spacing token.
    return theme
  }
  @Environment(\.openUICardIsAction) private var isAction
  @Environment(\.openUICardGroupAction) private var pendingGroupAction
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.dynamicTypeSize) private var typeSize
  @Environment(\.openUIResourceContext) private var artworkResources
  @Environment(\.openUIMediaCache) private var artworkCache
  @State private var artworkImageState: NativeArtworkImageState?
  @State private var copyBelowArtwork = false
  @Namespace private var artworkLayoutScope
  private var groupAction: NativeCardGroupAction? { pendingGroupAction }
  private var bannerHeaderInset: CGFloat {
    guard case .element(let header) = context.value("header"), header.typeName == "ImageTextLarge" else { return 0 }
    return context.theme.spaceM
  }
  private var artworkSource: String? {
    guard ["Visual", "Context"].contains(kind), let source = context.string("bgImageSrc"),
      !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
    return source
  }
  private var artworkRequest: NativeResourceRequestID? {
    guard let source = artworkSource else { return nil }
    return .init(request: artworkResources.request(for: source),
      loader: ObjectIdentifier(artworkResources.loader), attempt: 0)
  }
  private var hasLoadedArtwork: Bool {
    guard context.element.sourceReadiness["bgImageSrc"].complete, let request = artworkRequest else { return false }
    return artworkCache?[request] != nil
      || (artworkImageState?.request == request && artworkImageState?.status == .loaded)
  }
  private var usesArtworkOverlay: Bool {
    hasLoadedArtwork && !typeSize.isAccessibilitySize && !copyBelowArtwork
  }
  private var contentTheme: OpenUIThemeValues {
    var theme = context.theme
    if usesArtworkOverlay {
      theme.textNeutralPrimary = .white
      theme.textNeutralSecondary = .white.opacity(0.86)
      theme.sunk = .black.opacity(0.55)
      theme.foreground = .black.opacity(0.75)
      theme.borderDefault = .white.opacity(0.2)
      theme.background = .black
    }
    return theme
  }
  @ViewBuilder private var actionIndicator: some View {
    if isAction {
      Image(systemName: "chevron.right").openUIFont(context.theme.textLabelSmHeavy, role: .control)
        .foregroundStyle(contentTheme.textNeutralSecondary).accessibilityHidden(true)
    }
  }
  var body: some View {
    Group {
      if summary { content }
      else { content.clipShape(RoundedRectangle(cornerRadius: itemTheme.radius3xl, style: .continuous)) }
    }
    .environment(\.openUITheme, contentTheme)
    .foregroundStyle(contentTheme.textNeutralPrimary)
    .modifier(NativeCardSurface(
      theme: itemTheme,
      // Facts are outlined without a fill so they stay part of the reply;
      // independent offers keep the raised surface. Explicit gray and artwork
      // treatments remain item properties.
      fill: artworkSource != nil ? .clear
        : context.string("bgColor") == "gray" ? context.theme.sunk
        : summary ? .clear : context.theme.foreground,
      bordered: artworkSource == nil && kind != "Context"))
    .environment(\.openUIActionDensity, .compact)
    .environment(\.colorScheme, usesArtworkOverlay ? .dark : colorScheme)
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("openui.card-item." + kind.lowercased())
    .layoutValue(key: OpenUIFlexGrowKey.self, value: true)
    .layoutValue(key: NativeOverviewMetricKey.self,
      value: kind == "Overview" && context.value("bottom") != nil && context.value("bottom") != .null)
  }
  @ViewBuilder private var content: some View {
      if let source = artworkSource, let request = artworkRequest {
        NativeArtworkCardLayout(aspectRatio: context.presentation.coverAspectRatio,
          fallbackWidth: context.presentation.minimumCardWidth, accessibility: typeSize.isAccessibilitySize) {
          ZStack {
            context.theme.sunk
            NativeRemoteImage(src: source, alt: context.string("bgImageAlt") ?? "", layout: .cover,
              onStatus: { status, _ in
                guard context.isCurrentPresentation else { return }
                let next = NativeArtworkImageState(request: request, status: status)
                if artworkImageState != next { artworkImageState = next }
              })
              .environment(\.openUITheme, context.theme)
              .environment(\.colorScheme, colorScheme)
              .environment(\.openUIMediaSourceReady, context.element.sourceReadiness["bgImageSrc"].complete)
          }.allowsHitTesting(false)
          copy.background {
            GeometryReader { geometry in
              Color.clear.preference(key: NativeArtworkCopyPlacementKey.self,
                value: [artworkLayoutScope: geometry.frame(in: .named(artworkLayoutScope)).minY > 0.5])
            }
            if usesArtworkOverlay {
              LinearGradient(colors: [.black.opacity(0.12), .black.opacity(0.62)],
                startPoint: .top, endPoint: .bottom).allowsHitTesting(false)
            }
          }
        }
        .coordinateSpace(name: artworkLayoutScope)
        .onPreferenceChange(NativeArtworkCopyPlacementKey.self) { values in
          if let below = values[artworkLayoutScope], below != copyBelowArtwork { copyBelowArtwork = below }
        }
        .background(usesArtworkOverlay ? Color.black : hasLoadedArtwork ? context.theme.foreground : context.theme.sunk)
      } else {
        copy
      }
  }
  @ViewBuilder private var contextTitle: some View {
    if artworkSource != nil, case .element(let title) = context.value("title"), title.typeName == "Tag" {
      context.slot("title")
        .environment(\.openUIArtworkTag, usesArtworkOverlay)
        .environment(\.openUITheme, context.theme)
        .environment(\.colorScheme, colorScheme)
    } else {
      context.slot("title").openUIFont(context.theme.textBodyDefaultHeavy, role: .title)
    }
  }
  private var copy: some View {
    VStack(alignment: centeredOverview ? .center : .leading,
      spacing: ["Overview", "Context"].contains(kind) ? context.theme.spaceS : context.theme.spaceM) {
      switch kind {
      case "Snippet":
        HStack(alignment: .center, spacing: context.theme.spacing("s")) {
          NativeLabelValueLayout(
            gap: context.theme.spaceM, minimumLabelWidth: context.presentation.minimumCompactCardWidth,
            centerVertically: true
          ) {
            context.slot("lhs")
            context.slot("rhs")
          }
          actionIndicator
        }
      case "Overview":
        HStack(alignment: .top, spacing: context.theme.spacing("s")) {
          context.slot("top").multilineTextAlignment(centeredOverview ? .center : .leading)
            .frame(maxWidth: .infinity, alignment: copyAlignment)
          if isAction {
            Spacer(minLength: 0)
            actionIndicator
          }
        }
        .frame(maxHeight: .infinity, alignment: .topLeading)
        context.slot("bottom").multilineTextAlignment(centeredOverview ? .center : .leading)
          .frame(maxWidth: .infinity, alignment: copyAlignment)
          .alignmentGuide(.nativeOverviewMetricTop) { _ in 0 }
      case "Context":
        contextTitle
        if artworkSource != nil { Spacer(minLength: context.theme.spaceM) }
        if let body = context.string("body") {
          NativeMarkdownText(text: body, mode: .inline, style: contentTheme.textStyle(.compactBody).richText())
        }
      case "Visual":
        context.slot("tag")
          .environment(\.openUIArtworkTag, usesArtworkOverlay)
          .environment(\.openUITheme, context.theme)
          .environment(\.colorScheme, colorScheme)
        if artworkSource != nil { Spacer(minLength: context.theme.spaceM) }
        HStack(alignment: .center, spacing: context.theme.spacing("s")) {
          context.slot("body")
          if isAction {
            Spacer(minLength: 0)
            actionIndicator
          }
        }
      default:
        context.slot("header").environment(\.openUICardHeaderInset, bannerHeaderInset)
        context.slot("body")
        if let footer = context.value("footer"), footer != .null {
          NativeCompositeFooter(context: context, footer: footer)
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
      }
      groupEntry
    }
      .environment(\.openUICardGroupAction, nil)
      .padding(context.theme.componentStyle.objectInset)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: centeredOverview ? .top : .topLeading)
  }
  @ViewBuilder private var groupEntry: some View {
    if let groupAction {
      // A sibling of content/links, inside this item's single surface.
      OpenUIActionSurface(context: context, message: groupAction.message, action: groupAction.action) {
        HStack(spacing: context.theme.spacing("s")) {
          Text(groupAction.message).multilineTextAlignment(.leading)
          Spacer(minLength: 0)
          Image(systemName: "chevron.right").accessibilityHidden(true)
        }
        .openUIFont(context.theme.textLabelSmHeavy, role: .control)
        .foregroundStyle(contentTheme.textNeutralPrimary)
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .disabled(!context.canDispatch(groupAction.action))
      .accessibilityIdentifier("openui.card-item.group-action")
    }
  }
}

struct NativeCompositeFooter: View {
  let context: OpenUIComponentContext
  let footer: Value
  var body: some View {
    // An object footer balances amount and action when their complete widths
    // fit. It becomes a column before compressing either reading value. The
    // same mounted action survives that placement change.
    NativeLabelValueLayout(gap: context.theme.componentStyle.footerGap,
      minimumLabelWidth: .greatestFiniteMagnitude, centerVertically: true,
      collapsesEmptySlots: true) {
      context.render(NativeValue.prop(footer, "price") ?? .null)
      context.render(NativeValue.prop(footer, "button") ?? .null)
    }
  }
}
struct NativeCardBlock: View {
  let context: OpenUIComponentContext
  let kind: String
  @EnvironmentObject private var state: OpenUIState
  @Environment(\.dynamicTypeSize) private var typeSize
  @State private var selectedID = ""
  private var children: [OpenUIRenderChild] {
    var occurrences: [String: Int] = [:]
    return context.children("items").map { child in
      guard case .element(let item) = child.value, let statement = item.statementId else { return child }
      let ordinal = occurrences[statement, default: 0]; occurrences[statement] = ordinal + 1
      return OpenUIRenderChild(id: "statement:\(statement):\(ordinal)", value: child.value)
    }
  }
  private var layoutCount: Int? {
    let source = context.element.sourceReadiness["items"]
    return !source.complete && source.closed ? source.expectedCount : nil
  }
  private var selection: Binding<String> {
    Binding(get: { children.contains(where: { $0.id == selectedID }) ? selectedID : children.first?.id ?? "" },
      set: { selectedID = $0 })
  }
  private var gap: CGFloat {
    CGFloat(
      min(
        128, max(0, context.presentationNumber("gap") ?? Double(context.theme.spacing(context.presentationString("gap"))))))
  }
  private var grid: NativeCardGrid? {
    let layout = context.string("layout")
    // The standard component host admits only a committed layout. No guessed
    // carousel is needed while positional collection arguments are arriving.
    guard layout != "carousel" else { return nil }
    return NativeCardGrid(maxPerRow: ["Overview", "Context", "Visual"].contains(kind) ? 3 : 2,
      responsive: context.flag("responsive") != false,
      singleColumn: typeSize.isAccessibilitySize,
      minimumColumnWidth: kind == "Overview" ? overviewMinimumWidth : nil, spacing: gap)
  }
  private var overviewMinimumWidth: CGFloat {
    // Horizontal media needs a real reading column next to the thumbnail;
    // compact text/icon metrics can share the row. This follows declared
    // component/layout roles, never the wording or length of a particular case.
    let hasHorizontalMedia = children.contains { child in
      guard case .element(let top) = NativeValue.prop(child.value, "top") else { return false }
      return top.typeName == "ImageText" && PropValue.string(top, "layout") != "vertical"
    }
    return hasHorizontalMedia ? context.presentation.minimumCardWidth : context.presentation.minimumCompactCardWidth
  }
  var body: some View {
    Group {
      if children.isEmpty {
        EmptyView()
      } else {
        NativePager(ids: children.map(\.id), selection: selection, enabled: true,
          identifier: "openui.card-block.\(kind.lowercased())",
          showsControls: false,
          maximumPageWidth: context.presentation.maximumCarouselCardWidth,
          trailingPeek: context.presentation.carouselPeek, pageSpacing: gap, grid: grid, layoutCount: layoutCount, supportsAdjustment: false) { id in
          if let index = children.firstIndex(where: { $0.id == id }) {
            item(children[index], index: index)
          }
        }
      }
    }
  }
  @ViewBuilder private func item(_ item: OpenUIRenderChild, index: Int) -> some View {
    if let value = context.value("action"), value != .null {
      let message = NativeCardAction.label(item.value, kind: kind, index: index)
      let action = NativeCardAction.action(value, item: item.value, kind: kind, index: index)
      if ["Snippet", "Overview", "Visual"].contains(kind) {
        // These upstream item types contain presentation-only slots.
        // The image and text share one native Button hit target.
        OpenUIActionSurface(context: context, message: message, action: action) {
          context.render(item.value).environment(\.openUICardIsAction, true)
        }.accessibilityLabel(message)
      } else {
        if case .element = item.value {
          context.render(item.value).environment(\.openUICardGroupAction,
            NativeCardGroupAction(message: message, action: action))
        } else {
          context.render(item.value)
        }
      }
    } else {
      context.render(item.value)
    }
  }
}

struct NativeFollowUpBlock: View {
  let context: OpenUIComponentContext
  var body: some View {
    NativeWrappingRow(gap: context.theme.spacing("s")) {
      ForEach(context.children("items")) { item in
        context.render(item.value)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

struct NativeFollowUpItem: View {
  let context: OpenUIComponentContext
  private var text: String { context.string("text") ?? "" }
  var body: some View {
    OpenUIActionSurface(context: context, message: text, action: Self.action(for: text)) {
      Text(text)
        .fixedSize(horizontal: false, vertical: true)
        .nativeTextStyle(context.theme.textStyle(.compactAction))
        .padding(.horizontal, context.theme.spacing("m"))
        .padding(.vertical, context.theme.spacing("s"))
        .background(context.theme.sunk, in: Capsule(style: .continuous))
        .overlay(
          Capsule(style: .continuous).strokeBorder(context.theme.borderDefault,
            lineWidth: context.presentation.borderWidth))
        .openUIControlTarget(alignment: .leading)
    }
    .buttonStyle(.plain)
    .accessibilityLabel(text)
    .accessibilityIdentifier("openui.followup")
  }
  static func action(for text: String) -> Value {
    .object(OpenUIObject([
      ObjectField(key: OpenUIString("type"), value: .string(OpenUIString("continue_conversation"))),
      ObjectField(key: OpenUIString("message"), value: .string(OpenUIString(text))),
    ]))
  }
}
