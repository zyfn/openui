import SwiftUI
import OpenUILang

public enum OpenUIStandardComponents {
    /// Official examples and rules for the complete, pinned general-purpose library.
    /// Pass explicitly to prompt(_:); curate them when deriving a component subset.
    public static var promptOptions: PromptOptions { OpenUIReference.promptOptions }

    public static func library(id: String? = nil) throws -> OpenUIComponentLibrary {
        try OpenUIComponentLibrary(components: components, root: "Stack", id: id, componentGroups: OpenUIReference.groups + [ComponentGroup(name: "Maps and Diagrams", components: ["Map", "MapPoint", "SVG"], notes: ["Map displays locations, not navigation or live traffic. MapKit requires iOS 17 or macOS 14.", "SVG requires a valid viewBox. Use inline content or HTTPS src, not both; active content and external references are rejected."])])
    }
    public static var components: [OpenUIComponent] {
        let implementations = OpenUISelectionComponents.components + OpenUIFormComponents.components
            + OpenUIDisplayComponents.components + OpenUIContentComponents.components
            + OpenUIChartComponents.components + [
            OpenUIReference.component("Stack") {
                OpenUIStack(context: $0, wrapJustifyBetweenAsStart: true)
            },
            OpenUIReference.component("TextContent") { context in
                NativeMarkdownText(text: context.string("text") ?? "", mode: .textContent,
                    style: .textContent(context.presentationString("size"), theme: context.theme))
            },
            OpenUIReference.component("Image") { NativeContentImage(context: $0) },
            OpenUIReference.component("Button") { OpenUINativeButton(context: $0) },
            OpenUIReference.component("Card") { OpenUIStyledCard(context: $0) }
        ]
        let byName = Dictionary(uniqueKeysWithValues: implementations.map { ($0.definition.name, $0) })
        let pinned = OpenUIReference.definitions.map { definition in
            guard let component = byName[definition.name] else { preconditionFailure("Missing native renderer: " + definition.name) }
            return component
        }
        let all = pinned + [OpenUIGeographicComponents.map, OpenUIGeographicComponents.mapPoint, OpenUIGraphicComponents.svg]
        // Use the shared core's ordinary slot extension. Parameter order and the
        // pinned upstream definitions remain unchanged apart from these slots.
        do {
            let definitions = try createLibrary(components: pinned.map(\.definition)).extend(
                LibraryExtension(addComponents: Array(all.dropFirst(pinned.count)).map(\.definition), addComponentSlots: Dictionary(uniqueKeysWithValues: ["Map", "SVG"].map {
                    ($0, ["Card.children", "TabItem.content", "AccordionItem.content"])
                }))).components
            let builders = Dictionary(uniqueKeysWithValues: all.map { ($0.definition.name, $0) })
            return definitions.map { builders[$0.name]!.replacingDefinition($0) }
        } catch { preconditionFailure("Invalid SDK component library: \(error)") }
    }

}

