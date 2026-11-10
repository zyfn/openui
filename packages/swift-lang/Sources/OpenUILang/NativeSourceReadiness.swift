/// Native presentation metadata. This tree is not a Lang value, schema field,
/// serialized AST field, or change to expression evaluation.
public struct NativeSourceReadiness: Sendable, Equatable {
    public let complete: Bool
    public let closed: Bool
    public let expectedCount: Int?
    public let queryDependencies: [OpenUIString]
    public let children: [OpenUIString: NativeSourceReadiness]

    public init(complete: Bool, closed: Bool, children: [OpenUIString: NativeSourceReadiness] = [:], expectedCount: Int? = nil, queryDependencies: [OpenUIString] = []) {
        self.complete = complete; self.closed = closed; self.children = children
        self.expectedCount = expectedCount
        self.queryDependencies = queryDependencies
    }
    public subscript(_ key: String) -> Self {
        children[OpenUIString(key)] ?? .init(complete: complete, closed: complete)
    }
    public subscript(_ index: Int) -> Self { self[String(index)] }
}
