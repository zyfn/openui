import SwiftUI

/// Table is a read-only comparison surface. Its descendants share this smaller
/// registry, so a Stack or Popover cannot reintroduce an input/action builder.
/// Chart data nodes such as Series remain ordinary props, not rendered children.
public struct OpenUITableCellPolicy: Sendable {
    public let allowedComponents: Set<String>?
    public static let unrestricted = Self(allowedComponents: nil)
    public static let readOnly = Self(allowedComponents: Set(NativeTableCellContent.componentNames))
    public init(allowing components: [String]) { allowedComponents = Set(components) }
    private init(allowedComponents: Set<String>?) { self.allowedComponents = allowedComponents }
}
private struct TableCellPolicyKey: EnvironmentKey {
    static let defaultValue = OpenUITableCellPolicy.unrestricted
}
extension EnvironmentValues {
    public var openUITableCellPolicy: OpenUITableCellPolicy {
        get { self[TableCellPolicyKey.self] }
        set { self[TableCellPolicyKey.self] = newValue }
    }
}
extension View {
    public func openUITableCellPolicy(_ policy: OpenUITableCellPolicy) -> some View {
        environment(\.openUITableCellPolicy, policy)
    }
}

enum NativeTableCellContent {
    static let componentNames = [
        "TextContent", "Icon", "Tag", "Image",
        "MetricIndicatorInline", "MetricIndicatorWithStrikethrough",
        "BarChart", "LineChart", "SVG", "Stack", "Popover",
    ]

    static func registry(from installed: ComponentRegistry, policy: OpenUITableCellPolicy) -> ComponentRegistry {
        guard let allowed = policy.allowedComponents else { return installed }
        var cells = ComponentRegistry()
        for name in allowed { cells[name] = installed[name] }
        return cells
    }

    static func guidance(registered: Set<String>, policy: OpenUITableCellPolicy) -> String {
        let available = (policy.allowedComponents ?? registered).intersection(registered).sorted().joined(separator: ", ")
        let detail = registered.contains("Popover") && policy.allowedComponents?.contains("Popover") != false
            ? " Use Popover for contextual explanations." : ""
        return """
            Table cells are read-only comparisons: use plain text/numbers or these registered \
            components only: \(available). This limit applies recursively to nested cell content. \
            Keep explanations brief and charts compact. Place inputs, forms, submit \
            actions, card shells, maps, web pages, galleries and navigation outside the table; \
            unsupported cell components are not rendered.\(detail)
            """
    }
}
