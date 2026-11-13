import SwiftUI
import WebKit
import os
#if os(iOS)
import UIKit
typealias MathPlatformView = UIView
typealias MathPlatformImage = UIImage
#else
import AppKit
typealias MathPlatformView = NSView
typealias MathPlatformImage = NSImage
#endif

struct NativeMathImage: @unchecked Sendable {
  let image: MathPlatformImage
  let size: CGSize
  let baseline: CGFloat
  @MainActor func swiftUIImage(label: String) -> Image {
    #if os(iOS)
    let adjusted = image.withBaselineOffset(fromBottom: baseline)
    adjusted.accessibilityLabel = label
    return Image(uiImage: adjusted)
    #else
    return Image(nsImage: image)
    #endif
  }
}

/// Rasterization stages contain no TeX, URLs or user content. They are retained
/// for a single job and logged on failure so timeouts identify their boundary.
enum NativeMathRenderPhase: String {
  case waitingForHost, loading, awaitingFonts, measuring, snapshotting, completed
}

/// A message-owned renderer. KaTeX supplies the layout; WebKit rasterizes only
/// the trusted, self-contained equation and bundled fonts. Paragraphs, tables,
/// links and controls remain native. No external math resource is requested.
@MainActor final class NativeMathRenderer: ObservableObject {
  private struct Key: Hashable {
    let descriptor: NativeMathDescriptor
    let fontSize: CGFloat
    let color: String
  }
  private final class Pending {
    let id = UUID()
    var task: Task<Void, Never>?
    var waiters: [UUID: CheckedContinuation<NativeMathImage, Error>] = [:]
  }
  private static let admission = NativeResourceAdmission(maximum: 1)
  private weak var host: MathPlatformView?
  private var jobs: [UUID: NativeMathJob] = [:]
  private var pending: [Key: Pending] = [:]
  private var cache: [Key: NativeMathImage] = [:]
  private var costs: [Key: Int] = [:]
  private var order: [Key] = []
  private var cacheBytes = 0
  private var generation = 0
  var pendingRequestCount: Int { pending.count }
  var pendingSubscriberCount: Int { pending.values.reduce(0) { $0 + $1.waiters.count } }
  var cachedPixelBytes: Int { cacheBytes }
  private(set) var lastJobPhases: [NativeMathRenderPhase] = []
  private(set) var lastFailurePhase: NativeMathRenderPhase?
  private(set) var rasterizationCount = 0

  func attach(_ view: MathPlatformView) {
    // A detached old host must not replace an already attached new host.
    guard view.window != nil else {
      if host == nil { host = view }
      return
    }
    host = view
    for job in Array(jobs.values) { job.start(in: view) }
  }
  func detach(_ view: MathPlatformView) {
    // An old representable may dismantle after its replacement is attached.
    guard host === view else { return }
    host = nil
    cancel()
  }
  func cancel() {
    generation &+= 1
    let groups = Array(pending.values); pending.removeAll()
    for group in groups {
      group.task?.cancel(); group.task = nil
      for waiter in group.waiters.values { waiter.resume(throwing: CancellationError()) }
      group.waiters.removeAll()
    }
    for job in Array(jobs.values) { job.finish(.failure(CancellationError())) }
    jobs.removeAll()
  }
  func image(for descriptor: NativeMathDescriptor, fontSize: CGFloat, color: String) async throws -> NativeMathImage {
    try Task.checkCancellation()
    guard descriptor.tex.utf16.count <= 16_384, fontSize.isFinite, fontSize > 0, fontSize <= 512,
      color.range(of: #"^#[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?$"#, options: .regularExpression) != nil else {
      throw URLError(.dataLengthExceedsMaximum)
    }
    let key = Key(descriptor: descriptor, fontSize: fontSize, color: color)
    if let value = cache[key] {
      order.removeAll { $0 == key }; order.append(key)
      return value
    }
    let waiterID = UUID(), epoch = generation
    let image: NativeMathImage = try await withTaskCancellationHandler(operation: {
      try await withCheckedThrowingContinuation { continuation in
        guard !Task.isCancelled else { continuation.resume(throwing: CancellationError()); return }
        if let group = pending[key] { group.waiters[waiterID] = continuation; return }
        let group = Pending(); group.waiters[waiterID] = continuation; pending[key] = group
        let id = group.id
        group.task = Task { @MainActor [weak self] in
          let result: Result<NativeMathImage, Error>
          do {
            try await Self.admission.acquire()
            defer { Task { await Self.admission.release() } }
            try Task.checkCancellation()
            let html = try await Task.detached(priority: .userInitiated) {
              try NativeRichTextEngine.shared.mathHTML(descriptor)
            }.value
            try Task.checkCancellation()
            guard html.utf8.count <= 1_000_000, let self, self.generation == epoch else { throw CancellationError() }
            result = .success(try await self.render(html: html, fontSize: fontSize, color: color, id: id))
          } catch { result = .failure(error) }
          self?.finish(key, id: id, epoch: epoch, result: result)
        }
      }
    }, onCancel: { [weak self] in
      Task { @MainActor in self?.cancelWaiter(key, id: waiterID) }
    })
    try Task.checkCancellation()
    guard generation == epoch else { throw CancellationError() }
    return image
  }
  private func render(html: String, fontSize: CGFloat, color: String, id: UUID) async throws -> NativeMathImage {
    try await withTaskCancellationHandler(operation: {
      try await withCheckedThrowingContinuation { continuation in
        guard !Task.isCancelled else { continuation.resume(throwing: CancellationError()); return }
        let epoch = generation
        lastJobPhases = []; lastFailurePhase = nil
        let job = NativeMathJob(html: html, fontSize: fontSize, color: color,
          progress: { [weak self] phase in
            guard let self, self.generation == epoch else { return }
            self.lastJobPhases.append(phase)
          }, completion: { [weak self] result, phase in
            self?.jobs.removeValue(forKey: id)
            if let self, self.generation == epoch {
              if case .success = result { self.rasterizationCount += 1 }
              if case .failure(let error) = result, !(error is CancellationError) { self.lastFailurePhase = phase }
            }
            continuation.resume(with: result)
          })
        jobs[id] = job
        if let host, host.window != nil { job.start(in: host) }
      }
    }, onCancel: { [weak self] in
      Task { @MainActor in self?.jobs[id]?.finish(.failure(CancellationError())) }
    })
  }
  private func cancelWaiter(_ key: Key, id: UUID) {
    guard let group = pending[key], let waiter = group.waiters.removeValue(forKey: id) else { return }
    waiter.resume(throwing: CancellationError())
    if group.waiters.isEmpty {
      pending.removeValue(forKey: key); group.task?.cancel(); group.task = nil
      jobs[group.id]?.finish(.failure(CancellationError()))
    }
  }
  private func finish(_ key: Key, id: UUID, epoch: Int, result: Result<NativeMathImage, Error>) {
    guard generation == epoch, let group = pending[key], group.id == id else { return }
    pending.removeValue(forKey: key); group.task = nil
    if case .success(let image) = result {
      #if os(iOS)
      let pixels = image.image.size.width * image.image.scale * image.image.size.height * image.image.scale
      #else
      let pixels = image.image.representations.map { Double($0.pixelsWide) * Double($0.pixelsHigh) }.max() ?? 0
      #endif
      let cost = Int(min(Double(16 * 1024 * 1024 + 1), max(0, Double(pixels) * 4)))
      if cost <= 16 * 1024 * 1024 {
        cacheBytes -= costs[key] ?? 0; cacheBytes += cost
        cache[key] = image; costs[key] = cost
        order.removeAll { $0 == key }; order.append(key)
        while order.count > 32 || cacheBytes > 16 * 1024 * 1024 {
          let old = order.removeFirst(); cache.removeValue(forKey: old)
          cacheBytes -= costs.removeValue(forKey: old) ?? 0
        }
      }
    }
    for waiter in group.waiters.values { waiter.resume(with: result) }
    group.waiters.removeAll()
  }
}

@MainActor private final class NativeMathJob: NSObject, WKNavigationDelegate {
  private static let logger = Logger(subsystem: "dev.openui.swift", category: "Math")
  private let html: String
  private let fontSize: CGFloat
  private let color: String
  private let progress: (NativeMathRenderPhase) -> Void
  private var phase: NativeMathRenderPhase = .waitingForHost
  private var completion: ((Result<NativeMathImage, Error>, NativeMathRenderPhase) -> Void)?
  private var webView: WKWebView?
  private var timeout: Task<Void, Never>?

  init(html: String, fontSize: CGFloat, color: String,
       progress: @escaping (NativeMathRenderPhase) -> Void,
       completion: @escaping (Result<NativeMathImage, Error>, NativeMathRenderPhase) -> Void) {
    self.html = html; self.fontSize = fontSize; self.color = color
    self.progress = progress; self.completion = completion
    super.init()
    progress(.waitingForHost)
    timeout = Task { @MainActor [weak self] in
      do { try await Task.sleep(nanoseconds: 10_000_000_000) } catch { return }
      self?.finish(.failure(URLError(.timedOut)))
    }
  }
  private func advance(_ phase: NativeMathRenderPhase) {
    self.phase = phase
    progress(phase)
  }
  func start(in host: MathPlatformView) {
    guard host.window != nil, completion != nil else { return }
    if let view = webView {
      if view.superview !== host { host.addSubview(view) }
      return
    }
    guard let url = NativeControlResources.bundle.url(forResource: "rich-math", withExtension: "css"),
      let css = try? String(contentsOf: url, encoding: .utf8)
    else { finish(.failure(NativeRichTextError.missingResource)); return }
    let configuration = WKWebViewConfiguration()
    configuration.websiteDataStore = .nonPersistent()
    let view = WKWebView(frame: CGRect(x: 0, y: 0, width: 1024, height: 512), configuration: configuration)
    view.navigationDelegate = self
    #if os(iOS)
    view.isOpaque = false; view.backgroundColor = .clear
    #endif
    webView = view
    host.addSubview(view)
    advance(.loading)
    let document = """
      <!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1">
      <meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; font-src data:; script-src 'none'">
      <style>\(css)
      html,body{margin:0;padding:0;background:transparent;font-size:\(fontSize)px;color:\(color)}
      #equation{display:inline-block;padding:1px;white-space:nowrap} .katex-display{margin:0}
      #baseline{display:inline-block;width:0;height:0;vertical-align:baseline}</style>
      </head><body><span id="equation">\(html)<span id="baseline"></span></span></body></html>
      """
    view.loadHTMLString(document, baseURL: nil)
  }
  func webView(_ view: WKWebView, didFinish navigation: WKNavigation!) {
    guard webView === view, completion != nil, phase == .loading else { return }
    advance(.awaitingFonts)
    // This host is deliberately clipped/near-transparent. Waiting for rAF or
    // a visible screen refresh can starve forever when WebKit throttles it.
    // Native navigation + fonts-ready + forced layout is the readiness barrier.
    view.callAsyncJavaScript("""
      const equation = document.getElementById('equation');
      equation.getBoundingClientRect();
      await document.fonts.ready;
      const r = equation.getBoundingClientRect();
      const b = document.getElementById('baseline').getBoundingClientRect();
      return {width:Math.ceil(r.width), height:Math.ceil(r.height), baseline:r.bottom-b.top};
      """, arguments: [:], in: nil, in: .defaultClient) { [weak self, weak view] result in
      Task { @MainActor in
        guard let self, let view, self.webView === view, self.completion != nil else { return }
        switch result {
        case .success(let value):
          guard let metrics = value as? [String: NSNumber] else {
            self.finish(.failure(URLError(.cannotDecodeContentData))); return
          }
          self.prepareSnapshot(metrics, in: view)
        case .failure(let error): self.finish(.failure(error))
        }
      }
    }
  }
  private func prepareSnapshot(_ metrics: [String: NSNumber], in view: WKWebView) {
    let width = metrics["width"]?.doubleValue ?? 0, height = metrics["height"]?.doubleValue ?? 0
    let baseline = metrics["baseline"]?.doubleValue ?? 0
    guard width.isFinite, height.isFinite, baseline.isFinite, width > 0, height > 0,
      width <= 8192, height <= 4096, width * height <= 4_000_000 else {
      finish(.failure(URLError(.dataLengthExceedsMaximum))); return
    }
    advance(.measuring)
    let size = CGSize(width: width, height: height)
    view.frame.size = size
    #if os(iOS)
    view.setNeedsLayout(); view.layoutIfNeeded()
    #else
    view.needsLayout = true; view.layoutSubtreeIfNeeded()
    #endif
    // Resize first, then cross the WebContent layout boundary once more. There
    // is no second parser, animation frame, retry loop or increased deadline.
    view.callAsyncJavaScript("document.getElementById('equation').getBoundingClientRect(); return true;",
      arguments: [:], in: nil, in: .defaultClient) { [weak self, weak view] result in
      Task { @MainActor in
        guard let self, let view, self.webView === view, self.completion != nil else { return }
        if case .failure(let error) = result { self.finish(.failure(error)); return }
        self.takeSnapshot(in: view, size: size, baseline: CGFloat(min(height, max(0, baseline))))
      }
    }
  }
  private func takeSnapshot(in view: WKWebView, size: CGSize, baseline: CGFloat) {
    advance(.snapshotting)
    let configuration = WKSnapshotConfiguration()
    configuration.rect = CGRect(origin: .zero, size: size)
    // Fonts and layout have already completed. Do not require an on-screen
    // compositing update from the hidden rasterization host.
    configuration.afterScreenUpdates = false
    view.takeSnapshot(with: configuration) { [weak self, weak view] image, error in
      Task { @MainActor in
        guard let self, let view, self.webView === view, self.completion != nil else { return }
        if let image {
          self.finish(.success(NativeMathImage(image: image, size: size, baseline: baseline)))
        } else { self.finish(.failure(error ?? URLError(.cannotDecodeContentData))) }
      }
    }
  }
  func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { finish(.failure(error)) }
  func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { finish(.failure(error)) }
  func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
    finish(.failure(NSError(domain: WKErrorDomain, code: WKError.Code.webContentProcessTerminated.rawValue)))
  }
  func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
    decisionHandler(navigationAction.request.url?.scheme == "about" ? .allow : .cancel)
  }
  func finish(_ result: Result<NativeMathImage, Error>) {
    guard let completion else { return }
    self.completion = nil
    if case .success = result { advance(.completed) }
    if case .failure(let error) = result, !(error is CancellationError) {
      let code = (error as NSError).code
      Self.logger.error("Equation rasterization failed at \(self.phase.rawValue, privacy: .public); code=\(code)")
    }
    timeout?.cancel(); timeout = nil
    webView?.navigationDelegate = nil
    webView?.stopLoading(); webView?.removeFromSuperview(); webView = nil
    completion(result, phase)
  }
}

#if os(iOS)
private final class NativeMathHostView: UIView {
  weak var renderer: NativeMathRenderer?
  override func didMoveToWindow() { super.didMoveToWindow(); renderer?.attach(self) }
}
struct NativeMathHost: UIViewRepresentable {
  let renderer: NativeMathRenderer
  func makeUIView(context: Context) -> UIView {
    let view = NativeMathHostView(); view.renderer = renderer; view.clipsToBounds = true
    renderer.attach(view); return view
  }
  func updateUIView(_ view: UIView, context: Context) {
    if let host = view as? NativeMathHostView {
      if host.renderer !== renderer { host.renderer?.detach(host); host.renderer = renderer }
    }
    renderer.attach(view)
  }
  static func dismantleUIView(_ view: UIView, coordinator: ()) {
    if let host = view as? NativeMathHostView { host.renderer?.detach(host); host.renderer = nil }
  }
}
#else
private final class NativeMathHostView: NSView {
  weak var renderer: NativeMathRenderer?
  override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); renderer?.attach(self) }
}
struct NativeMathHost: NSViewRepresentable {
  let renderer: NativeMathRenderer
  func makeNSView(context: Context) -> NSView {
    let view = NativeMathHostView(); view.renderer = renderer; view.wantsLayer = true; view.layer?.masksToBounds = true
    renderer.attach(view); return view
  }
  func updateNSView(_ view: NSView, context: Context) {
    if let host = view as? NativeMathHostView {
      if host.renderer !== renderer { host.renderer?.detach(host); host.renderer = renderer }
    }
    renderer.attach(view)
  }
  static func dismantleNSView(_ view: NSView, coordinator: ()) {
    if let host = view as? NativeMathHostView { host.renderer?.detach(host); host.renderer = nil }
  }
}
#endif
