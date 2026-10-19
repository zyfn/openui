// OpenUILang — Query/Mutation lifecycle.
//
// Simplified but functional Swift port of runtime/queryManager.ts.
// Tracks per-query {status, data, error}; discards stale results; a missing
// tool surfaces as a tool-not-found OpenUIError and never crashes.
// Mutations run only via `runMutation`; a second run while one is loading is
// rejected. This layer is exercised lightly by Level 1 (queries read defaults;
// no fetch happens) and fully by the SwiftUI layer later.

import Foundation

/// Tool backend for Query()/Mutation() calls. Framework-agnostic — works
/// with MCP, REST, GraphQL, or any backend.
public protocol ToolProvider {
    func callTool(name: String, arguments: [String: Value]) async throws -> Value
}

/// Throw this from a `ToolProvider` to report a tool-not-found OpenUIError
/// (code `tool-not-found`) instead of a generic tool error.
public struct ToolNotFoundError: Error, Sendable {
    public var toolName: String
    public var availableTools: [String]
    public init(toolName: String, availableTools: [String] = []) {
        self.toolName = toolName
        self.availableTools = availableTools
    }
}

public enum QueryStatus: String, Sendable {
    case idle
    case loading
    case success
    case error
}

/// Per-query {status, data, error}. `data` is the last good fetch result, or
/// the declared defaults before anything has resolved.
public struct QueryState: Sendable {
    public var status: QueryStatus
    public var data: Value?
    public var error: OpenUIError?
    public init(status: QueryStatus, data: Value? = nil, error: OpenUIError? = nil) {
        self.status = status
        self.data = data
        self.error = error
    }
}

/// Per-mutation {status, data, error}.
public struct MutationState: Sendable {
    public var status: QueryStatus
    public var data: Value?
    public var error: OpenUIError?
    public init(status: QueryStatus, data: Value? = nil, error: OpenUIError? = nil) {
        self.status = status
        self.data = data
        self.error = error
    }
}

public final class QueryManager {
    /// Dictionary-backed tool provider: tool name → implementation.
    public typealias ToolFn = @Sendable ([String: Value]) async throws -> Value

    private struct QueryEntry {
        var toolName: String
        var args: [String: Value]
        var defaults: Value
        var status: QueryStatus
        var data: Value?
        var error: OpenUIError?
        var generation: Int
    }

    private struct MutationEntry {
        var toolName: String
        var status: QueryStatus
        var data: Value?
        var error: OpenUIError?
        var generation: Int
    }

    private let lock = NSLock()
    private var provider: ToolProvider?
    private var tools: [String: ToolFn]?
    private var queries: [String: QueryEntry] = [:]
    private var mutations: [String: MutationEntry] = [:]
    private var disposed = false

    /// Create with a `ToolProvider` (may be nil: queries then read defaults).
    public init(provider: ToolProvider?) {
        self.provider = provider
    }

    /// Create with a plain dictionary of tool implementations.
    public init(tools: [String: ToolFn]) {
        self.tools = tools
    }

    // MARK: - Queries

    /// Fire (or re-fire) a query fetch. Returns immediately; the result lands
    /// in `queryState(for:)`. A re-run while a fetch is in-flight marks the
    /// older fetch stale — its result is discarded on arrival.
    ///
    /// With no tool backend (neither a provider nor a tools dictionary), no
    /// fetch is attempted — the query stays idle and `queryState(for:)` reads
    /// defaults. This mirrors upstream's null-provider behavior (Level 1:
    /// no fetch).
    public func runQuery(statementId: String, tool: String, args: Value, defaults: Value, onSettled: (@Sendable () -> Void)? = nil) {
        let argDict = objectArgs(args)
        let generation: Int
        let hasBackend: Bool
        lock.lock()
        if disposed { lock.unlock(); return }
        var entry = queries[statementId] ?? QueryEntry(
            toolName: tool, args: argDict, defaults: defaults,
            status: .idle, data: nil, error: nil, generation: 0)
        entry.toolName = tool
        entry.args = argDict
        entry.defaults = defaults
        entry.generation += 1
        hasBackend = tools != nil || provider != nil
        entry.status = hasBackend ? .loading : .idle
        generation = entry.generation
        queries[statementId] = entry
        lock.unlock()

        guard hasBackend else { return }

        Task { [weak self] in
            guard let self = self else { return }
            let result: Result<Value, Error>
            do {
                result = .success(try await self.callTool(name: tool, args: argDict))
            } catch {
                result = .failure(error)
            }
            self.finishQuery(statementId: statementId, generation: generation, result: result)
            onSettled?()
        }
    }

    /// Current per-query {status, data, error}. `data` falls back to the
    /// declared defaults until a fetch resolves.
    public func queryState(for statementId: String) -> QueryState? {
        lock.lock(); defer { lock.unlock() }
        guard let e = queries[statementId] else { return nil }
        return QueryState(status: e.status, data: e.data ?? e.defaults, error: e.error)
    }

    // MARK: - Mutations

    /// Run a mutation and await its outcome. A second call for the same
    /// statement while one is loading is rejected: the current loading state
    /// is returned and the tool is not called again.
    ///
    /// With no tool backend, returns `.idle` without calling anything
    /// (mirrors upstream's null-provider early return).
    @discardableResult
    public func runMutation(statementId: String, tool: String, args: Value) async -> MutationState {
        let argDict = objectArgs(args)
        let generation: Int
        lock.lock()
        if disposed {
            lock.unlock()
            return MutationState(status: .idle)
        }
        if tools == nil && provider == nil {
            lock.unlock()
            return MutationState(status: .idle)
        }
        var entry = mutations[statementId] ?? MutationEntry(
            toolName: tool, status: .idle, data: nil, error: nil, generation: 0)
        if entry.status == .loading {
            let current = MutationState(status: entry.status, data: entry.data, error: entry.error)
            lock.unlock()
            return current // rejected: already loading
        }
        entry.toolName = tool
        entry.status = .loading
        entry.error = nil
        entry.generation += 1
        generation = entry.generation
        mutations[statementId] = entry
        lock.unlock()

        let result: Result<Value, Error>
        do {
            result = .success(try await callTool(name: tool, args: argDict))
        } catch {
            result = .failure(error)
        }

        lock.lock(); defer { lock.unlock() }
        // Stale (superseded/disposed) results are discarded.
        guard !disposed, var e = mutations[statementId], e.generation == generation else {
            return MutationState(status: .idle)
        }
        switch result {
        case .success(let data):
            e.status = .success
            e.data = data
            e.error = nil
        case .failure(let error):
            e.status = .error
            e.error = toolOpenUIError(toolName: tool, statementId: statementId, component: "Mutation", error: error)
        }
        mutations[statementId] = e
        return MutationState(status: e.status, data: e.data, error: e.error)
    }

    /// Current per-mutation {status, data, error}.
    public func mutationState(for statementId: String) -> MutationState? {
        lock.lock(); defer { lock.unlock() }
        guard let e = mutations[statementId] else { return nil }
        return MutationState(status: e.status, data: e.data, error: e.error)
    }

    // MARK: - Lifecycle

    /// Stop all in-flight work; later completions are discarded.
    public func dispose() {
        lock.lock(); defer { lock.unlock() }
        disposed = true
    }

    // MARK: - Private

    private func callTool(name: String, args: [String: Value]) async throws -> Value {
        if let tools = tools, let fn = tools[name] {
            return try await fn(args)
        }
        if let tools = tools {
            throw ToolNotFoundError(toolName: name, availableTools: tools.keys.sorted())
        }
        if let provider = provider {
            return try await provider.callTool(name: name, arguments: args)
        }
        throw ToolNotFoundError(toolName: name, availableTools: [])
    }

    private func finishQuery(statementId: String, generation: Int, result: Result<Value, Error>) {
        lock.lock(); defer { lock.unlock() }
        // Stale-result discard: the query was re-run or disposed while in-flight.
        guard !disposed, var e = queries[statementId], e.generation == generation else { return }
        switch result {
        case .success(let data):
            e.status = .success
            e.data = data
            e.error = nil
        case .failure(let error):
            e.status = .error
            // Last good data is kept (mirrors upstream: settled data stays
            // visible while the error is recorded).
            e.error = toolOpenUIError(toolName: e.toolName, statementId: statementId, component: "Query", error: error)
        }
        queries[statementId] = e
    }

    private func toolOpenUIError(toolName: String, statementId: String, component: String, error: Error) -> OpenUIError {
        if let notFound = error as? ToolNotFoundError {
            return OpenUIError(
                source: component == "Mutation" ? .mutation : .query,
                code: .toolNotFound,
                message: "\(component) tool \"\(toolName)\" not found",
                statementId: statementId,
                component: component,
                toolName: toolName,
                hint: notFound.availableTools.isEmpty
                    ? nil
                    : "Available tools: \(notFound.availableTools.joined(separator: ", "))")
        }
        return OpenUIError(
            source: component == "Mutation" ? .mutation : .query,
            code: .toolError,
            message: "\(component) \"\(toolName)\" failed: \(String(describing: error))",
            statementId: statementId,
            component: component,
            toolName: toolName)
    }

    private func objectArgs(_ args: Value) -> [String: Value] {
        guard case .object(let fields) = args else { return [:] }
        return Dictionary(uniqueKeysWithValues: fields.map { ($0.key, $0.value) })
    }
}
