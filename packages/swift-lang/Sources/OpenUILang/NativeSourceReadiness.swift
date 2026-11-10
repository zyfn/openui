/// Native presentation metadata. This tree is not a Lang value, schema field,
/// serialized AST field, or change to expression evaluation.
public struct NativeSourceReadiness: Sendable, Equatable {
    public let complete: Bool
    public let closed: Bool
    public let expectedCount: Int?
    public let queryDependencies: [OpenUIString]
    public let queryDependenciesObserved: Bool
    /// Original array positions mapped to retained protocol values. Nil entries
    /// were omitted by materialization; pendingChildren may describe their
    /// already-declared component without inserting it into the Lang tree.
    public let valueIndices: [Int?]?
    public let pendingChildren: [Int: NativeSourceReadiness]
    public let placeholder: NativeComponentPlaceholder?
    public let children: [OpenUIString: NativeSourceReadiness]

    public init(complete: Bool, closed: Bool, children: [OpenUIString: NativeSourceReadiness] = [:], expectedCount: Int? = nil, queryDependencies: [OpenUIString] = [], queryDependenciesObserved: Bool = false, valueIndices: [Int?]? = nil, pendingChildren: [Int: NativeSourceReadiness] = [:], placeholder: NativeComponentPlaceholder? = nil) {
        self.complete = complete; self.closed = closed; self.children = children
        self.expectedCount = expectedCount
        self.queryDependencies = queryDependencies
        self.queryDependenciesObserved = queryDependenciesObserved
        self.valueIndices = valueIndices; self.pendingChildren = pendingChildren; self.placeholder = placeholder
    }
    public subscript(_ key: String) -> Self {
        children[OpenUIString(key)] ?? .init(complete: complete, closed: complete)
    }
    public subscript(_ index: Int) -> Self { self[String(index)] }
}

/// A native-only layout hint for a known declaration whose required data has
/// not materialized. It contains committed scalar layout properties, no actions.
public struct NativeComponentPlaceholder: Sendable, Equatable {
    public let typeName: String
    public let statementId: String?
    public let properties: [OpenUIString: Value]
    public init(typeName: String, statementId: String? = nil, properties: [OpenUIString: Value] = [:]) {
        self.typeName = typeName; self.statementId = statementId; self.properties = properties
    }
}
