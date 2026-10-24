import OpenUILang
import SwiftUI
import XCTest
@testable import OpenUISwiftUI

final class StreamingPresentationTests: XCTestCase {
    @MainActor func testFullBufferStreamingAndItsFinalSnapshotDoNotReplaceNativePresentation() throws {
        let library = try OpenUIStandardComponents.library()
        let state = OpenUIState(schema: library.library.toSchema())
        let prefix = "root=Tabs([TabItem(\"a\",\"First\",[TextContent(\"A\")])"
        state.setSource(prefix, streaming: true)
        let generation = state.presentationRevision
        let full = prefix + ",TabItem(\"b\",\"Second\",[TextContent(\"B\")])])"
        state.setSource(full, streaming: true)
        XCTAssertEqual(state.presentationRevision, generation)
        state.setSource(full, streaming: false)
        XCTAssertEqual(state.presentationRevision, generation)
        XCTAssertTrue(state.errors.isEmpty, "\(state.errors)")
        state.setSource("root=Tabs([TabItem(\"c\",\"Replacement\",[TextContent(\"C\")])])")
        XCTAssertGreaterThan(state.presentationRevision, generation)
    }

    func testTabSelectionStaysOnItsFirstValidIDAsPanelsGrowAndArrive() {
        let a = NativeTabPanel(id: "a", label: "方案一 · 较长中文名称", content: .string("First"))
        let b = NativeTabPanel(id: "b", label: "方案二 · 另一个名称", content: .string("Second"))
        var selection = NativeTabsSelection()
        selection.reconcile([])
        XCTAssertNil(selection.selected)
        selection.reconcile([a])
        selection.reconcile([a, b])
        XCTAssertEqual(selection.selected, "a")
        selection.choose("b")
        selection.reconcile([NativeTabPanel(id: "a", label: a.label, content: .string("First grows considerably")), b])
        XCTAssertEqual(selection.selected, "b")
        selection.reconcile([a])
        XCTAssertEqual(selection.selected, "a")
        selection.reconcile([])
        XCTAssertNil(selection.selected)
    }

    func testConditionalEmptySlotsDoNotChangeLaterAnonymousIdentities() {
        let tabs = Value.element(EvaluatedElement(typeName: "Tabs"))
        let carousel = Value.element(EvaluatedElement(typeName: "Carousel"))
        let before = OpenUIRenderChild.children(of: .array([.null, tabs, .array([.undefined, carousel])]))
        let after = OpenUIRenderChild.children(of: .array([.string("Arrived"), tabs, .array([.string("Also arrived"), carousel])]))
        XCTAssertEqual(before.map(\.id), [after[1].id, after[3].id])
    }

    @MainActor func testAppendCompleteStateAndPatchKeepPresentationWhileReplacementInvalidatesIt() throws {
        let library = try OpenUIStandardComponents.library()
        let state = OpenUIState(schema: library.library.toSchema())
        let generation = state.presentationRevision
        state.push("root=Tabs([TabItem(\"a\",\"First\",[TextContent(\"A\")])")
        state.push(",TabItem(\"b\",\"Second\",[TextContent(\"B\")])])")
        state.complete()
        XCTAssertEqual(state.presentationRevision, generation)
        state.setState("$note", value: .string("kept"))
        state.applyPatch("root=Tabs([TabItem(\"a\",\"First\",[TextContent(\"A grows\")]),TabItem(\"b\",\"Second\",[TextContent(\"B\")])])")
        XCTAssertEqual(state.presentationRevision, generation)
        XCTAssertTrue(state.errors.isEmpty, "\(state.errors)")
        state.setSource("root=Tabs([TabItem(\"a\",\"First\",[TextContent(\"Replacement\")])])")
        XCTAssertGreaterThan(state.presentationRevision, generation)
        let replacement = state.presentationRevision
        state.reset()
        XCTAssertGreaterThan(state.presentationRevision, replacement)
    }

    @MainActor func testEveryIncrementalTabPrefixPreservesSelectionUntilCompletion() throws {
        let library = try OpenUIStandardComponents.library()
        let state = OpenUIState(schema: library.library.toSchema())
        let source = "root=Tabs([TabItem(\"a\",\"方案一 · 较长中文标题\",[TextContent(\"第一段正文逐渐增长\")]),TabItem(\"b\",\"方案二 · 另一种选择\",[TextContent(\"第二段\")]),TabItem(\"c\",\"方案三 · 第三种选择\",[TextContent(\"第三段\")])])"
        var selection = NativeTabsSelection()
        var sawFirst = false
        for character in source {
            state.push(String(character))
            guard let root = state.root else { continue }
            let panels = NativeTabPanel.read(OpenUIRenderChild.children(of: PropValue.value(root, "items") ?? .null))
            selection.reconcile(panels)
            if panels.contains(where: { $0.id == "a" }) {
                sawFirst = true
                XCTAssertEqual(selection.selected, "a")
            }
            XCTAssertFalse(state.isComplete)
        }
        state.complete()
        XCTAssertTrue(sawFirst)
        XCTAssertTrue(state.errors.isEmpty, "\(state.errors)")
        XCTAssertEqual(selection.selected, "a")
    }
}
