import OpenUILang

/// Native composition advice passed through the official PromptOptions hooks.
/// This does not change the library spec, language grammar or core generator.
public enum OpenUINativePrompt {
    public static func options(
        for spec: LibrarySpec, extending original: PromptOptions = PromptOptions(),
        tableCellPolicy: OpenUITableCellPolicy = .unrestricted
    ) -> PromptOptions {
        let names = Set(spec.components.map(\.name))
        guard names.contains("Stack"), names.contains("TextContent") else { return original }
        var options = original
        var rules = [
            "Compose an answer with a takeaway, useful comparisons or local exploration, not a component tour. Give each fact one main presentation; omit unavailable media and never copy example facts.",
            "Design for the parent container's available width and text size, not a phone model. Prefer an open vertical reading flow; reserve large-heavy for the main heading and normal text for explanations.",
            "For flexible peers: Stack(items,\"row\") is a non-wrapping row; prefer Stack(items,\"row\",\"m\",\"start\",\"start\",true). Text wrapping alone does not wrap the row. Do not invent column ratios."
        ]
        if names.contains("Card") {
            rules.append("Use Card for an independent object or meaningful group, not every paragraph. Avoid nested card shells, fixed content heights and oversized local actions.")
        }
        if spec.components.contains(where: { $0.name.hasSuffix("CardBlock") && $0.signature.contains("responsive?") }) {
            rules.append("Keep responsive=true for grid card blocks so columns adapt to their parent. Use carousel only for deliberate horizontal browsing, not to squeeze a crowded row.")
        }
        if names.contains("Buttons") {
            rules.append("Use Buttons for related actions; row can fall back to column when constrained. Keep primary emphasis for the main task and secondary/tertiary for local alternatives; explicit direction and size still matter.")
        }
        if names.contains("ImageText") {
            rules.append("ImageText with horizontal layout stays horizontal; it does not automatically turn vertical. Use it for a thumbnail and short text, or choose a vertical composition for media with long explanations.")
        }
        if names.contains("Table") {
            rules.append("Table keeps column relationships, including component-valued cells. A wide table scrolls horizontally; it does not become cards. Choose it for shared comparison axes, not unrelated narratives.")
            if tableCellPolicy.allowedComponents != nil {
                rules.append(NativeTableCellContent.guidance(registered: names, policy: tableCellPolicy))
            }
        }
        if names.contains("Map") {
            rules.append("Use Map when supplied coordinates make spatial relationships useful. Valid point facts get compact default place cards; use content only for richer component pages. Omit unlocatable points and missing media, never invent coordinates or ratings.")
        }
        options.additionalRules = appending(rules, to: original.additionalRules)
        let eligibleExamples = spec.root == nil || spec.root == "Stack" ? Self.examples.filter { example in
            let tokens = tokenize(example.source)
            let references = Set(tokens.compactMap { token -> String? in
                if case .type(let name) = token { return name }
                return nil
            })
            let usesBindings = tokens.contains { if case .stateVar = $0 { return true }; return false }
            return references.isSubset(of: names) && (original.bindings != false || !usesBindings)
        } : []
        options.examples = appending(eligibleExamples.map(\.prompt), to: original.examples)
        return options
    }

    private static func appending(_ additions: [String], to original: [String]?) -> [String]? {
        guard !additions.isEmpty else { return original }
        var result = original ?? []
        for addition in additions where !result.contains(addition) { result.append(addition) }
        return result
    }

    struct Example {
        let purpose: String
        let source: String
        var prompt: String { "\(purpose) (illustrative content; adapt to supplied facts):\n\(source)" }
    }

    static let examples: [Example] = [
        Example(purpose: "Open reading flow with wrapping summary", source: """
        root=Stack([
          TextContent("Progress at a glance","large-heavy"),
          Stack([TextContent("12 finished"),TextContent("3 next")],"row","l","start","start",true),
          TextContent("Resolve the open question before expanding scope.","small")
        ],"column","m")
        """),
        Example(purpose: "Optional media and text from one source, with responsive peers", source: """
        content={title:"Compare the trade-off",note:"Choose based on the question you need to answer.",imageUrl:null}
        root=Stack([
          TextContent(content.title,"large-heavy"),
          content.imageUrl?ImageBlock(content.imageUrl,content.title):null,
          OverviewCardBlock([
            OverviewCardItem("a",Text("text","Faster feedback"),MetricIndicatorInline("2","steps")),
            OverviewCardItem("b",Text("text","Broader coverage"),MetricIndicatorInline("4","steps"))
          ],"grid",true),
          TextContent(content.note,"small")
        ],"column","m")
        """),
        Example(purpose: "Mixed cells and an action that reveals context", source: """
        $detail=false
        root=Stack([
          Table([Col("Focus",[TextContent("Scope"),TextContent("Evidence")]),Col("Status",[Tag("Ready"),Tag("Review")])]),
          Buttons([Button($detail?"Hide context":"Show context",@Set($detail,!$detail),"tertiary")],"row"),
          $detail?TextContent("Scope is agreed; the evidence still needs review."):null
        ],"column","m")
        """),
    ]
}
