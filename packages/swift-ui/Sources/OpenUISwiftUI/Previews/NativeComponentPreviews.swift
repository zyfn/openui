#if DEBUG
    import SwiftUI
    import OpenUILang

    /// Development-only fixtures. Every control uses the default SDK registration.
    /// No application component override, transport, account or business data is used.
    enum SDKDesignVariant: Int, CaseIterable, Identifiable {
        case light, dark, hostLight, hostDark, accessibility, choices, actions, disabled, content, contentDark
        var id: Int { rawValue }
        var title: String {
            switch self {
            case .light: return "标准浅色"
            case .dark: return "标准深色"
            case .hostLight: return "宿主浅色"
            case .hostDark: return "宿主深色"
            case .accessibility: return "大字号与长标签"
            case .choices: return "选择与日期范围"
            case .actions: return "操作与加载"
            case .disabled: return "不可操作状态"
            case .content: return "内容与信息层级"
            case .contentDark: return "内容与信息层级 · 深色"
            }
        }
        var host: Bool { self == .hostLight || self == .hostDark }
        var scheme: ColorScheme { self == .dark || self == .hostDark || self == .contentDark ? .dark : .light }
    }

    @MainActor
    struct SDKDesignReviewBrowser: View {
        @State private var variant = SDKDesignVariant.light
        var body: some View {
            VStack(spacing: 0) {
                Picker("设计场景", selection: $variant) {
                    ForEach(SDKDesignVariant.allCases) { item in Text(item.title).tag(item) }
                }.pickerStyle(.menu).font(.subheadline).padding(8).accessibilityIdentifier("review.variant")
                Divider()
                SDKComponentShowcase(variant: variant).id(variant)
            }.preferredColorScheme(variant.scheme)
        }
    }

    private struct ShowcaseDelay: ToolProvider {
        func callTool(name: OpenUIString, arguments: OpenUIObject) async throws -> Value {
            try await Task.sleep(nanoseconds: 8_000_000_000)
            return .object([])
        }
    }

    @MainActor
    struct SDKComponentShowcase: View {
        let variant: SDKDesignVariant
        private let library: OpenUIComponentLibrary
        @StateObject private var state: OpenUIState
        @State private var actions = 0
        init(variant: SDKDesignVariant) {
            self.variant = variant
            // Static preview data; a failed registration is visible in package tests.
            let library = try! OpenUIStandardComponents.library()
            self.library = library
            let runtime = OpenUIState(schema: library.library.toSchema(), toolProvider: ShowcaseDelay())
            runtime.setSource(Self.source(variant), streaming: variant == .disabled)
            _state = StateObject(wrappedValue: runtime)
        }
        private var theme: OpenUITheme {
            var theme = OpenUITheme()
            if variant.host { theme.accent = Color(red: 0.12, green: 0.44, blue: 0.34) }
            return theme
        }
        var body: some View {
            Group {
                if variant.host {
                    content.font(.largeTitle).foregroundStyle(.orange).tint(.pink)
                        .textFieldStyle(.roundedBorder).buttonStyle(.borderless)
                } else {
                    content
                }
            }
            .openUITheme(theme).environment(\.locale, Locale(identifier: "zh-Hans"))
            .preferredColorScheme(variant.scheme)
            .dynamicTypeSize(variant == .accessibility ? .accessibility2 : .large)
            .onAppear { state.onAction = { _ in actions += 1 } }
        }
        private var content: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    OpenUIRenderer(state: state, registry: library.registry)
                    if [.light, .dark, .hostLight, .hostDark, .accessibility, .disabled].contains(variant) {
                        Text(state.stateValue("$date") == .null ? "日期尚未确定" : "日期已选择")
                            .font(.footnote).foregroundStyle(Color.secondary)
                            .accessibilityIdentifier(
                                state.stateValue("$date") == .null
                                    ? "review.date.empty" : "review.date.selected")
                        if actions > 0 {
                            Text("已收到本地提交").font(.footnote).foregroundStyle(Color.secondary)
                                .accessibilityIdentifier("review.submitted")
                        }
                    }
                }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color.primary.opacity(0.025)).clipped()
            .accessibilityIdentifier("review.content")
        }
        private static func source(_ variant: SDKDesignVariant) -> String {
            if variant == .content || variant == .contentDark {
                return """
                    root=Stack([
                      TextContent("本周概览", "small-heavy"),
                      TextContent("少一点忙碌，\\n多一点专注。", "large-heavy"),
                      TextContent("把信息整理清楚，让下一步更从容。", "small"),
                      Card([Stack([
                        MetricIndicatorWithStrikethrough("18", "已整理的事项"),
                        MetricIndicatorWithStrikethrough("6", "值得关注的更新")
                      ],"row","xl","start","between")]),
                      Stack([InlineHeader("接下来"),
                        Card([TextContent("留出一段完整的时间", "small-heavy"), TextContent("先处理最重要的一件事，其余的可以慢一点。", "small"), Button("查看安排", null, "tertiary")]),
                        Card([TextContent("给灵感一个去处", "small-heavy"), TextContent("把零散想法收在一起，需要时随手找到。", "small"), Button("整理笔记", null, "tertiary")])
                      ]),
                      Accordion([AccordionItem("sources", "信息来源", [TextContent("这里展示的是 SDK 自包含预览数据，不连接个人账户。", "small")])])
                    ],"column","l")
                    """
            }
            if variant == .choices {
                return """
                    root=Stack([TextContent("选择与日期", "large-heavy"), Form("choices",Buttons([Button("确定"),Button("稍后",null,"secondary")]),[
                      FormControl("日期范围",DatePicker("range","range",null,{from:"2026-11-01T00:00:00.000Z",to:"2026-11-03T00:00:00.000Z"})),
                      FormControl("接收方式",RadioGroup("channel",[RadioItem("邮件","接收一份内容摘要","email"),RadioItem("通知","只显示重要更新","notification")],"email")),
                      FormControl("包含内容",CheckBoxGroup("items",[CheckBoxItem("摘要","简洁呈现关键信息","summary",true),CheckBoxItem("原文链接","保留进一步阅读的入口","source",false)]))
                    ])])
                    """
            }
            if variant == .actions {
                return """
                    save=Mutation("preview.save",{})
                    root=Stack([TextContent("清晰的操作层级","large-heavy"),TextContent("选择一种操作，观察反馈与状态。"),
                      Buttons([Button("保存",@Run(save)),Button("稍后",null,"secondary")]),
                      Button("查看说明",null,"tertiary"),Button("删除",null,"secondary","destructive"),
                      TextContent(save.status=="loading"?"正在保存":save.status=="success"?"保存完成":"等待保存","small")])
                    """
            }
            let title = variant == .accessibility ? "请为这件重要的事项填写一个足够清晰的标题" : "标题"
            return """
                $title=""
                $category="personal"
                $date=null
                $notifications={enabled:false}
                root=Stack([TextContent("创建一个提醒","large-heavy"),TextContent("记录重要的事，留出从容安排的空间。","small"),
                  Form("reminder",Buttons([Button("保存提醒",@ToAssistant("根据表单继续")),Button("重置",@Reset($title,$date,$notifications),"secondary")]),[
                    FormControl("\(title)",Input("title","需要记住什么",null,{required:true},$title)),
                    FormControl("分类",Select("category",[SelectItem("personal","个人事项"),SelectItem("work","工作安排"),SelectItem("learning","学习计划")],null,null,$category)),
                    FormControl("日期",DatePicker("date","single",null,$date)),
                    FormControl("通知",SwitchGroup("notifications",[SwitchItem("到时通知","为重要事项保留一个提醒入口","enabled",false)],null,$notifications))
                  ])])
                """
        }
    }

    @MainActor
    struct SDKNativeDesign_Previews: PreviewProvider {
        static var previews: some View {
            Group {
                SDKComponentShowcase(variant: .light).previewDisplayName("Default · Light")
                SDKComponentShowcase(variant: .dark).previewDisplayName("Default · Dark")
                SDKComponentShowcase(variant: .hostLight).previewDisplayName("Host inheritance · Light")
                SDKComponentShowcase(variant: .hostDark).previewDisplayName("Host inheritance · Dark")
                SDKComponentShowcase(variant: .accessibility).previewDisplayName(
                    "Accessibility · Long labels")
            }
        }
    }
#endif
