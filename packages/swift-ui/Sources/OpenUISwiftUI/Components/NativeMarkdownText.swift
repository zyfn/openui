import MarkdownUI
import SwiftUI

/// Standard block Markdown is a presentation format inside the existing
/// component, independent of OpenUI Lang parsing and component validation.
struct NativeMarkdownText: View {
  let text: String
  @Environment(\.openUITheme) private var theme
  @Environment(\.openUIResourceContext) private var resources

  var body: some View {
    MarkdownUI.Markdown(text, baseURL: resources.baseURL, imageBaseURL: resources.baseURL)
      .markdownTheme(.basic)
      .markdownTextStyle { ForegroundColor(theme.foreground) }
      .markdownTextStyle(\.link) { ForegroundColor(theme.accent) }
      // MarkdownUI owns semantic fonts through its FontProperties model;
      // an outer SwiftUI Font cannot override those attributed runs.
      .markdownBlockStyle(\.paragraph) { configuration in
        configuration.label
          .fixedSize(horizontal: false, vertical: true)
          .relativeLineSpacing(.em(0.15))
          .markdownMargin(top: 0, bottom: theme.contentSpacing)
      }
      .markdownImageProvider(NativeMarkdownImageProvider())
      .textSelection(.enabled)
      .frame(maxWidth: .infinity, alignment: .leading)
  }
}

private struct NativeMarkdownImageProvider: ImageProvider {
  func makeImage(url: URL?) -> some View {
    NativeMarkdownImage(url: url)
  }
}

private struct NativeMarkdownImage: View {
  let url: URL?
  @Environment(\.openUITheme) private var theme
  @State private var status: NativeMediaStatus = .loading

  var body: some View {
    NativeRemoteImage(src: url?.absoluteString, layout: .intrinsic,
                      onStatus: { phase, _ in status = phase })
      .clipShape(RoundedRectangle(cornerRadius: theme.mediaCornerRadius, style: .continuous))
      .accessibilityElement(children: .ignore)
      .accessibilityAddTraits(.isImage)
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
