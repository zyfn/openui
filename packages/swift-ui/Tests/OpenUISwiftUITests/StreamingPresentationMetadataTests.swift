import OpenUILang
import XCTest
@testable import OpenUISwiftUI

final class StreamingPresentationMetadataTests: XCTestCase {
  @MainActor func testDeclaredChartGetsAPresentationSlotWithoutChangingTheLangTree() throws {
    let library = try OpenUIStandardComponents.library()
    let state = OpenUIState(schema: library.library.toSchema())
    state.push("root=Stack([before,plot,after])\nbefore=TextContent(\"Before\")\nafter=TextContent(\"After\")\nplot=LineChart(labels,series)\n")
    var context = OpenUIComponentContext(element: try XCTUnwrap(state.root), registry: library.registry, state: state)
    XCTAssertEqual(context.children().count, 2, "Normative materialization still omits the unresolved chart")
    let presented = context.presentationChildren()
    XCTAssertEqual(presented.count, 3)
    guard case .element(let proxy) = presented[1].value else { return XCTFail("Missing native slot") }
    XCTAssertEqual(proxy.typeName, "LineChart")
    XCTAssertFalse(proxy.isSourceComplete)
    XCTAssertNil(proxy.props.first { $0.0 == "series" }, "No samples are invented")
    XCTAssertFalse(OpenUIComponentContext(element: proxy, registry: library.registry, state: state).canInteract)
    var overridden = library.registry
    overridden["LineChart"] = library.registry["LineChart"]
    let custom = OpenUIComponentContext(element: try XCTUnwrap(state.root), registry: overridden, state: state)
    XCTAssertEqual(custom.presentationChildren().count, 2, "Custom renderers do not inherit guessed SDK geometry")
    state.push("labels=[\"A\",\"B\"]\nseries=[Series(\"S\",[1,2])]\n"); state.complete()
    context = OpenUIComponentContext(element: try XCTUnwrap(state.root), registry: library.registry, state: state)
    XCTAssertEqual(context.children().count, 3)
    XCTAssertEqual(context.presentationChildren().map(\.id), presented.map(\.id))
  }

  @MainActor func testMissingSeriesDataDoesNotBlockOtherDeclaredSeries() throws {
    let library = try OpenUIStandardComponents.library()
    let state = OpenUIState(schema: library.library.toSchema())
    state.push("root=LineChart(labels,[first,second])\nlabels=[\"A\",\"B\"]\nfirst=Series(\"First\",firstValues)\nsecond=Series(\"Second\",secondValues)\nfirstValues=[1,")
    let context = OpenUIComponentContext(element: try XCTUnwrap(state.root), registry: library.registry, state: state)
    XCTAssertEqual(NativeValue.array(context.value("series")).count, 1)
    let staged = try XCTUnwrap(NativeChartStreamingPresentation.staged(context: context))
    XCTAssertEqual(staged.series.map(\.name), ["First", "Second"])
    XCTAssertEqual(staged.series[0].values, [1])
    XCTAssertTrue(staged.series[1].values.isEmpty)
    XCTAssertFalse(staged.hasValue(1, 0))
  }

  @MainActor func testInactiveBranchesAndDeferredActionsDoNotOwnLoading() throws {
    let library = try OpenUIStandardComponents.library()
    let state = OpenUIState(schema: library.library.toSchema())
    state.setSource("$use=false\ndata=Query(\"fixture\",{},[1])\nroot=LineChart([\"A\"],[Series(\"S\",$use?data:[1])])\n", streaming: true)
    var context = OpenUIComponentContext(element: try XCTUnwrap(state.root), registry: library.registry, state: state)
    XCTAssertFalse(context.hasPendingData)
    state.setState("$use", value: .boolean(true))
    context = OpenUIComponentContext(element: try XCTUnwrap(state.root), registry: library.registry, state: state)
    XCTAssertTrue(context.hasPendingData)
    state.setSource("data=Query(\"fixture\",{},[])\nroot=Button(\"Retry\",@Run(data))\n", streaming: true)
    context = OpenUIComponentContext(element: try XCTUnwrap(state.root), registry: library.registry, state: state)
    XCTAssertTrue(context.element.sourceReadiness.queryDependencies.isEmpty)
    state.setSource("root=Stack([false?LineChart(missingLabels,missingSeries):null,TextContent(\"Visible\")])\n", streaming: true)
    context = OpenUIComponentContext(element: try XCTUnwrap(state.root), registry: library.registry, state: state)
    XCTAssertEqual(context.presentationChildren().count, 1, "The presentation plan must not revive an inactive branch")
  }

  @MainActor func testInterruptDoesNotCommitTheTailOrStartDeferredTools() async throws {
    let library = try OpenUIStandardComponents.library()
    let provider = UnstartedStreamingTool()
    let state = OpenUIState(schema: library.library.toSchema(), toolProvider: provider)
    state.push("data=Query(\"fixture\",{},[])\nroot=LineChart([\"A\",\"B\"],[Series(\"S\",[1,2")
    let identity = state.presentationRevision
    state.interrupt()
    XCTAssertTrue(state.isComplete)
    XCTAssertTrue(state.isInterrupted)
    XCTAssertEqual(state.presentationRevision, identity)
    let context = OpenUIComponentContext(element: try XCTUnwrap(state.root), registry: library.registry, state: state)
    XCTAssertEqual(NativeChartStreamingPresentation.staged(context: context)?.series.first?.values, [1])
    try await Task.sleep(nanoseconds: 30_000_000)
    let calls = await provider.count()
    XCTAssertEqual(calls, 0)
    state.reset()
    XCTAssertFalse(state.isInterrupted)
  }

  @MainActor func testAStringOrReferenceAtTheStreamTailIsNotYetACommittedExpression() throws {
    let library = try OpenUIStandardComponents.library()
    let state = OpenUIState(schema: library.library.toSchema())
    state.push("root=ImageBlock(\"https://images.example/base\"")
    XCTAssertFalse(try XCTUnwrap(state.root).sourceReadiness["src"].complete)
    state.push("+\"?token=complete\",")
    XCTAssertTrue(try XCTUnwrap(state.root).sourceReadiness["src"].complete)
    state.reset()
    state.push("price=1\npriceLong=100\nroot=LineChart([\"A\"],[Series(\"S\",[price")
    let context = OpenUIComponentContext(element: try XCTUnwrap(state.root), registry: library.registry, state: state)
    XCTAssertFalse(NativeChartStreamingPresentation.staged(context: context)?.hasContent(for: "LineChart") ?? false)
    state.push("Long,")
    let ready = OpenUIComponentContext(element: try XCTUnwrap(state.root), registry: library.registry, state: state)
    XCTAssertEqual(NativeChartStreamingPresentation.staged(context: ready)?.series.first?.values, [100])
  }

  @MainActor func testAddingAnIntegerNamedSeriesDoesNotRecolorAnExistingSeries() throws {
    let library = try OpenUIStandardComponents.library()
    let state = OpenUIState(schema: library.library.toSchema())
    func chart() throws -> NativeChartData {
      try XCTUnwrap(NativeChartStreamingPresentation.staged(context:
        OpenUIComponentContext(element: try XCTUnwrap(state.root), registry: library.registry, state: state)))
    }
    state.push("root=LineChart([\"A\"],[Series(\"2\",[1]),")
    XCTAssertEqual(try chart().colorIndex(at: 0), 0)
    state.push("Series(\"1\",[2])])"); state.complete()
    let final = try chart()
    XCTAssertEqual(final.series.map(\.name), ["1", "2"], "ECMAScript ordering is retained")
    XCTAssertEqual(final.colorIndices, [1, 0], "Colors follow the source series identity")
  }

  @MainActor func testCartesianPresentationUsesCommittedSamplesWithoutInventingZeroRows() throws {
    let library = try OpenUIStandardComponents.library()
    let state = OpenUIState(schema: library.library.toSchema())
    func staged() throws -> NativeChartData {
      let context = OpenUIComponentContext(element: try XCTUnwrap(state.root), registry: library.registry, state: state)
      return try XCTUnwrap(NativeChartStreamingPresentation.staged(context: context))
    }
    state.push("root=LineChart([\"A\",\"B\",\"C\"],[Series(\"S\",[1,2")
    var data = try staged()
    XCTAssertEqual(data.labels, ["A", "B", "C"])
    XCTAssertEqual(data.series.first?.values, [1])
    XCTAssertFalse(data.hasValue(0, 1))
    XCTAssertEqual(data.accessibilityRows.count, 1)
    XCTAssertNil(data.inspection(at: 1, locale: Locale(identifier: "en_US")))
    state.push("0,3")
    data = try staged()
    XCTAssertEqual(data.series.first?.values, [1, 20])
    XCTAssertEqual(data.labels.count, 3, "Known category positions do not collapse to the received prefix")
    state.push("])])"); state.complete()
    data = try staged()
    XCTAssertEqual(data.series.first?.values, [1, 20, 3])
    XCTAssertFalse(data.isProgressive)
  }

  @MainActor func testPieDoesNotPresentAnUnfinishedTotalAsOneHundredPercent() throws {
    let library = try OpenUIStandardComponents.library()
    let state = OpenUIState(schema: library.library.toSchema())
    state.push("root=PieChart([\"A\",\"B\"],[1,2")
    var context = OpenUIComponentContext(element: try XCTUnwrap(state.root), registry: library.registry, state: state)
    XCTAssertNil(NativeChartStreamingPresentation.staged(context: context))
    state.push("0])")
    context = OpenUIComponentContext(element: try XCTUnwrap(state.root), registry: library.registry, state: state)
    XCTAssertEqual(NativeChartStreamingPresentation.staged(context: context)?.slices.sorted(), [1, 20])
  }

  @MainActor func testLoadingOwnershipDoesNotFollowAnUnrelatedQuery() throws {
    let library = try OpenUIStandardComponents.library()
    let state = OpenUIState(schema: library.library.toSchema())
    state.setSource("data=Query(\"fixture\",{},[])\nroot=Table([Col(\"Data\",data)])", streaming: true)
    var context = OpenUIComponentContext(element: try XCTUnwrap(state.root), registry: library.registry, state: state)
    XCTAssertEqual(context.element.sourceReadiness.queryDependencies, ["data"])
    XCTAssertTrue(context.hasPendingData)
    state.setSource("data=Query(\"fixture\",{},[])\nroot=LineChart([\"A\"],[Series(\"S\",[1])])", streaming: true)
    context = OpenUIComponentContext(element: try XCTUnwrap(state.root), registry: library.registry, state: state)
    XCTAssertTrue(state.isQueryLoading)
    XCTAssertTrue(context.element.sourceReadiness.queryDependencies.isEmpty)
    XCTAssertFalse(context.hasPendingData)
  }

  @MainActor func testChartNumericBoundariesDistinguishCommittedPrefixFromOpenToken() throws {
    let library = try OpenUIStandardComponents.library()
    let state = OpenUIState(schema: library.library.toSchema())
    state.push("root=LineChart([\"A\",\"B\"],[Series(\"S\",[1,2")
    var root = try XCTUnwrap(state.root)
    XCTAssertTrue(root.sourceReadiness["labels"].complete)
    XCTAssertTrue(root.sourceReadiness["series"][0]["values"][0].complete)
    XCTAssertFalse(root.sourceReadiness["series"][0]["values"][1].complete)
    state.push("0,")
    root = try XCTUnwrap(state.root)
    XCTAssertTrue(root.sourceReadiness["series"][0]["values"][1].complete)
    state.push("])])")
    root = try XCTUnwrap(state.root)
    XCTAssertTrue(root.sourceReadiness.closed)
    state.complete()
    XCTAssertTrue(try XCTUnwrap(state.root).sourceReadiness.complete)
    XCTAssertTrue(state.errors.isEmpty)
  }

  @MainActor func testButtonStructureDoesNotInventAnOptionalVariantBeforeClosing() throws {
    let library = try OpenUIStandardComponents.library()
    let state = OpenUIState(schema: library.library.toSchema())
    state.push("root=Button(\"Details\"")
    XCTAssertFalse(try XCTUnwrap(state.root).sourceReadiness.closed)
    XCTAssertFalse(try XCTUnwrap(state.root).sourceReadiness["variant"].complete)
    state.push(",null,\"secondary\")")
    XCTAssertTrue(try XCTUnwrap(state.root).sourceReadiness.closed)
    XCTAssertTrue(try XCTUnwrap(state.root).sourceReadiness["variant"].complete)
  }

  @MainActor func testReferencedDataRetainsPerValueBoundaries() throws {
    let library = try OpenUIStandardComponents.library()
    let state = OpenUIState(schema: library.library.toSchema())
    state.push("root=LineChart(labels,series)\nlabels=[\"A\",\"B\"]\nseries=[Series(\"S\",[1,2")
    let root = try XCTUnwrap(state.root)
    XCTAssertTrue(root.sourceReadiness["labels"].complete)
    XCTAssertTrue(root.sourceReadiness["series"][0]["values"][0].complete)
    XCTAssertFalse(root.sourceReadiness["series"][0]["values"][1].complete)
  }
}

private actor UnstartedStreamingTool: ToolProvider {
  private var calls = 0
  func callTool(name: OpenUIString, arguments: OpenUIObject) async throws -> Value {
    calls += 1; return .array([])
  }
  func count() -> Int { calls }
}
