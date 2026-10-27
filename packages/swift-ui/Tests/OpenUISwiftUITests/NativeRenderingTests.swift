#if os(macOS)
    import AppKit
    import XCTest
    import SwiftUI
    import OpenUILang
    @testable import OpenUISwiftUI

    final class NativeRenderingTests: XCTestCase {
        @MainActor func testPendingPositionalLayoutDoesNotPresentAFullWidthInlineImage() throws {
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
            XCTAssertLessThan(pending, 100, "A missing row argument must not temporarily produce a full-width photo")
            state.push(" beside the image\")],\"row\",\"m\",\"stretch\",\"start\",false)")
            state.complete()
            XCTAssertTrue(state.errors.isEmpty)
            XCTAssertGreaterThan(try height(), pending)
            XCTAssertLessThan(try height(), 240)
            state.reset()
            state.push("root=Stack([Stack([Image(\"Photo\",null),TextContent(\"Known local row\")],\"row\",\"m\",\"stretch\",\"start\",false)")
            XCTAssertGreaterThan(try height(), 100,
                "A resolved local row must show its media without waiting for the whole outer response")
        }

        @MainActor func testNativeAndRichTextBothRespondToTheSameThemeFont() throws {
            _ = NSApplication.shared
            let library = try OpenUIStandardComponents.library()
            func height(_ source: String, theme: OpenUITheme) throws -> CGFloat {
                let state = OpenUIState(schema: library.library.toSchema())
                state.setSource(source)
                XCTAssertTrue(state.errors.isEmpty)
                let renderer = ImageRenderer(content:
                    OpenUIRenderer(state: state, registry: library.registry).openUITheme(theme))
                renderer.proposedSize = ProposedViewSize(width: 320, height: nil)
                return try XCTUnwrap(renderer.nsImage).size.height
            }
            let ordinary = OpenUITheme()
            var enlarged = ordinary
            enlarged.typography.body.size = 25
            enlarged.typography.detail.size = 23
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

        @MainActor func testCompactCardDoesNotFillAnUnrequestedParentHeight() throws {
            _ = NSApplication.shared
            let library = try OpenUIStandardComponents.library()
            let state = OpenUIState(schema: library.library.toSchema())
            state.setSource("root=Card([TextContent(\"A compact card\")])")
            XCTAssertTrue(state.errors.isEmpty)
            guard #available(macOS 13, *) else { throw XCTSkip("Native Layout requires macOS 13") }
            let renderer = ImageRenderer(content: OpenUIRenderer(state: state, registry: library.registry))
            renderer.proposedSize = ProposedViewSize(width: 320, height: 400)
            let image = try XCTUnwrap(renderer.nsImage)
            XCTAssertGreaterThan(image.size.height, 32)
            XCTAssertLessThan(image.size.height, 160, "A height proposal is a constraint, not a request to fill it")
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
#endif
