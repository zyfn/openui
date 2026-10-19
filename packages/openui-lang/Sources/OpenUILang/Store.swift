// OpenUILang — Reactive state store.
//
// Swift port of runtime/store.ts `createStore()`. A flat map of `$variable`
// values plus a `pristine` set: keys still holding their declared default,
// which a later parse may still replace (e.g. a value read from a truncated
// statement while streaming).

import Foundation

/// Concrete `StateStore`. Mirrors `createStore()` in runtime/store.ts.
///
/// Note: the TS store also supports `subscribe`/`notify` for reactive UI
/// frameworks. Reactivity is the SwiftUI layer's job, so this port keeps only
/// the data semantics (get/set/initialize/snapshot/dispose).
public final class OUIStateStore: StateStore {
    private var state: [String: Value] = [:]
    /// Keys still holding their declared default; a later parse may replace them.
    private var pristine: Set<String> = []

    public init() {}

    public func get(_ name: String) -> Value? {
        state[name]
    }

    public func set(_ name: String, value: Value, pristine isPristine: Bool) {
        // The pristine flag is updated even when the value doesn't change
        // (mirrors the TS implementation's ordering).
        if isPristine { pristine.insert(name) } else { pristine.remove(name) }

        let existing = state[name]
        // Object.is(existing, value) — scalar/identity no-op.
        // In Swift, Value has value semantics, so deep equality subsumes both
        // the Object.is check and the TS shallow object-compare (form data):
        // anything the TS version would skip as a no-op is also == here.
        if let existingValue = existing, existingValue == value { return }

        state[name] = value
    }

    public func initialize(defaults: [(String, Materialized)], persisted: [String: Value]) {
        // Persisted values win and clear pristine; defaults fill missing keys
        // as pristine, or replace pristine keys when different. User-set
        // (non-pristine) values are never overwritten, and keys are never
        // deleted: declarations can briefly disappear while streaming.
        for (key, value) in persisted {
            pristine.remove(key)
            if state[key] != value { state[key] = value }
        }
        for (key, materialized) in defaults {
            // .expr defaults can't be materialized to a plain value; leave the
            // key untouched (the evaluator resolves expressions at read time).
            guard let value = materializedToPlain(materialized) else { continue }
            if state[key] == nil {
                state[key] = value
                pristine.insert(key)
            } else if pristine.contains(key), state[key] != value {
                state[key] = value
            }
        }
    }

    public func snapshot() -> [String: Value] {
        state
    }

    public func dispose() {
        state.removeAll()
        pristine.removeAll()
    }
}

/// Create a new reactive state store. Mirrors `createStore()`.
public func createStore() -> StateStore {
    OUIStateStore()
}
