import Foundation
import OpenUILang
import OpenUISwiftUI
import SwiftUI
import WebKit

/// Optional presentation primitives. They do not change the upstream catalog.
public enum OpenUIWebComponents {
    public static func install(into base: OpenUIComponentLibrary) throws -> OpenUIComponentLibrary {
        let height = ParamDef(name: "height", required: false, schema: .object([
            .init(key: "type", value: .string("number")), .init(key: "minimum", value: .number(1))
        ]))
        let svg = OpenUIComponent(name: "SVG", description: """
            A scalable vector illustration, diagram or custom data graphic. Supply a complete SVG
            document in content, or its resource URL in src. Never invent an image URL. The viewBox
            determines proportions; omitted height follows its actual rendered content. alt describes
            its meaning. Scripts are disabled. Prefer standard charts for ordinary numeric data.
            """, params: [OpenUIParameter.string("content", required: false), OpenUIParameter.string("src", required: false),
                OpenUIParameter.string("alt", required: false), height]) { NativeEmbeddedContent(context: $0, svg: true) }
        let web = OpenUIComponent(name: "WebView", description: """
            Embedded web content for an existing webpage or a self-contained HTML visualization
            that native components cannot express. Supply html or src, not both. Omitted height
            follows content; an explicit height creates a scrollable viewport. Links open through
            the normal URL handler. Prefer native components for ordinary cards, forms and text.
            Page JavaScript is disabled by default and controlled by SDK policy, never by generated content.
            """, params: [OpenUIParameter.string("html", required: false), OpenUIParameter.string("src", required: false),
                OpenUIParameter.string("title", required: false), height]) { NativeEmbeddedContent(context: $0, svg: false) }
        let names = ["SVG", "WebView"]
        return try base.extending(adding: [svg, web], slots: Dictionary(uniqueKeysWithValues:
            names.map { ($0, base.standardContentSlots) }))
    }
}

/// Web execution is an application capability, not a model-controlled flag.
public struct OpenUIWebPolicy {
    public var allowsJavaScript: Bool
    public init(allowsJavaScript: Bool = false) { self.allowsJavaScript = allowsJavaScript }
}
private struct NativeWebPolicyKey: EnvironmentKey { static let defaultValue = OpenUIWebPolicy() }
extension EnvironmentValues {
    public var openUIWebPolicy: OpenUIWebPolicy {
        get { self[NativeWebPolicyKey.self] }
        set { self[NativeWebPolicyKey.self] = newValue }
    }
}
extension View {
    public func openUIWebPolicy(_ policy: OpenUIWebPolicy) -> some View { environment(\.openUIWebPolicy, policy) }
}

enum NativeSVGDocument {
    static func html(_ content: String, alt: String) -> String? {
        guard let bytes = content.data(using: .utf8) else { return nil }
        let validator = Validator()
        let parser = XMLParser(data: bytes)
        parser.shouldResolveExternalEntities = false
        parser.delegate = validator
        guard parser.parse(), validator.rootIsSVG else { return nil }
        return """
        <!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1">
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; img-src https: http: data:; font-src data:; script-src 'none'">
        <style>html,body{margin:0;padding:0;background:transparent;font-family:-apple-system,system-ui,sans-serif}body>div>svg{display:block;width:100%;max-width:100%;height:auto}body>div{width:100%}</style>
        </head><body><div role="img" aria-label="\(escape(alt))">\(content)</div></body></html>
        """
    }
    static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;")
    }
    private final class Validator: NSObject, XMLParserDelegate {
        var rootIsSVG = false
        private var depth = 0
        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                    qualifiedName qName: String?, attributes: [String: String] = [:]) {
            if depth == 0 { rootIsSVG = elementName.lowercased() == "svg" }
            depth += 1
        }
        func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) { depth -= 1 }
        func parser(_ parser: XMLParser, foundInternalEntityDeclarationWithName name: String, value: String?) { parser.abortParsing() }
        func parser(_ parser: XMLParser, foundExternalEntityDeclarationWithName name: String, publicID: String?, systemID: String?) { parser.abortParsing() }
    }
}

private struct NativeEmbeddedContent: View {
    let context: OpenUIComponentContext
    let svg: Bool
    @Environment(\.openUIResourceContext) private var resources
    @Environment(\.openUIWebPolicy) private var webPolicy
    @Environment(\.openURL) private var openURL
    @State private var remoteSVG: String?
    @State private var loadedSVGRequest: WebResourceRequestID?
    @State private var failed = false
    @State private var measuredHeight: CGFloat = 44
    @State private var attempt = 0
    @Namespace private var webInstance
    private var request: URLRequest? { resources.request(for: context.string("src")) }
    private var inline: String? { context.string(svg ? "content" : "html") }
    private var html: String? {
        svg ? (inline ?? (loadedSVGRequest == requestID ? remoteSVG : nil))
            .flatMap { NativeSVGDocument.html($0, alt: context.string("alt") ?? "") } : inline
    }
    private var requestID: WebResourceRequestID {
        .init(request: request, loader: ObjectIdentifier(resources.loader), attempt: attempt)
    }
    var body: some View {
        Group {
            if (inline != nil && context.string("src") != nil) || failed || (svg && (inline ?? remoteSVG) != nil && html == nil) {
                unavailable
            } else if html != nil || (!svg && request != nil) {
                NativeWebSurface(html: html, request: svg ? nil : request, baseURL: resources.baseURL,
                    javaScript: !svg && webPolicy.allowsJavaScript, scrolls: context.number("height") != nil,
                    title: context.string(svg ? "alt" : "title") ?? "", resources: resources,
                    measuredHeight: $measuredHeight, failed: $failed, open: { openURL($0) })
                    .id(WebPresentationIdentity(instance: webInstance, svg: svg,
                                               javaScript: !svg && webPolicy.allowsJavaScript))
                    .frame(height: CGFloat(context.number("height") ?? Double(measuredHeight)))
            } else if svg && request != nil {
                ProgressView().frame(maxWidth: .infinity, minHeight: 44)
            } else { unavailable }
        }
        .task(id: requestID) {
            remoteSVG = nil; loadedSVGRequest = nil; failed = false; measuredHeight = 44
            guard svg, inline == nil, let request else { return }
            do {
                let bytes = try await resources.loader.data(for: request)
                try Task.checkCancellation()
                guard let text = String(data: bytes, encoding: .utf8), NativeSVGDocument.html(text, alt: "") != nil else {
                    throw URLError(.cannotDecodeContentData)
                }
                remoteSVG = text
                loadedSVGRequest = requestID
            } catch { if !Task.isCancelled { failed = true } }
        }
        .onChange(of: inline) { _ in measuredHeight = 44; failed = false }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(svg ? "openui.svg" : "openui.web")
    }
    private var unavailable: some View {
        HStack(spacing: 8) {
            Label(svg ? "SVG unavailable" : "Web content unavailable", systemImage: "rectangle.slash")
                .font(context.theme.typography.caption)
            Spacer(minLength: 0)
            if request != nil {
                Button("Retry") { failed = false; attempt += 1 }
                    .buttonStyle(.plain).font(context.theme.typography.caption).frame(minHeight: 44)
            }
        }.foregroundStyle(context.theme.secondary).padding(10)
          .background(context.theme.surface, in: RoundedRectangle(cornerRadius: context.theme.controlCornerRadius))
    }
}

private struct WebPresentationIdentity: Hashable {
    let instance: Namespace.ID
    let svg: Bool
    let javaScript: Bool
}

#if os(iOS)
private struct NativeWebSurface: UIViewRepresentable {
    let html: String?
    let request: URLRequest?
    let baseURL: URL?
    let javaScript: Bool
    let scrolls: Bool
    let title: String
    let resources: OpenUIResourceContext
    @Binding var measuredHeight: CGFloat
    @Binding var failed: Bool
    let open: (URL) -> Void
    func makeCoordinator() -> NativeWebCoordinator { NativeWebCoordinator(owner: self) }
    func makeUIView(context: Context) -> WKWebView { context.coordinator.makeView() }
    func updateUIView(_ view: WKWebView, context: Context) { context.coordinator.update(self, view: view) }
    static func dismantleUIView(_ view: WKWebView, coordinator: NativeWebCoordinator) { coordinator.dispose(view) }
}
#else
private struct NativeWebSurface: NSViewRepresentable {
    let html: String?
    let request: URLRequest?
    let baseURL: URL?
    let javaScript: Bool
    let scrolls: Bool
    let title: String
    let resources: OpenUIResourceContext
    @Binding var measuredHeight: CGFloat
    @Binding var failed: Bool
    let open: (URL) -> Void
    func makeCoordinator() -> NativeWebCoordinator { NativeWebCoordinator(owner: self) }
    func makeNSView(context: Context) -> WKWebView { context.coordinator.makeView() }
    func updateNSView(_ view: WKWebView, context: Context) { context.coordinator.update(self, view: view) }
    static func dismantleNSView(_ view: WKWebView, coordinator: NativeWebCoordinator) { coordinator.dispose(view) }
}
#endif

@MainActor private final class NativeWebCoordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    var owner: NativeWebSurface
    private var lastHTML: String?
    private var lastRequest: URLRequest?
    private var lastBaseURL: URL?
    private var loaded = false
    private var navigation: WKNavigation?
    init(owner: NativeWebSurface) { self.owner = owner }
    func makeView() -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = owner.javaScript
        // Measurement executes in the SDK's isolated world, without enabling
        // page scripts or providing model content with a native action bridge.
        configuration.userContentController.add(self, contentWorld: .defaultClient, name: "openuiSize")
        configuration.userContentController.addUserScript(WKUserScript(source: """
            (()=>{if(!document.querySelector('meta[name="viewport"]')){const m=document.createElement('meta');m.name='viewport';m.content='width=device-width,initial-scale=1';document.head.appendChild(m)}
            let last=0;const report=()=>{const h=Math.ceil(document.documentElement.getBoundingClientRect().height);
            if(h>0&&h!==last){last=h;window.webkit.messageHandlers.openuiSize.postMessage(h)}};
            new ResizeObserver(report).observe(document.documentElement);report()})();
            """, injectionTime: .atDocumentEnd, forMainFrameOnly: true, in: .defaultClient))
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = self
        #if os(iOS)
        view.isOpaque = false; view.backgroundColor = .clear; view.scrollView.backgroundColor = .clear
        #endif
        return view
    }
    func update(_ owner: NativeWebSurface, view: WKWebView) {
        self.owner = owner
        #if os(iOS)
        view.scrollView.isScrollEnabled = owner.scrolls
        view.accessibilityLabel = owner.title
        #else
        view.setAccessibilityLabel(owner.title)
        #endif
        guard !loaded || owner.html != lastHTML || owner.request != lastRequest || owner.baseURL != lastBaseURL else { return }
        loaded = true; lastHTML = owner.html; lastRequest = owner.request; lastBaseURL = owner.baseURL
        if let html = owner.html { navigation = view.loadHTMLString(html, baseURL: owner.baseURL) }
        else if let request = owner.request { navigation = view.load(request) }
    }
    func dispose(_ view: WKWebView) {
        view.stopLoading(); view.navigationDelegate = nil
        view.configuration.userContentController.removeScriptMessageHandler(forName: "openuiSize", contentWorld: .defaultClient)
    }
    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.frameInfo.isMainFrame, let number = message.body as? NSNumber,
              number.doubleValue.isFinite, number.doubleValue > 0 else { return }
        let height = max(1, CGFloat(number.doubleValue))
        if abs(height - owner.measuredHeight) > 0.5 { owner.measuredHeight = height }
    }
    func webView(_ view: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = action.request.url else { decisionHandler(.cancel); return }
        if url.absoluteString == "about:blank" { decisionHandler(.allow); return }
        guard let resolved = owner.resources.request(for: url.absoluteString)?.url else { decisionHandler(.cancel); return }
        if action.navigationType == .linkActivated || action.targetFrame == nil {
            owner.open(resolved); decisionHandler(.cancel)
        } else { decisionHandler(.allow) }
    }
    func webView(_ view: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        if navigation === self.navigation, (error as NSError).code != NSURLErrorCancelled { owner.failed = true }
    }
    func webView(_ view: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        if navigation === self.navigation, (error as NSError).code != NSURLErrorCancelled { owner.failed = true }
    }
}

private struct WebResourceRequestID: Hashable {
    let request: URLRequest?
    let loader: ObjectIdentifier
    let attempt: Int
}
