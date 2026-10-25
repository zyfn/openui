import OpenUILang
import SwiftUI
import XCTest

@testable import OpenUISwiftUI

final class ComponentPromptTests: XCTestCase {
    func testDefaultPromptForwardsCoreOptionsWithoutImplicitNativeGuidance() throws {
        let library = try OpenUIStandardComponents.library()
        let options = PromptOptions(preamble: "Host", additionalRules: ["Host choice"])
        XCTAssertEqual(library.prompt(options), library.library.prompt(options))
        XCTAssertEqual(library.prompt(), library.library.prompt())
    }
    func testNativeAndDirectCorePromptPathsPreserveHostOptions() throws {
        let library = try OpenUIStandardComponents.library()
        let spec = library.toSpec()
        let originalSpec = spec.toJSONValue()
        let host = PromptOptions(
            preamble: "HOST PREAMBLE", additionalRules: ["HOST RULE"], examples: ["HOST EXAMPLE"],
            toolExamples: ["HOST TOOL EXAMPLE"], tools: [.name("host_tool")],
            editMode: false, inlineMode: false, toolCalls: false, bindings: false, builtinFunctions: false)
        let options = OpenUINativePrompt.options(for: spec, extending: host)
        XCTAssertEqual(options.preamble, host.preamble)
        XCTAssertEqual(options.additionalRules?.first, "HOST RULE")
        XCTAssertEqual(options.examples?.first, "HOST EXAMPLE")
        XCTAssertEqual(options.toolExamples, host.toolExamples)
        XCTAssertEqual(options.editMode, false)
        XCTAssertEqual(options.inlineMode, false)
        XCTAssertEqual(options.toolCalls, false)
        XCTAssertEqual(options.bindings, false)
        XCTAssertEqual(options.builtinFunctions, false)
        guard case .name(let tool)? = options.tools?.first else { return XCTFail("Lost host tool") }
        XCTAssertEqual(tool, "host_tool")

        let direct = generateSystemPrompt(library: spec, promptOptions: options)
        XCTAssertEqual(library.prompt(options), direct, "Both entry points must use the same unchanged core generator")
        XCTAssertTrue(direct.contains("HOST PREAMBLE"))
        XCTAssertTrue(direct.contains("HOST EXAMPLE"))
        XCTAssertTrue(direct.contains("parent container's available width"))
        XCTAssertTrue(direct.contains("responsive=true"))
        XCTAssertTrue(direct.contains("does not automatically turn vertical"))
        XCTAssertFalse(options.examples?.contains { $0.contains("$detail") } ?? true)
        XCTAssertEqual(library.toSpec().toJSONValue(), originalSpec, "Prompt prose must not alter schema or signatures")
    }

    @MainActor func testAllNativePromptExamplesParseAndEvaluate() throws {
        let library = try OpenUIStandardComponents.library()
        XCTAssertEqual(OpenUINativePrompt.examples.count, 3)
        for example in OpenUINativePrompt.examples {
            let state = OpenUIState(schema: library.library.toSchema())
            state.setSource(example.source)
            XCTAssertTrue(state.isComplete, example.purpose)
            XCTAssertNotNil(state.root, example.purpose)
            XCTAssertTrue(state.errors.isEmpty, "\(example.purpose): \(state.errors)")
        }

        let media = OpenUINativePrompt.examples[1]
        let state = OpenUIState(schema: library.library.toSchema())
        state.setSource(media.source)
        let withoutMedia = PropValue.children(try XCTUnwrap(state.root))
        XCTAssertFalse(withoutMedia.contains { $0.typeName == "ImageBlock" },
            "Missing media must disappear without removing the source's text")
        XCTAssertTrue(withoutMedia.contains { $0.typeName == "TextContent" && PropValue.string($0, "text") == "Compare the trade-off" })
        // Parser/evaluator fixture only: no renderer or network request runs.
        let withMedia = media.source.replacingOccurrences(of: "imageUrl:null",
            with: "imageUrl:\"https://sdk-fixture.invalid/detail.jpg\"")
        state.reset()
        state.setSource(withMedia)
        XCTAssertTrue(state.errors.isEmpty, "\(state.errors)")
        let children = PropValue.children(try XCTUnwrap(state.root))
        let image = try XCTUnwrap(children.first { $0.typeName == "ImageBlock" })
        XCTAssertEqual(PropValue.string(image, "alt"), "Compare the trade-off")
        XCTAssertTrue(children.contains { $0.typeName == "TextContent" && PropValue.string($0, "text") == "Compare the trade-off" })
    }

    @MainActor func testSubsetGuidanceOnlyIncludesItsRegisteredComponents() throws {
        let allowed = Set(["Stack", "TextContent"])
        let subset = try OpenUIComponentLibrary(
            components: OpenUIStandardComponents.components.filter { allowed.contains($0.definition.name) }, root: "Stack")
        let options = OpenUINativePrompt.options(for: subset.toSpec())
        let included = OpenUINativePrompt.examples.filter { options.examples?.contains($0.prompt) == true }
        XCTAssertEqual(included.count, 1)
        for example in included {
            let state = OpenUIState(schema: subset.library.toSchema())
            state.setSource(example.source)
            XCTAssertNotNil(state.root)
            XCTAssertTrue(state.errors.isEmpty, "\(state.errors)")
            for token in tokenize(example.source) {
                if case .type(let name) = token { XCTAssertTrue(allowed.contains(name), name) }
            }
        }
        let prompt = subset.prompt(options)
        for excluded in ["OverviewCardBlock", "Buttons", "ImageText", "Table"] {
            XCTAssertFalse(prompt.contains(excluded + "("), "Removed component calls/signatures must not leak: \(excluded)")
            XCTAssertFalse(options.additionalRules?.joined(separator: "\n").contains(excluded) ?? false)
        }
    }

    func testGuidanceIsIdempotentAndLeavesCustomLibrariesAlone() throws {
        let standard = try OpenUIStandardComponents.library()
        let once = OpenUINativePrompt.options(for: standard.toSpec(), extending: PromptOptions(
            additionalRules: ["Host policy"], examples: ["Host illustration"]))
        let twice = OpenUINativePrompt.options(for: standard.toSpec(), extending: once)
        XCTAssertEqual(once.additionalRules, twice.additionalRules)
        XCTAssertEqual(once.examples, twice.examples)
        XCTAssertEqual(standard.prompt(once), standard.prompt(twice))

        let note = OpenUIComponent(name: "Note", description: "A note", params: [OpenUIParameter.string("text")]) {
            Text($0.string("text") ?? "")
        }
        let custom = try OpenUIComponentLibrary(components: [note], root: "Note")
        let host = PromptOptions(preamble: "Custom product", additionalRules: ["Use its contract"])
        XCTAssertEqual(custom.prompt(host), custom.library.prompt(host))
    }
}
