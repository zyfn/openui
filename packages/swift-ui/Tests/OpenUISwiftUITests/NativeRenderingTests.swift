#if os(macOS)
    import AppKit
    import XCTest
    import SwiftUI
    import OpenUILang
    @testable import OpenUISwiftUI

    final class NativeRenderingTests: XCTestCase {
        @MainActor func testVisiblePartialTextKeepsGrowingBeforeItsParentCloses() throws {
            _ = NSApplication.shared
            let library = try OpenUIStandardComponents.library()
            let state = OpenUIState(schema: library.library.toSchema())
            func height() throws -> CGFloat {
                let renderer = ImageRenderer(content: OpenUIRenderer(state: state, registry: library.registry))
                renderer.proposedSize = ProposedViewSize(width: 320, height: nil)
                return try XCTUnwrap(renderer.nsImage).size.height
            }
            state.push("root=Stack([TextContent(\"A visible sentence.")
            let first = try height()
            state.push(String(repeating: " More text arrives while the parent layout is still open.", count: 8))
            XCTAssertFalse(state.isComplete)
            XCTAssertGreaterThan(try height(), first + 40,
                "Partial text must grow visibly; a constant parent skeleton cannot replace the response")
            state.push("\")],\"column\",\"m\")")
            state.complete()
            XCTAssertTrue(state.errors.isEmpty, "\(state.errors)")
        }

        @MainActor func testUnfinishedContainerDefersMediaUntilLocalLayoutIsKnown() throws {
            _ = NSApplication.shared
            let library = try OpenUIStandardComponents.library()
            let state = OpenUIState(schema: library.library.toSchema())
            func height() throws -> CGFloat {
                let renderer = ImageRenderer(content: OpenUIRenderer(state: state, registry: library.registry))
                renderer.proposedSize = ProposedViewSize(width: 320, height: nil)
                return try XCTUnwrap(renderer.nsImage).size.height
            }
            state.push("root=Stack([Image(\"Photo\",null),TextContent(\"Copy grows")
            let pending = try height()
            XCTAssertLessThan(pending, 100, "Unreceived direction is not a confirmed column default")
            state.push(" beside the image\")],\"row\",\"m\",\"stretch\",\"start\",false)")
            state.complete()
            XCTAssertTrue(state.errors.isEmpty)
            let photoHeight = OpenUIPresentation().thumbnailSize / OpenUIPresentation().coverAspectRatio
            XCTAssertEqual(try height(), photoHeight, accuracy: 1,
                "Resolving a local row must retain the shared photo aspect rather than switching to a 4:5 height")
            state.reset()
            state.push("root=Stack([Stack([Image(\"Photo\",null),TextContent(\"Known local row\")],\"row\",\"m\",\"stretch\",\"start\",false)")
            XCTAssertLessThan(try height(), photoHeight,
                "An unresolved ancestor can still change this row's available width")
        }

        @MainActor func testNativeAndRichTextBothRespondToTheSameThemeFont() throws {
            _ = NSApplication.shared
            let library = try OpenUIStandardComponents.library()
            func height(_ source: String, theme: OpenUIThemeValues) throws -> CGFloat {
                let state = OpenUIState(schema: library.library.toSchema())
                state.setSource(source)
                XCTAssertTrue(state.errors.isEmpty)
                let renderer = ImageRenderer(content:
                    OpenUIRenderer(state: state, registry: library.registry).openUITheme(theme))
                renderer.proposedSize = ProposedViewSize(width: 320, height: nil)
                return try XCTUnwrap(renderer.nsImage).size.height
            }
            let ordinary = OpenUIThemeValues()
            var enlarged = ordinary
            enlarged.textBodyDefault.size = 25
            enlarged.textBodyDefaultHeavy.size = 25
            enlarged.textBodySm.size = 23
            for source in ["root=TextContent(\"One line\",\"default\")",
                           "root=BoldText(\"text\",\"One line\",null,\"text\",\"md\")",
                           "root=ListBlock([ListItem(\"One line\",\"Supporting line\")],\"number\")"] {
                XCTAssertGreaterThan(try height(source, theme: enlarged), try height(source, theme: ordinary) + 3,
                    "The same theme must reach both ordinary and rich text: \(source)")
            }
        }

        @MainActor func testNumberListIgnoresOptionalItemImages() throws {
            _ = NSApplication.shared
            guard #available(macOS 13, *) else { throw XCTSkip("ImageRenderer requires macOS 13") }
            let library = try OpenUIStandardComponents.library()
            func pixels(imageArgument: String) throws -> Data {
                let state = OpenUIState(schema: library.library.toSchema())
                state.setSource("root=ListBlock([ListItem(\"An item\",\"Supporting text\",\(imageArgument))],\"number\")")
                XCTAssertTrue(state.errors.isEmpty, "\(state.errors)")
                let renderer = ImageRenderer(content:
                    OpenUIRenderer(state: state, registry: library.registry)
                        .environment(\.locale, Locale(identifier: "en_US"))
                        .preferredColorScheme(.light).background(Color.white))
                renderer.proposedSize = ProposedViewSize(width: 320, height: nil)
                renderer.scale = 1
                let image = try XCTUnwrap(renderer.cgImage)
                return try XCTUnwrap(image.dataProvider?.data) as Data
            }
            XCTAssertEqual(
                try pixels(imageArgument: "null"),
                try pixels(imageArgument: "{src:\"https://example.invalid/unused.jpg\",alt:\"Unused image\"}"),
                "Number indicators must not turn into image rows when optional image data is present")
        }

        @MainActor func testFollowUpChipsRenderAndSynthesizeContinueConversation() throws {
            _ = NSApplication.shared
            guard #available(macOS 13, *) else { throw XCTSkip("ImageRenderer requires macOS 13") }
            let library = try OpenUIStandardComponents.library()
            let state = OpenUIState(schema: library.library.toSchema())
            state.setSource("root=FollowUpBlock([a,b])\na=FollowUpItem(\"Tell me more\")\nb=FollowUpItem(\"Show a comparison\")")
            XCTAssertTrue(state.errors.isEmpty, "\(state.errors)")
            let renderer = ImageRenderer(content:
                OpenUIRenderer(state: state, registry: library.registry)
                    .environment(\.locale, Locale(identifier: "en_US"))
                    .preferredColorScheme(.light).background(Color.white))
            renderer.proposedSize = ProposedViewSize(width: 320, height: nil)
            renderer.scale = 1
            _ = try XCTUnwrap(renderer.cgImage)
            let action = NativeFollowUpItem.action(for: "Tell me more")
            guard case .object(let fields) = action else {
                return XCTFail("follow-up action must be an object")
            }
            let byKey = Dictionary(uniqueKeysWithValues: fields.fields.map { ($0.key.displayString, $0.value) })
            XCTAssertEqual(byKey["type"], .string(OpenUIString("continue_conversation")))
            XCTAssertEqual(byKey["message"], .string(OpenUIString("Tell me more")))
        }

        @MainActor func testCompactCardDoesNotFillAnUnrequestedParentHeight() throws {
            _ = NSApplication.shared
            let library = try OpenUIStandardComponents.library()
            guard #available(macOS 13, *) else { throw XCTSkip("Native Layout requires macOS 13") }
            func height(_ source: String, proposedHeight: CGFloat?) throws -> CGFloat {
                let state = OpenUIState(schema: library.library.toSchema())
                state.setSource(source)
                XCTAssertTrue(state.errors.isEmpty, "\(state.errors)")
                let renderer = ImageRenderer(content: OpenUIRenderer(state: state, registry: library.registry))
                renderer.proposedSize = ProposedViewSize(width: 320, height: proposedHeight)
                return try XCTUnwrap(renderer.nsImage).size.height
            }
            let copy = "TextContent(\"A compact card\")"
            let textHeight = try height("root=" + copy, proposedHeight: nil)
            XCTAssertGreaterThan(textHeight, 0, "The card's content must actually render")
            for variant in [nil, "card", "clear", "sunk"] as [String?] {
                let argument = variant.map { ",\"\($0)\"" } ?? ""
                let source = "root=Card([\(copy)]\(argument))"
                let natural = try height(source, proposedHeight: nil)
                XCTAssertEqual(try height(source, proposedHeight: 400), natural, accuracy: 1,
                    "A height proposal is a constraint, not a request to fill it")
                let theme = OpenUIThemeValues()
                let inset = variant == "clear" ? 0 : 2 * theme.spaceML
                XCTAssertEqual(natural, textHeight + inset, accuracy: 1,
                    "Card height must include only its content and declared native inset")
            }
        }

        @MainActor func testDatePlaceholderRendersUsingTheScopedSwiftUILocale() throws {
            _ = NSApplication.shared
            let library = try OpenUIStandardComponents.library()
            let state = OpenUIState(schema: library.library.toSchema())
            state.setSource("root=DatePicker(\"date\",\"single\",null,null)")
            XCTAssertTrue(state.errors.isEmpty, "\(state.errors)")
            let hosting = NSHostingView(rootView:
                OpenUIRenderer(state: state, registry: library.registry)
                    .environment(\.locale, Locale(identifier: "en_US"))
                    .preferredColorScheme(.light).padding(16).background(Color.white))
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 360, height: 100), styleMask: [.borderless],
                backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.contentView = hosting
            window.setFrameOrigin(NSPoint(x: -10000, y: -10000))
            window.orderFront(nil)
            defer { window.close() }

            func snapshot(_ locale: String) throws -> Data {
                hosting.rootView = OpenUIRenderer(state: state, registry: library.registry)
                    .environment(\.locale, Locale(identifier: locale))
                    .preferredColorScheme(.light).padding(16).background(Color.white)
                hosting.layoutSubtreeIfNeeded()
                RunLoop.main.run(until: Date().addingTimeInterval(0.1))
                let bitmap = try XCTUnwrap(hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds))
                hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
                return try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
            }

            let english = try snapshot("en_US")
            let chinese = try snapshot("zh_CN")
            XCTAssertNotEqual(english, chinese, "The placeholder must resolve in the view's locale")
            XCTAssertEqual(try snapshot("en_US"), english, "Locale changes must be reversible in the same view")
        }

        @MainActor func testNativeFormMountsItsFieldsAndCanRenderSnapshots() throws {
            _ = NSApplication.shared
            let library = try OpenUIStandardComponents.library()
            let state = OpenUIState(schema: library.library.toSchema())
            state.setSource(
                """
                $email = ""
                $travel = "train"
                root = Stack([
                  TextContent("安排一次轻松的出行", "large-heavy"),
                  TextContent("原生输入与选择，共用现有状态和动作。"),
                  Form("trip", Buttons([Button("提交行程", @ToAssistant("请根据表单继续安排")), Button("重置邮箱", @Reset($email), "secondary")]), [
                    FormControl("联系邮箱", Input("email", "you@example.com", "email", {required:true,email:true}, $email)),
                    FormControl("交通方式", Select("travel", [SelectItem("train", "高铁"), SelectItem("flight", "飞机")], null, null, $travel)),
                    FormControl("出行日期", DatePicker("dates", "range", null, {from:"2026-11-01",to:"2026-11-03"})),
                    FormControl("预算", Slider("budget", "discrete", 0, 10000, 500, [2000,6000], "预算")),
                    FormControl("偏好", CheckBoxGroup("preferences", [CheckBoxItem("靠窗", "优先选择靠窗座位", "window", true), CheckBoxItem("餐食", "需要餐食", "meal", false)]))
                  ])
                ])
                """)
            XCTAssertTrue(state.errors.isEmpty, "\(state.errors)")
            let root = ScrollView {
                OpenUIRenderer(state: state, registry: library.registry).padding(24)
            }.environment(\.locale, Locale(identifier: "zh_CN"))
                .preferredColorScheme(.light).background(Color.white)
            let hosting = NSHostingView(rootView: root)
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 520, height: 660), styleMask: [.borderless],
                backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.contentView = hosting
            window.setFrameOrigin(NSPoint(x: -10000, y: -10000))
            window.orderFront(nil)
            defer { window.close() }
            hosting.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.3))
            XCTAssertEqual(state.fieldValue(form: "trip", name: "email"), .string(""))
            XCTAssertEqual(state.fieldValue(form: "trip", name: "travel"), .string("train"))
            guard case .array(let range) = state.fieldValue(form: "trip", name: "budget") else {
                return XCTFail("Slider did not mount")
            }
            XCTAssertEqual(Array(range), [.number(2000), .number(6000)])
            guard case .object(let preferences) = state.fieldValue(form: "trip", name: "preferences") else {
                return XCTFail("Choices did not mount")
            }
            XCTAssertEqual(preferences["window"], .boolean(true))
            if let directory = ProcessInfo.processInfo.environment["OPENUI_SNAPSHOT_DIR"] {
                try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
                let rectangle = hosting.bounds
                let bitmap = try XCTUnwrap(hosting.bitmapImageRepForCachingDisplay(in: rectangle))
                hosting.cacheDisplay(in: rectangle, to: bitmap)
                let data = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
                try data.write(
                    to: URL(fileURLWithPath: directory).appendingPathComponent("native-form-macos.png"))
            }
        }
    }


extension NativeRenderingTests {
  /// Deterministic SDK visual fixtures. No live prices, remote images or map
  /// tiles are requested. Geometry checks always run; PNG export is opt-in.
  @MainActor func testNativeVisualAcceptanceMatrix() throws {
    _ = NSApplication.shared
    let library = try OpenUIStandardComponents.library()
    let pages: [(String, String)] = [
      ("reading", ###"root=Stack([TextContent("阅读与解释","large-heavy"),TextContent("先给出清楚的结论，再展开必要的理由。**强调不是另一套字号**。\n\n## 信息的关系\n\n- 同组内容应该紧密\n- 不同章节留出呼吸空间\n\n支持 [来源入口](https://example.com)，以及 `inline code`。"),TextCallout("info","说明","这是 SDK 视觉测试内容，不包含实时数据。"),CodeBlock("swift","    let amount = 12\n    print(amount)\n")])"###),
      ("object", ###"root=Stack([TextContent("单个对象","large-heavy"),Card([Image("图片不可用时仍保留对象信息",null),CardHeader("适合阅读的独立对象","辅助信息不抢标题"),TextContent("对象介绍允许自然换行。缺少图片不应让价格、说明与操作一起消失。"),MetricIndicatorInline("¥1,299.00","示例金额，不是实时报价"),Buttons([Button("查看详情", "secondary")])])])"###),
      ("comparison", ###"root=Stack([TextContent("比较与数据","large-heavy"),TextContent("表格保持明确的行列关系，图表只显示真实存在的数据。"),Table([Col("方案",["标准方案","包含较长名称的方案"]),Col("示例数值",[1200,2450.75],"number")]),BarChart(["五月","六月","七月"],[Series("示例",[12,0,-4])]),MetricIndicatorWithStrikethrough("¥2,450.75","数值不截断","¥2,999.00")])"###),
      ("input", ###"root=Stack([TextContent("选择与输入","large-heavy"),Form("example",Buttons([Button("提交"),Button("返回","tertiary")]),[FormControl("联系邮箱",Input("email","请输入邮箱","email",{required:true,email:true})),FormControl("预算范围",Slider("budget","continuous",0,100,1,[20,80],"示例范围")),FormControl("偏好",CheckBoxGroup("preferences",[CheckBoxItem("安静","减少不必要的提示","quiet",true),CheckBoxItem("辅助说明","保留可读的详细信息","details",false)]))])])"###),
      ("process", ###"root=Stack([TextContent("步骤与披露","large-heavy"),TextContent("已有 Steps 表达过程，不新增时间线组件。"),Steps([StepsItem("确认内容","先确定真正需要展示的信息。"),StepsItem("检查状态","保留用户编辑，错误就近反馈。"),StepsItem("完成操作","展示已确认的结果，不把派发事件等同于远端保存成功。")]),Accordion([AccordionItem("detail","查看详细说明",[TextContent("在大字号下，文字与控件应自然扩展，不重叠或被裁切。")])])])"###),
      ("mixed", ###"root=Stack([TextContent("混合内容","large-heavy"),TextContent("连续正文、独立对象和操作区域不必具有同样的视觉重量。"),TagBlock(["清晰","可扩展","无业务定制"]),ListBlock([ListItem("文字与图片","缺失内容能够自然收拢"),ListItem("动作与状态","可操作性在点击之前就能辨认")],"number"),Separator("horizontal",true),TextContent("## 接下来\n\n默认主题无需逐组件补样式。"),Buttons([Button("继续","secondary")])])"###)
    ]
    let variants: [(String, CGFloat, ColorScheme, DynamicTypeSize, LayoutDirection)] = [
      ("compact-light", 320, .light, .large, .leftToRight),
      ("wide-light", 600, .light, .large, .leftToRight),
      ("compact-dark", 320, .dark, .large, .leftToRight),
      ("large-type", 320, .light, .accessibility2, .leftToRight),
      ("rtl", 320, .light, .large, .rightToLeft)
    ]
    for (name, source) in pages {
      let state = OpenUIState(schema: library.library.toSchema())
      state.setSource(source)
      XCTAssertTrue(state.errors.isEmpty, "\(name): \(state.errors)")
      for (variant, width, scheme, size, direction) in variants {
        let renderer = ImageRenderer(content: OpenUIRenderer(state: state, registry: library.registry)
          .environment(\.locale, Locale(identifier: "zh-Hans"))
          .environment(\.dynamicTypeSize, size)
          .environment(\.layoutDirection, direction)
          .environment(\.colorScheme, scheme)
          .padding(16).frame(width: width)
          .background(scheme == .dark ? Color.black : Color.white))
        renderer.proposedSize = ProposedViewSize(width: width, height: nil)
        renderer.scale = 1
        let image = try XCTUnwrap(renderer.nsImage, "\(name):\(variant)")
        XCTAssertEqual(image.size.width, width, accuracy: 1)
        XCTAssertTrue(image.size.height.isFinite && image.size.height > 30 && image.size.height < 12000)
        if let directory = ProcessInfo.processInfo.environment["OPENUI_SNAPSHOT_DIR"] {
          try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
          let tiff = try XCTUnwrap(image.tiffRepresentation)
          let bitmap = try XCTUnwrap(NSBitmapImageRep(data: tiff))
          let data = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
          try data.write(to: URL(fileURLWithPath: directory).appendingPathComponent("\(name)-\(variant).png"))
        }
      }
    }
  }
}

extension NativeRenderingTests {
  @MainActor func testChartCategoryAxisPhysicalPlacementIsIdenticalInLTRAndRTL() throws {
    let layout = NativeChartLayout(size: CGSize(width: 320, height: 250))
    func snapshot(_ direction: LayoutDirection) throws -> NSBitmapImageRep {
      try repairBitmap(NativeChartCategoryAxis(labels: ["May", "June", "July"],
        layout: layout, theme: OpenUIThemeValues()).environment(\.layoutDirection, direction),
        size: CGSize(width: 320, height: 250), name: direction == .leftToRight ? "d1-axis-ltr" : "d1-axis-rtl")
    }
    let ltr = try snapshot(.leftToRight), rtl = try snapshot(.rightToLeft)
    XCTAssertEqual(try repairPixelData(ltr), try repairPixelData(rtl),
      "A writing-direction change must not move categories onto different physical bars")
    let blank = try repairBitmap(Color.white, size: CGSize(width: 320, height: 250), name: "d1-background")
    XCTAssertNotEqual(try repairPixelData(rtl), try repairPixelData(blank), "Both blank is not an axis rendering pass")
  }

  @MainActor func testSymmetricRangeSliderRemainsVisibleAtTheSamePositionsInRTL() throws {
    let config = NativeSliderConfiguration(minimum: 0, maximum: 100, step: 1, discrete: false)
    func snapshot(_ direction: LayoutDirection) throws -> NSBitmapImageRep {
      try repairBitmap(NativeSliderTrack(values: [20, 80], configuration: config,
        enabled: true, showsDots: false, label: "Budget", select: { _, _ in })
        .environment(\.layoutDirection, direction), size: CGSize(width: 320, height: 44),
        name: direction == .leftToRight ? "d2-slider-ltr" : "d2-slider-rtl")
    }
    let ltr = try snapshot(.leftToRight), rtl = try snapshot(.rightToLeft)
    XCTAssertEqual(try repairPixelData(ltr), try repairPixelData(rtl),
      "Symmetric range fill and thumbs must remain inside the RTL control")
    let blank = try repairBitmap(Color.white, size: CGSize(width: 320, height: 44), name: "d2-background")
    XCTAssertNotEqual(try repairPixelData(rtl), try repairPixelData(blank), "Passing because both tracks are blank is invalid")
  }

  @MainActor private func repairBitmap<V: View>(_ content: V, size: CGSize, name: String) throws -> NSBitmapImageRep {
    _ = NSApplication.shared
    let hosting = NSHostingView(rootView: content.frame(width: size.width, height: size.height)
      .environment(\.colorScheme, .light).background(Color.white))
    let window = NSWindow(contentRect: CGRect(origin: .zero, size: size),
      styleMask: [.borderless], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false; window.contentView = hosting
    window.setFrameOrigin(NSPoint(x: -10000, y: -10000)); window.orderFront(nil)
    defer { window.close() }
    hosting.layoutSubtreeIfNeeded()
    RunLoop.main.run(until: Date().addingTimeInterval(0.1))
    hosting.layoutSubtreeIfNeeded()
    let bitmap = try XCTUnwrap(hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds))
    hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
    if let path = ProcessInfo.processInfo.environment["OPENUI_SNAPSHOT_DIR"] {
      try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
      try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        .write(to: URL(fileURLWithPath: path).appendingPathComponent(name + ".png"))
    }
    return bitmap
  }
  private func repairPixelData(_ image: NSBitmapImageRep) throws -> Data {
    let cgImage = try XCTUnwrap(image.cgImage)
    let context = try XCTUnwrap(CGContext(data: nil, width: image.pixelsWide, height: image.pixelsHigh,
      bitsPerComponent: 8, bytesPerRow: image.pixelsWide * 4,
      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: image.pixelsWide, height: image.pixelsHigh))
    return Data(bytes: try XCTUnwrap(context.data), count: image.pixelsWide * image.pixelsHigh * 4)
  }

  @MainActor func testValidBlockMathRendersInClippedHostsAcrossPageReentry() async throws {
    _ = NSApplication.shared
    let renderer = NativeMathRenderer()
    defer { renderer.cancel() }
    for index in 1...3 {
      let hosting = NSHostingView(rootView: NativeMathHost(renderer: renderer)
        .frame(width: 1, height: 1).clipped().opacity(0.001))
      let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 320, height: 100),
        styleMask: [.borderless], backing: .buffered, defer: false)
      window.isReleasedWhenClosed = false; window.contentView = hosting
      window.setFrameOrigin(NSPoint(x: -10000, y: -10000)); window.orderFront(nil)
      defer { window.contentView = nil; window.close() }
      hosting.layoutSubtreeIfNeeded()
      let descriptor = NativeMathDescriptor(tex: "\\frac{1}{2} + \(index)", display: true)
      let image = try await renderer.image(for: descriptor, fontSize: 16, color: "#303036ff")
      XCTAssertGreaterThan(image.size.width, 0); XCTAssertGreaterThan(image.size.height, 0)
      XCTAssertTrue(image.baseline.isFinite)
      XCTAssertEqual(renderer.lastJobPhases, [.waitingForHost, .loading, .awaitingFonts, .measuring, .snapshotting, .completed])
      XCTAssertNil(renderer.lastFailurePhase)
      XCTAssertEqual(renderer.rasterizationCount, index, "Each reentry must rasterize a fresh equation, not just hit cache")
      let bitmap = try XCTUnwrap(NSBitmapImageRep(data: try XCTUnwrap(image.image.tiffRepresentation)))
      var hasInk = false
      for y in stride(from: 0, to: bitmap.pixelsHigh, by: max(1, bitmap.pixelsHigh / 64)) {
        for x in stride(from: 0, to: bitmap.pixelsWide, by: max(1, bitmap.pixelsWide / 256)) {
          if (bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.05 { hasInk = true }
        }
      }
      XCTAssertTrue(hasInk, "Snapshot completion with a transparent bitmap is not successful formula rendering")
      if let path = ProcessInfo.processInfo.environment["OPENUI_SNAPSHOT_DIR"] {
        try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
        try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
          .write(to: URL(fileURLWithPath: path).appendingPathComponent("d4-math-reentry-\(index).png"))
      }
      renderer.cancel()
      window.contentView = nil
    }
  }

  @MainActor func testOldMathHostDetachDoesNotCancelTheReplacementHost() async throws {
    _ = NSApplication.shared
    let renderer = NativeMathRenderer()
    let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 320, height: 100),
      styleMask: [.borderless], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false
    let root = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 100))
    let old = NSView(frame: NSRect(x: 0, y: 0, width: 1, height: 1))
    let next = NSView(frame: NSRect(x: 0, y: 0, width: 1, height: 1))
    root.addSubview(old); root.addSubview(next); window.contentView = root
    window.setFrameOrigin(NSPoint(x: -10000, y: -10000)); window.orderFront(nil)
    defer { renderer.cancel(); window.close() }
    renderer.attach(old); renderer.attach(next)
    old.removeFromSuperview(); renderer.attach(old); renderer.detach(old)
    let image = try await renderer.image(for: .init(tex: "x^{2} + 1", display: true), fontSize: 16, color: "#303036ff")
    XCTAssertGreaterThan(image.size.width, 0)
    XCTAssertEqual(renderer.pendingRequestCount, 0)
    XCTAssertNil(renderer.lastFailurePhase)
  }
}
#endif
