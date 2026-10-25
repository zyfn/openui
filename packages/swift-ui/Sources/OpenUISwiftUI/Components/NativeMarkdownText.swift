import MarkdownUI
import OpenUILang
import SwiftUI
#if os(iOS)
import UIKit
#else
import AppKit
#endif

struct NativeRichTextStyle {
  var scale: CGFloat = 1
  var weight: Font.Weight = .regular
  var numeric = false
  var color: Color?
  static func textContent(_ size: String?, theme: OpenUITheme) -> Self {
    let scale: CGFloat
    switch size {
    case "small", "small-heavy": scale = 15 / 17
    case "large": scale = 20 / 17
    case "large-heavy": scale = 28 / 17
    default: scale = 1
    }
    return .init(scale: scale, weight: size?.hasSuffix("heavy") == true ? .semibold : .regular,
      color: size == "small" ? theme.secondary : theme.foreground)
  }
}

/// Shared native Markdown presentation. Remark owns text parsing and extensions;
/// MarkdownUI lays out native blocks, and CodeBlock shares the standard renderer.
struct NativeMarkdownText: View {
  let text: String
  var mode = NativeRichTextMode.markdown
  var style = NativeRichTextStyle()
  @Environment(\.openUITheme) private var theme
  @Environment(\.openUIResourceContext) private var resources
  @Environment(\.cardSources) private var sources
  @Environment(\.openURL) private var openURL
  @Environment(\.colorScheme) private var colorScheme
  @ScaledMetric(relativeTo: .body) private var bodySize = FontProperties.defaultSize
  @StateObject private var math = NativeMathRenderer()
  @State private var prepared: String?
  @State private var preparedRequest: NativeRichTextRequest?
  @State private var citation: NativeCitationSelection?
  private var foreground: Color { style.color ?? theme.foreground }
  private var mathSize: CGFloat { bodySize * style.scale }
  private var mathColor: String { NativeMathColor.css(foreground, scheme: colorScheme) }
  private var request: NativeRichTextRequest {
    .init(source: OpenUIString(text), mode: mode, sources: sources, fontSize: Double(mathSize), color: mathColor)
  }

  var body: some View {
    MarkdownUI.Markdown(preparedRequest == request ? prepared ?? text : text,
      baseURL: resources.baseURL, imageBaseURL: resources.baseURL)
      .markdownTextStyle {
        ForegroundColor(foreground)
        FontSize(FontProperties.defaultSize * style.scale)
        FontWeight(style.weight)
        FontDigitVariant(style.numeric ? .monospaced : .normal)
      }
      .markdownTextStyle(\.link) { ForegroundColor(theme.accent) }
      .markdownSoftBreakMode(mode == .markdown ? .space : .lineBreak)
      .markdownBlockStyle(\.paragraph) { configuration in
        configuration.label.fixedSize(horizontal: false, vertical: true)
          .relativeLineSpacing(.em(0.15))
          .markdownMargin(top: 0, bottom: mode == .inline ? 0 : theme.contentSpacing)
      }
      .markdownBlockStyle(\.codeBlock) { configuration in
        NativeCodeBlockContent(code: OpenUIString(configuration.content.trimmingCharacters(in: .whitespacesAndNewlines)),
          language: OpenUIString(NativeMarkdownCode.language(configuration.language)), theme: theme)
          .markdownMargin(top: 8, bottom: 8)
      }
      .markdownTheme(.basic)
      .markdownImageProvider(NativeMarkdownImageProvider(math: math, fontSize: mathSize, color: mathColor))
      .markdownInlineImageProvider(NativeMarkdownInlineImages(math: math, fontSize: mathSize, color: mathColor, resources: resources))
      .textSelection(.enabled)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(alignment: .topLeading) {
        NativeMathHost(renderer: math).frame(width: 1, height: 1).clipped().opacity(0.001)
          .accessibilityHidden(true).allowsHitTesting(false)
      }
      .environment(\.openURL, OpenURLAction { url in
        if let selection = NativeCitationSelection(url: url, sources: sources) {
          citation = selection; return .handled
        }
        guard let safe = NativeRichTextEngine.shared.sourceURL(url.absoluteString), let target = URL(string: safe) else { return .discarded }
        openURL(target); return .handled
      })
      .popover(item: $citation) { selected in
        NativeCitationSources(indices: selected.indices, sources: sources)
          .environment(\.openUITheme, theme).environment(\.openUIResourceContext, resources)
      }
      .task(id: request) {
        let current = request
        let worker = Task.detached(priority: .userInitiated) {
          try NativeRichTextEngine.shared.prepare(current.source.displayString, mode: current.mode,
            sources: current.sources, fontSize: current.fontSize, color: current.color)
        }
        do {
          let value = try await withTaskCancellationHandler(operation: { try await worker.value }, onCancel: { worker.cancel() })
          guard !Task.isCancelled else { return }
          prepared = value; preparedRequest = current
        } catch {
          guard !Task.isCancelled else { return }
          // Keep readable source on a resource/parse failure; the language
          // runtime's diagnostic and state channels remain independent.
          prepared = text; preparedRequest = current
        }
      }
      .onDisappear { math.cancel() }
  }
}

enum NativeMarkdownCode {
  static func language(_ info: String?) -> String {
    guard let info, let match = info.range(of: #"^\w+"#, options: .regularExpression) else { return "text" }
    return String(info[match])
  }
}

private enum NativeMathColor {
  static func css(_ color: Color, scheme: ColorScheme) -> String {
    #if os(iOS)
    let value = UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: scheme == .dark ? .dark : .light))
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 1
    value.getRed(&r, green: &g, blue: &b, alpha: &a)
    #else
    var resolved = NSColor.black
    let appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
    appearance?.performAsCurrentDrawingAppearance { resolved = NSColor(color).usingColorSpace(.deviceRGB) ?? .black }
    let r = resolved.redComponent, g = resolved.greenComponent, b = resolved.blueComponent, a = resolved.alphaComponent
    #endif
    return String(format: "#%02x%02x%02x%02x", Int(r * 255), Int(g * 255), Int(b * 255), Int(a * 255))
  }
}

private struct NativeMarkdownImageProvider: ImageProvider {
  let math: NativeMathRenderer
  let fontSize: CGFloat
  let color: String
  @ViewBuilder func makeImage(url: URL?) -> some View {
    if let url, let descriptor = NativeMathDescriptor(url: url) {
      NativeMathBlock(descriptor: descriptor, renderer: math, fontSize: fontSize, color: color)
    } else { NativeMarkdownImage(url: url) }
  }
}

private struct NativeMarkdownInlineImages: InlineImageProvider {
  let math: NativeMathRenderer
  let fontSize: CGFloat
  let color: String
  let resources: OpenUIResourceContext
  func image(with url: URL, label: String) async throws -> Image {
    if let descriptor = NativeMathDescriptor(url: url) {
      return try await math.image(for: descriptor, fontSize: fontSize, color: color).swiftUIImage(label: label)
    }
    guard let request = resources.request(for: url.absoluteString) else { throw URLError(.unsupportedURL) }
    let data = try await resources.loader.data(for: request)
    try Task.checkCancellation()
    #if os(iOS)
    guard let image = UIImage(data: data), let cgImage = image.cgImage else { throw URLError(.cannotDecodeContentData) }
    return Image(cgImage, scale: image.scale, label: Text(label))
    #else
    guard let image = NSImage(data: data), let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { throw URLError(.cannotDecodeContentData) }
    return Image(cgImage, scale: 1, label: Text(label))
    #endif
  }
}

private struct NativeMathBlock: View {
  let descriptor: NativeMathDescriptor
  let renderer: NativeMathRenderer
  let fontSize: CGFloat
  let color: String
  @State private var image: NativeMathImage?
  @State private var failed = false
  private var key: String {
    "\(fontSize):\(color):" + ((try? JSONEncoder().encode(descriptor).base64EncodedString()) ?? "")
  }
  var body: some View {
    Group {
      if let image {
        ScrollView(.horizontal) {
          image.swiftUIImage(label: descriptor.tex).frame(width: image.size.width, height: image.size.height)
        }.frame(height: image.size.height)
          .accessibilityElement(children: .ignore).accessibilityLabel(descriptor.tex)
          .accessibilityAddTraits(.isImage).accessibilityIdentifier("openui.math.rendered")
      } else if failed {
        Text(descriptor.tex).font(.system(.body, design: .monospaced)).textSelection(.enabled)
          .accessibilityIdentifier("openui.math.fallback")
      } else { ProgressView().frame(minHeight: fontSize * 1.5).accessibilityIdentifier("openui.math.loading") }
    }.task(id: key) {
      image = nil; failed = false
      do {
        let result = try await renderer.image(for: descriptor, fontSize: fontSize, color: color)
        guard !Task.isCancelled else { return }
        image = result
      } catch { if !Task.isCancelled { failed = true } }
    }
  }
}

private struct NativeMarkdownImage: View {
  let url: URL?
  @Environment(\.openUITheme) private var theme
  @State private var status: NativeMediaStatus = .loading
  var body: some View {
    NativeRemoteImage(src: url?.absoluteString, layout: .intrinsic, onStatus: { phase, _ in status = phase })
      .clipShape(RoundedRectangle(cornerRadius: theme.mediaCornerRadius, style: .continuous))
      .accessibilityElement(children: .ignore).accessibilityAddTraits(.isImage)
      .accessibilityIdentifier(identifier)
  }
  private var identifier: String {
    switch status {
    case .loading: return "openui.markdown.image.loading"
    case .loaded: return "openui.markdown.image.loaded"
    case .unavailable: return "openui.markdown.image.unavailable"
    }
  }
}
