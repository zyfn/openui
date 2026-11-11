import Foundation
import OpenUILang
import SwiftUI
import WebKit

enum OpenUIGraphicComponents {
    static var svg: OpenUIComponent {
        OpenUIComponent(name: "SVG", description: "Use to explain shapes, structures, mechanisms, or relationships when a diagram makes them easier to understand. Keep the key idea clear and labels readable at the available width. Supply either inline SVG content or an HTTPS src, not both, with a valid viewBox. Size is derived automatically from viewBox; omit height.", params: [
            OpenUIParameter.string("content", required: false), OpenUIParameter.string("src", required: false),
            OpenUIParameter.string("alt", required: false), OpenUIParameter.number("height")
        ]) { context in MainActor.assumeIsolated { NativeSVG(context: context) } }
    }
}

private struct NativeSVG: View {
    let context: OpenUIComponentContext
    @State private var downloaded: String?
    @State private var failed = false
    @Environment(\.colorScheme) private var scheme
    @Environment(\.openUIResourceContext) private var resources
    private var document: NativeSVGDocument? {
        if context.string("content") != nil && context.string("src") != nil { return nil }
        guard context.string("content") == nil || context.element.sourceReadiness["content"].complete else { return nil }
        return (context.string("content") ?? downloaded).flatMap(NativeSVGDocument.parse)
    }
    var body: some View {
        Group {
            if let document {
                web(document).aspectRatio(document.ratio, contentMode: .fit)
            } else if !failed && (context.isStreaming || (context.string("src") != nil && context.string("content") == nil && downloaded == nil)) {
                NativePendingContent(loading: true, message: "Loading")
            } else {
                Text(failed ? "Unable to load graphic" : "Graphic requires a valid SVG viewBox", bundle: NativeControlResources.bundle)
                    .nativeTextStyle(context.theme.textStyle(.supporting))
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(context.string("alt") ?? "SVG")
        .task(id: NativeResourceRequestID(request: remoteRequest, loader: ObjectIdentifier(resources.loader), attempt: 0)) {
            downloaded = nil; failed = false
            guard context.element.sourceReadiness["src"].complete, context.string("src") != nil, context.string("content") == nil else { return }
            guard var request = remoteRequest else { failed = true; return }
            do {
                request.timeoutInterval = 20
                let data = try await resources.loader.data(for: request)
                guard data.count <= 1_000_000,
                      let text = String(data: data, encoding: .utf8), NativeSVGDocument.parse(text) != nil else { failed = true; return }
                try Task.checkCancellation(); downloaded = text
            } catch is CancellationError { } catch { if !Task.isCancelled { failed = true } }
        }
    }
    private var remoteRequest: URLRequest? {
        guard context.element.sourceReadiness["src"].complete, context.string("content") == nil else { return nil }
        return NativeSVGResource.request(context.string("src"), resources: resources)
    }
    private func web(_ document: NativeSVGDocument) -> SVGWebView {
        SVGWebView(html: """
        <!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1">
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; img-src data:; script-src 'none'; connect-src 'none'; base-uri 'none'">
        <style>html,body{margin:0;width:100%;height:100%;overflow:hidden;background:transparent;color:\(NativeCSSColor.css(context.theme.textNeutralPrimary, scheme: scheme));font-family:-apple-system,sans-serif}svg{display:block;width:100%!important;height:100%!important}</style>
        </head><body>\(document.markup)</body></html>
        """)
    }
}

@MainActor private final class SVGWebCoordinator: NSObject, WKNavigationDelegate {
    var html = ""
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void) {
        decisionHandler(navigationAction.request.url?.scheme == "about" ? .allow : .cancel)
    }
}
@MainActor private func svgWebView(_ coordinator: SVGWebCoordinator) -> WKWebView {
    let config = WKWebViewConfiguration(); config.websiteDataStore = .nonPersistent()
    config.defaultWebpagePreferences.allowsContentJavaScript = false
    let view = WKWebView(frame: .zero, configuration: config); view.navigationDelegate = coordinator
    #if os(iOS)
    view.isOpaque = false; view.backgroundColor = .clear; view.scrollView.isScrollEnabled = false
    #endif
    return view
}
#if os(iOS)
private struct SVGWebView: UIViewRepresentable {
    let html: String
    func makeCoordinator() -> SVGWebCoordinator { SVGWebCoordinator() }
    func makeUIView(context: Context) -> WKWebView { svgWebView(context.coordinator) }
    func updateUIView(_ view: WKWebView, context: Context) {
        if context.coordinator.html != html { context.coordinator.html = html; view.loadHTMLString(html, baseURL: nil) }
    }
}
#else
private struct SVGWebView: NSViewRepresentable {
    let html: String
    func makeCoordinator() -> SVGWebCoordinator { SVGWebCoordinator() }
    func makeNSView(context: Context) -> WKWebView { svgWebView(context.coordinator) }
    func updateNSView(_ view: WKWebView, context: Context) {
        if context.coordinator.html != html { context.coordinator.html = html; view.loadHTMLString(html, baseURL: nil) }
    }
}
#endif

enum NativeSVGResource {
    static func request(_ source: String?, resources: OpenUIResourceContext) -> URLRequest? {
        guard let source, let url = URL(string: source, relativeTo: resources.baseURL)?.absoluteURL,
              url.scheme?.lowercased() == "https", url.host?.isEmpty == false, url.user == nil, url.password == nil,
              let request = resources.request(for: source), request.url?.scheme?.lowercased() == "https" else { return nil }
        return request
    }
}
