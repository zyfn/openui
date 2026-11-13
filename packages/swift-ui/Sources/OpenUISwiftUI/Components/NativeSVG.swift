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
    @State private var drawingStatus = NativeMediaStatus.loading
    @State private var documents = NativeSVGDocumentCache()
    @Environment(\.colorScheme) private var scheme
    @Environment(\.openUIResourceContext) private var resources
    private var document: NativeSVGDocument? {
        if context.string("content") != nil && context.string("src") != nil { return nil }
        guard context.string("content") == nil || context.element.sourceReadiness["content"].complete else { return nil }
        return documents.value(context.string("content") ?? downloaded)
    }
    var body: some View {
        Group {
            if let document {
                web(document).aspectRatio(document.viewportRatio, contentMode: .fit)
                    .frame(maxHeight: 1024)
                    .overlay {
                        if drawingStatus == .loading {
                            NativePendingContent(loading: true, message: "Loading")
                        } else if drawingStatus == .unavailable {
                            Text("Unable to load graphic", bundle: NativeControlResources.bundle)
                                .nativeTextStyle(context.theme.textStyle(.supporting))
                        }
                    }
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
        .task(id: NativeResourceRequestID(request: remoteRequest, loader: ObjectIdentifier(resources.loader), attempt: 0, authorizationScope: resources.loader.authorizationScopeID)) {
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
        """, onStatus: { drawingStatus = $0 })
    }
}

@MainActor private final class SVGWebCoordinator: NSObject, WKNavigationDelegate {
    private var html = ""
    private var generation = 0
    private var navigation: WKNavigation?
    private var timeout: Task<Void, Never>?
    private var onStatus: ((NativeMediaStatus) -> Void)?
    func update(_ html: String, view: WKWebView, onStatus: @escaping (NativeMediaStatus) -> Void) {
        self.onStatus = onStatus
        guard self.html != html else { return }
        self.html = html
        generation += 1
        let epoch = generation
        timeout?.cancel()
        navigation = view.loadHTMLString(html, baseURL: nil)
        Task { @MainActor [weak self] in
            guard let self, self.generation == epoch else { return }
            self.onStatus?(.loading)
        }
        timeout = Task { @MainActor [weak self, weak view] in
            do { try await Task.sleep(nanoseconds: 20_000_000_000) } catch { return }
            guard let self, self.generation == epoch else { return }
            view?.stopLoading(); self.finish(.unavailable)
        }
    }
    private func finish(_ status: NativeMediaStatus) {
        timeout?.cancel(); timeout = nil
        onStatus?(status)
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard navigation === self.navigation else { return }
        finish(.loaded)
    }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        guard navigation === self.navigation else { return }
        finish(.unavailable)
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        guard navigation === self.navigation else { return }
        finish(.unavailable)
    }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { finish(.unavailable) }
    func dispose(_ view: WKWebView) {
        generation += 1; timeout?.cancel(); timeout = nil; onStatus = nil
        view.navigationDelegate = nil; view.stopLoading(); navigation = nil
    }
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
    let onStatus: (NativeMediaStatus) -> Void
    func makeCoordinator() -> SVGWebCoordinator { SVGWebCoordinator() }
    func makeUIView(context: Context) -> WKWebView { svgWebView(context.coordinator) }
    func updateUIView(_ view: WKWebView, context: Context) {
        context.coordinator.update(html, view: view, onStatus: onStatus)
    }
    static func dismantleUIView(_ view: WKWebView, coordinator: SVGWebCoordinator) { coordinator.dispose(view) }
}
#else
private struct SVGWebView: NSViewRepresentable {
    let html: String
    let onStatus: (NativeMediaStatus) -> Void
    func makeCoordinator() -> SVGWebCoordinator { SVGWebCoordinator() }
    func makeNSView(context: Context) -> WKWebView { svgWebView(context.coordinator) }
    func updateNSView(_ view: WKWebView, context: Context) {
        context.coordinator.update(html, view: view, onStatus: onStatus)
    }
    static func dismantleNSView(_ view: WKWebView, coordinator: SVGWebCoordinator) { coordinator.dispose(view) }
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
