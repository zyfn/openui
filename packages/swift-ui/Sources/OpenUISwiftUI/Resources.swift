import Foundation
import SwiftUI

/// Resource policy and transport are injected once for an entire rendered tree.
/// Implementations can add authorization or resolve application-owned resources
/// without changing the language, its evaluated values, or individual builders.
public protocol OpenUIResourceLoading: AnyObject {
    func request(for source: String, relativeTo baseURL: URL?) -> URLRequest?
    func data(for request: URLRequest) async throws -> Data
}

public final class OpenUIURLSessionResourceLoader: OpenUIResourceLoading {
    public static let shared = OpenUIURLSessionResourceLoader()
    private let session: URLSession

    public init(session: URLSession = .shared) { self.session = session }

    public func request(for source: String, relativeTo baseURL: URL?) -> URLRequest? {
        guard !source.isEmpty,
              let url = URL(string: source, relativeTo: baseURL)?.absoluteURL,
              let scheme = url.scheme?.lowercased(), ["https", "http"].contains(scheme),
              url.host?.isEmpty == false else { return nil }
        return URLRequest(url: url)
    }

    public func data(for request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        return data
    }
}

public struct OpenUIResourceContext {
    public var baseURL: URL?
    public var loader: any OpenUIResourceLoading

    public init(baseURL: URL? = nil, loader: any OpenUIResourceLoading = OpenUIURLSessionResourceLoader.shared) {
        self.baseURL = baseURL
        self.loader = loader
    }

    public func request(for source: String?) -> URLRequest? {
        source.flatMap { loader.request(for: $0, relativeTo: baseURL) }
    }
}

private struct OpenUIResourceContextKey: EnvironmentKey {
    static let defaultValue = OpenUIResourceContext()
}

extension EnvironmentValues {
    public var openUIResourceContext: OpenUIResourceContext {
        get { self[OpenUIResourceContextKey.self] }
        set { self[OpenUIResourceContextKey.self] = newValue }
    }
}

extension View {
    public func openUIResourceContext(_ context: OpenUIResourceContext) -> some View {
        environment(\.openUIResourceContext, context)
    }
}

struct NativeResourceRequestID: Hashable {
    let request: URLRequest?
    let loader: ObjectIdentifier
    let attempt: Int
}
