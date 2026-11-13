import Foundation
import ImageIO
import CoreGraphics
import UniformTypeIdentifiers
import XCTest
@testable import OpenUISwiftUI

final class ResourceStoreTests: XCTestCase {
  @MainActor func testReleasingStateCancelsItsPendingResources() async throws {
    let library = try OpenUIStandardComponents.library()
    var state: OpenUIState? = OpenUIState(schema: library.library.toSchema())
    weak var releasedState = state
    let store = try XCTUnwrap(state).resourceStore
    let media = try XCTUnwrap(state).mediaCache
    let started = expectation(description: "both requests started")
    started.expectedFulfillmentCount = 2
    let cancelled = expectation(description: "both owned requests cancelled")
    cancelled.expectedFulfillmentCount = 2
    let loader = SuspendedResourceLoader(started: started, cancelled: cancelled)
    let scope = store.scoped(.init(loader: loader))
    let dataRequest = try XCTUnwrap(scope.request(for: "https://resource.example/data"))
    let imageRequest = try XCTUnwrap(loader.request(for: "https://resource.example/image", relativeTo: nil))
    let dataTask = Task { try await scope.loader.data(for: dataRequest) }
    let imageTask = Task { try await media.resource(
      NativeResourceRequestID(request: imageRequest, loader: ObjectIdentifier(loader), attempt: 0), loader: loader) }
    defer { store.removeAll(); media.removeAll(); dataTask.cancel(); imageTask.cancel() }
    await fulfillment(of: [started], timeout: 2)
    state = nil
    XCTAssertNil(releasedState, "The test tasks must not retain the rendering state")
    await fulfillment(of: [cancelled], timeout: 1)
  }

  @MainActor func testPendingDataIsSharedAndExplicitReloadBypassesTheCompletedCache() async throws {
    let loader = ByteLoader()
    let store = NativeResourceStore()
    let context = store.scoped(.init(loader: loader))
    let request = try XCTUnwrap(context.request(for: "https://resource.example/diagram"))
    let first = Task { try await context.loader.data(for: request) }
    let second = Task { try await context.loader.data(for: request) }
    let a = try await first.value, b = try await second.value
    XCTAssertEqual(a, b); XCTAssertEqual(loader.count, 1)
    _ = try await context.loader.data(for: request)
    XCTAssertEqual(loader.count, 1)
    var fresh = request; fresh.cachePolicy = .reloadIgnoringLocalCacheData
    _ = try await context.loader.data(for: fresh)
    _ = try await context.loader.data(for: fresh)
    XCTAssertEqual(loader.count, 3, "A user reload must not replay cached invalid bytes forever")
  }
  @MainActor func testResetRejectsRequestsFromThePreviousPresentation() async throws {
    let loader = ByteLoader(), store = NativeResourceStore()
    let original = OpenUIResourceContext(loader: loader)
    let old = store.scoped(original)
    let request = try XCTUnwrap(old.request(for: "https://resource.example/diagram"))
    store.removeAll()
    do { _ = try await old.loader.data(for: request); XCTFail("Old scopes must not refill a reset presentation") }
    catch { XCTAssertTrue(error is CancellationError) }
    XCTAssertEqual(loader.count, 0)
    _ = try await store.scoped(original).loader.data(for: request)
    XCTAssertEqual(loader.count, 1)
  }
  @MainActor func testNestedIndependentScopesDoNotShareAnotherRepliesDataOrCancellation() async throws {
    let loader = ByteLoader(), first = NativeResourceStore(), second = NativeResourceStore()
    let a = first.scoped(.init(loader: loader))
    let b = second.scoped(a)
    let request = try XCTUnwrap(a.request(for: "https://resource.example/diagram"))
    _ = try await a.loader.data(for: request)
    _ = try await b.loader.data(for: request)
    XCTAssertEqual(loader.count, 2, "Independent replies fetch into independent data stores")
    first.removeAll()
    _ = try await b.loader.data(for: request)
    XCTAssertEqual(loader.count, 2, "Resetting one reply cannot discard another reply's data")
  }
  @MainActor func testChangingAuthorizationScopeCannotReuseOrRefillOldBytes() async throws {
    let owner = ScopedFixtureLoader(), store = NativeResourceStore()
    let first = store.scoped(.init(loader: owner))
    let request = try XCTUnwrap(first.request(for: "https://resource.example/private"))
    let a = try await first.loader.data(for: request)
    XCTAssertEqual(a, Data("account-a".utf8))
    owner.account = "account-b"
    XCTAssertNil(first.request(for: "https://resource.example/private"))
    do { _ = try await first.loader.data(for: request); XCTFail("Old authorization is invalid") }
    catch { XCTAssertTrue(error is CancellationError) }
    let b = try await store.scoped(.init(loader: owner)).loader.data(for: request)
    XCTAssertEqual(b, Data("account-b".utf8))
    XCTAssertEqual(owner.calls, 2)
  }

  @MainActor func testCustomLoaderOversizeResultIsRejectedBeforeCaching() async throws {
    let owner = ScopedFixtureLoader(limit: 2), store = NativeResourceStore()
    let scope = store.scoped(.init(loader: owner))
    let request = try XCTUnwrap(scope.request(for: "https://resource.example/private"))
    for _ in 0..<2 {
      do { _ = try await scope.loader.data(for: request); XCTFail("Oversize custom results must not enter cache") }
      catch { XCTAssertEqual((error as? URLError)?.code, .dataLengthExceedsMaximum) }
    }
    XCTAssertEqual(owner.calls, 2)
  }

  func testDefaultDownloadLimitAppliesToAdvertisedAndActualBytes() async throws {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [ResourceFixtureProtocol.self]
    let session = URLSession(configuration: configuration)
    defer { session.invalidateAndCancel() }
    let loader = OpenUIURLSessionResourceLoader(session: session,
      limits: OpenUIResourceLimits(maximumResponseBytes: 32))
    for path in ["advertised", "unknown-length"] {
      let request = try XCTUnwrap(loader.request(for: "https://resource.test/" + path, relativeTo: nil))
      do { _ = try await loader.data(for: request); XCTFail("Bytes must be bounded for " + path) }
      catch { XCTAssertEqual((error as? URLError)?.code, .dataLengthExceedsMaximum) }
    }
    let exact = try XCTUnwrap(loader.request(for: "https://resource.test/exact", relativeTo: nil))
    let bytes = try await loader.data(for: exact)
    XCTAssertEqual(bytes.count, 32, "The maximum itself is accepted")
    let failure = try XCTUnwrap(loader.request(for: "https://resource.test/error", relativeTo: nil))
    do { _ = try await loader.data(for: failure); XCTFail("HTTP errors cannot become image bytes") }
    catch { XCTAssertEqual((error as? URLError)?.code, .badServerResponse) }
  }

  func testRedirectPolicyRejectsDowngradesCredentialsAndUnexpectedOrigins() {
    let from = URL(string: "https://example.com/image")!
    let limits = OpenUIResourceLimits()
    XCTAssertTrue(NativeResourceRedirectPolicy.permitted(from: from,
      to: URL(string: "https://example.com:443/cached"), limits: limits))
    for target in ["http://example.com/image", "https://other.example/image",
                   "file:///secret", "https://user:password@example.com/image", "https://example.com:8443/image"] {
      XCTAssertFalse(NativeResourceRedirectPolicy.permitted(from: from, to: URL(string: target), limits: limits), target)
    }
    var explicit = limits; explicit.allowsCrossOriginRedirects = true
    XCTAssertTrue(NativeResourceRedirectPolicy.permitted(from: from,
      to: URL(string: "https://cdn.example.com/image"), limits: explicit))
    XCTAssertFalse(NativeResourceRedirectPolicy.permitted(from: from,
      to: URL(string: "http://cdn.example.com/image"), limits: explicit))
  }

  @MainActor func testCancellingOneSubscriberDoesNotCancelAnotherAndLastCancellationStopsTransport() async throws {
    let store = NativeResourceStore()
    let started = expectation(description: "transport started once")
    let cancelled = expectation(description: "transport cancelled when last subscriber exits")
    let owner = SuspendedResourceLoader(started: started, cancelled: cancelled)
    let scope = store.scoped(.init(loader: owner))
    let request = try XCTUnwrap(scope.request(for: "https://resource.example/shared"))
    let first = Task { try await scope.loader.data(for: request) }
    let second = Task { try await scope.loader.data(for: request) }
    defer { first.cancel(); second.cancel(); store.removeAll() }
    await fulfillment(of: [started], timeout: 2)
    let joined = expectation(description: "both subscribers joined")
    let observer = Task { @MainActor in
      while !Task.isCancelled && store.pendingSubscriberCount != 2 { await Task.yield() }
      if !Task.isCancelled { joined.fulfill() }
    }
    await fulfillment(of: [joined], timeout: 2)
    observer.cancel()
    first.cancel()
    do { _ = try await first.value; XCTFail("Cancelled subscriber must resume without waiting for transport") }
    catch { XCTAssertTrue(error is CancellationError) }
    XCTAssertFalse(second.isCancelled)
    second.cancel()
    do { _ = try await second.value; XCTFail("Last subscriber must be cancelled") }
    catch { XCTAssertTrue(error is CancellationError) }
    await fulfillment(of: [cancelled], timeout: 2)
  }

  @MainActor func testImageDownsamplingPreservesSourceGeometryAndChecksPixelBudget() async throws {
    let context = try XCTUnwrap(CGContext(data: nil, width: 800, height: 400,
      bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    let image = try XCTUnwrap(context.makeImage())
    let data = NSMutableData()
    let destination = try XCTUnwrap(CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil))
    CGImageDestinationAddImage(destination, image, nil)
    XCTAssertTrue(CGImageDestinationFinalize(destination))
    let loader = OpenUIURLSessionResourceLoader()
    let small = try await NativeMediaCache.prepare(data as Data, loader: loader, targetPixelSize: 80)
    XCTAssertEqual(small.size, CGSize(width: 800, height: 400))
    XCTAssertLessThanOrEqual(small.decodedPixelSize, 80)
    XCTAssertLessThanOrEqual(small.cost, 80 * 80 * 4)
    XCTAssertFalse(small.satisfies(200))
    let strict = OpenUIURLSessionResourceLoader(limits: OpenUIResourceLimits(maximumImageSourcePixels: 100))
    do {
      _ = try await NativeMediaCache.prepare(data as Data, loader: strict, targetPixelSize: 80)
      XCTFail("A large compressed source cannot bypass its source-pixel budget")
    } catch { XCTAssertEqual((error as? URLError)?.code, .cannotDecodeContentData) }
  }

}
private final class ByteLoader: OpenUIResourceLoading {
  private let lock = NSLock()
  private var calls = 0
  var count: Int { lock.lock(); defer { lock.unlock() }; return calls }
  func request(for source: String, relativeTo baseURL: URL?) -> URLRequest? {
    URL(string: source, relativeTo: baseURL).map { URLRequest(url: $0) }
  }
  private func record() { lock.lock(); defer { lock.unlock() }; calls += 1 }
  func data(for request: URLRequest) async throws -> Data {
    record(); try await Task.sleep(nanoseconds: 50_000_000)
    return Data("resource bytes".utf8)
  }
}

private final class SuspendedResourceLoader: OpenUIResourceLoading {
  let started: XCTestExpectation
  let cancelled: XCTestExpectation
  init(started: XCTestExpectation, cancelled: XCTestExpectation) {
    self.started = started; self.cancelled = cancelled
  }
  func request(for source: String, relativeTo baseURL: URL?) -> URLRequest? {
    URL(string: source, relativeTo: baseURL).map { URLRequest(url: $0) }
  }
  func data(for request: URLRequest) async throws -> Data {
    started.fulfill()
    do { try await Task.sleep(nanoseconds: 60_000_000_000) }
    catch { cancelled.fulfill(); throw error }
    return Data()
  }
}

private final class ScopedFixtureLoader: OpenUIResourceLoading {
  var account = "account-a"
  var calls = 0
  var authorizationScopeID: String { account }
  let resourceLimits: OpenUIResourceLimits
  init(limit: Int = 1024) { resourceLimits = OpenUIResourceLimits(maximumResponseBytes: limit) }
  func request(for source: String, relativeTo baseURL: URL?) -> URLRequest? {
    URL(string: source, relativeTo: baseURL).map { URLRequest(url: $0) }
  }
  func data(for request: URLRequest) async throws -> Data { calls += 1; return Data(account.utf8) }
}

private final class ResourceFixtureProtocol: URLProtocol {
  override class func canInit(with request: URLRequest) -> Bool { request.url?.host == "resource.test" }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
  override func startLoading() {
    guard let url = request.url else { return }
    let count = url.path == "/exact" ? 32 : 64
    let headers = url.path == "/advertised" ? ["Content-Length": String(count)] : [:]
    let response = HTTPURLResponse(url: url, statusCode: url.path == "/error" ? 503 : 200,
      httpVersion: "HTTP/1.1", headerFields: headers)!
    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    client?.urlProtocol(self, didLoad: Data(repeating: 7, count: count))
    client?.urlProtocolDidFinishLoading(self)
  }
  override func stopLoading() { }
}


extension ResourceStoreTests {
  @MainActor func testCancelledImageSubscriberFailsWhileOtherSubscriberGetsSharedResult() async throws {
    let cache = NativeMediaCache()
    let started = expectation(description: "one image transport")
    let loader = ControlledImageLoader(started: started)
    let key = NativeResourceRequestID(request: URLRequest(url: URL(string: "https://image.test/shared")!),
      loader: ObjectIdentifier(loader), attempt: 0)
    let first = Task { try await cache.resource(key, loader: loader) }
    let second = Task { try await cache.resource(key, loader: loader) }
    defer { first.cancel(); second.cancel(); cache.removeAll() }
    await fulfillment(of: [started], timeout: 3)
    let joined = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in cache.pendingSubscriberCount == 2 }, object: nil)
    await fulfillment(of: [joined], timeout: 3)
    first.cancel()
    // The cancelled waiter must finish without waiting for bytes to arrive.
    let cancelled = expectation(description: "cancelled waiter returned")
    let observer = Task { @MainActor in
      do { _ = try await first.value; XCTFail("A cancelled image subscriber returned success") }
      catch { XCTAssertTrue(error is CancellationError) }
      cancelled.fulfill()
    }
    await fulfillment(of: [cancelled], timeout: 2)
    XCTAssertEqual(cache.pendingSubscriberCount, 1)
    await loader.gate.release(id: 1)
    let image = try await second.value
    await observer.value
    XCTAssertGreaterThan(image.cost, 0)
    XCTAssertEqual(cache.pendingRequestCount, 0)
    let counts = await loader.gate.counts
    XCTAssertEqual(counts.started, 1)
    XCTAssertEqual(counts.cancelled, 0, "A live subscriber still owns the shared transport")
    XCTAssertNotNil(cache[key])
  }

  @MainActor func testLastImageSubscriberCancellationStopsTransport() async throws {
    let cache = NativeMediaCache()
    let started = expectation(description: "image transport started")
    let cancelled = expectation(description: "last subscriber cancels transport")
    let loader = ControlledImageLoader(started: started, cancelled: cancelled)
    let key = NativeResourceRequestID(request: URLRequest(url: URL(string: "https://image.test/cancel")!),
      loader: ObjectIdentifier(loader), attempt: 0)
    let task = Task { try await cache.resource(key, loader: loader) }
    defer { task.cancel(); cache.removeAll() }
    await fulfillment(of: [started], timeout: 3)
    task.cancel()
    let returned = expectation(description: "last subscriber returned")
    let observer = Task { @MainActor in
      do { _ = try await task.value; XCTFail("Cancelled image returned success") }
      catch { XCTAssertTrue(error is CancellationError) }
      returned.fulfill()
    }
    await fulfillment(of: [cancelled, returned], timeout: 3)
    await loader.gate.release(id: 1) // also drain the fixture if a regression failed the assertions
    await observer.value
    XCTAssertEqual(cache.pendingRequestCount, 0)
    XCTAssertEqual(cache.pendingSubscriberCount, 0)
    XCTAssertNil(cache[key])
  }

  @MainActor func testImageCacheResetCannotBeRefilledByUncooperativeOldTransport() async throws {
    let cache = NativeMediaCache()
    let started = expectation(description: "old and new requests started"); started.expectedFulfillmentCount = 2
    let firstStarted = expectation(description: "old transport started")
    let loader = ControlledImageLoader(started: started, firstStarted: firstStarted, honorsCancellation: false)
    let key = NativeResourceRequestID(request: URLRequest(url: URL(string: "https://image.test/reset")!),
      loader: ObjectIdentifier(loader), attempt: 0)
    let first = Task { try await cache.resource(key, loader: loader) }
    let oldJoined = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in cache.pendingSubscriberCount == 1 }, object: nil)
    await fulfillment(of: [oldJoined], timeout: 3)
    // Wait for transport registration, not just cache registration.
    await fulfillment(of: [firstStarted], timeout: 3)
    cache.removeAll()
    let returned = expectation(description: "reset subscriber returned before old bytes")
    let observer = Task { @MainActor in
      do { _ = try await first.value; XCTFail("Reset must cancel old subscribers") }
      catch { XCTAssertTrue(error is CancellationError) }
      returned.fulfill()
    }
    await fulfillment(of: [returned], timeout: 2)
    let next = Task { try await cache.resource(key, loader: loader) }
    defer { next.cancel(); cache.removeAll() }
    await fulfillment(of: [started], timeout: 3)
    await loader.gate.release(id: 1)
    await loader.gate.release(id: 2)
    _ = try await next.value
    await observer.value
    XCTAssertEqual(cache.pendingRequestCount, 0)
    XCTAssertNotNil(cache[key], "Only the current request may refill the cache")
    let counts = await loader.gate.counts
    XCTAssertEqual(counts.started, 2)
  }

  @MainActor func testAlreadyCancelledImageSubscriberCannotReadCompletedCache() async throws {
    let cache = NativeMediaCache()
    let started = expectation(description: "initial load")
    let loader = ControlledImageLoader(started: started)
    let key = NativeResourceRequestID(request: URLRequest(url: URL(string: "https://image.test/cached")!),
      loader: ObjectIdentifier(loader), attempt: 0)
    let initial = Task { try await cache.resource(key, loader: loader) }
    await fulfillment(of: [started], timeout: 3)
    await loader.gate.release(id: 1)
    _ = try await initial.value
    let cancelled = Task { @MainActor in
      withUnsafeCurrentTask { $0?.cancel() }
      return try await cache.resource(key, loader: loader)
    }
    do { _ = try await cancelled.value; XCTFail("A cache hit must still respect caller cancellation") }
    catch { XCTAssertTrue(error is CancellationError) }
    let counts = await loader.gate.counts
    XCTAssertEqual(counts.started, 1)
    cache.removeAll()
  }
}

private final class ControlledImageLoader: OpenUIResourceLoading {
  let gate: ControlledImageGate
  init(started: XCTestExpectation, cancelled: XCTestExpectation? = nil,
       firstStarted: XCTestExpectation? = nil, honorsCancellation: Bool = true) {
    gate = ControlledImageGate(started: started, cancelled: cancelled,
      firstStarted: firstStarted, honorsCancellation: honorsCancellation)
  }
  func request(for source: String, relativeTo baseURL: URL?) -> URLRequest? {
    URL(string: source, relativeTo: baseURL).map { URLRequest(url: $0) }
  }
  func data(for request: URLRequest) async throws -> Data { try await gate.load() }
}

private actor ControlledImageGate {
  let started: XCTestExpectation
  let cancelled: XCTestExpectation?
  let firstStarted: XCTestExpectation?
  let honorsCancellation: Bool
  private var sequence = 0
  private var cancellationCount = 0
  private var pending: [Int: CheckedContinuation<Data, Error>] = [:]
  var counts: (started: Int, cancelled: Int) { (sequence, cancellationCount) }
  init(started: XCTestExpectation, cancelled: XCTestExpectation?,
       firstStarted: XCTestExpectation?, honorsCancellation: Bool) {
    self.started = started; self.cancelled = cancelled
    self.firstStarted = firstStarted; self.honorsCancellation = honorsCancellation
  }
  func load() async throws -> Data {
    sequence += 1
    let id = sequence
    return try await withTaskCancellationHandler(operation: {
      try await withCheckedThrowingContinuation { continuation in
        pending[id] = continuation
        started.fulfill()
        if id == 1 { firstStarted?.fulfill() }
      }
    }, onCancel: { Task { await self.cancel(id: id) } })
  }
  private func cancel(id: Int) {
    guard pending[id] != nil else { return }
    cancellationCount += 1; cancelled?.fulfill()
    if honorsCancellation { pending.removeValue(forKey: id)?.resume(throwing: CancellationError()) }
  }
  func release(id: Int) {
    // Same valid 1x1 PNG used by native transport fixtures. No network is used.
    let png = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=")!
    pending.removeValue(forKey: id)?.resume(returning: png)
  }
}
