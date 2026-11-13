import OpenUILang

/// Narrows the existing live-snapshot search without deciding which snapshot
/// is safe to use. Property and readiness checks remain in OpenUIState.
struct NativeLiveElementIndex {
  private struct Key: Hashable {
    let typeName: String
    let statementID: String?

    init(_ element: EvaluatedElement) {
      typeName = element.typeName
      statementID = element.statementId
    }
  }

  private var buckets: [Key: [EvaluatedElement]] = [:]

  mutating func insert(_ element: EvaluatedElement) {
    buckets[Key(element), default: []].append(element)
  }

  func candidates(for element: EvaluatedElement) -> [EvaluatedElement] {
    buckets[Key(element)] ?? []
  }

  mutating func removeAll(keepingCapacity: Bool = false) {
    buckets.removeAll(keepingCapacity: keepingCapacity)
  }
}
