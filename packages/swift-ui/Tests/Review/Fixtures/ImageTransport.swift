import Combine
import Foundation

@MainActor
final class ReviewImageMonitor: ObservableObject {
  static let shared = ReviewImageMonitor()
  @Published var loaded = 0
}

/// Test-only transport for AsyncImage. The standard SDK renderer is unchanged.
final class ReviewImageProtocol: URLProtocol, @unchecked Sendable {
  private static let lock = NSLock()
  private static var attempts: [String: Int] = [:]
  private var delayed: DispatchWorkItem?
  private static let sourceImages = [
    "https://dimg04.c-ctrip.com/images/100i0m000000dvuquABAF_W_640_10000.jpg?proc=autoorient": "detail.jpg",
    "https://www.mct.gov.cn/whzx/whyw/201907/W020190716601079239508.jpg": "object.jpg",
  ]
  override class func canInit(with request: URLRequest) -> Bool {
    request.url?.host == "sdk-fixture.invalid" || sourceImages[request.url?.absoluteString ?? ""] != nil
  }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
  override func startLoading() {
    let args = ProcessInfo.processInfo.arguments
    let mode = args.firstIndex(of: "--media-response").flatMap { $0 + 1 < args.count ? args[$0 + 1] : nil }
    let key = request.url?.absoluteString ?? ""
    Self.lock.lock()
    Self.attempts[key, default: 0] += 1
    let attempt = Self.attempts[key, default: 0]
    Self.lock.unlock()
    if mode == "unavailable" || (mode == "partial" && request.url?.lastPathComponent == "object.jpg")
      || (mode == "retry" && attempt == 1) {
      client?.urlProtocol(self, didFailWithError: URLError(.cannotLoadFromNetwork))
      return
    }
    if mode == "loading" {
      let item = DispatchWorkItem { [weak self] in self?.deliver() }
      delayed = item
      DispatchQueue.global().asyncAfter(deadline: .now() + 30, execute: item)
    } else { deliver() }
  }
  private func deliver() {
    let filename = Self.sourceImages[request.url?.absoluteString ?? ""]
      ?? request.url?.lastPathComponent ?? ""
    let asset = URL(fileURLWithPath: filename)
    guard let url = request.url,
      let file = Bundle.main.url(
        forResource: asset.deletingPathExtension().lastPathComponent,
        withExtension: asset.pathExtension, subdirectory: "Images"),
      let data = try? Data(contentsOf: file),
      let response = HTTPURLResponse(
        url: url, statusCode: 200, httpVersion: "HTTP/1.1",
        headerFields: ["Content-Type": asset.pathExtension == "png" ? "image/png" : "image/jpeg"])
    else {
      client?.urlProtocol(self, didFailWithError: URLError(.fileDoesNotExist))
      return
    }
    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    client?.urlProtocol(self, didLoad: data)
    client?.urlProtocolDidFinishLoading(self)
    Task { @MainActor in ReviewImageMonitor.shared.loaded += 1 }
  }
  override func stopLoading() { delayed?.cancel() }
}
