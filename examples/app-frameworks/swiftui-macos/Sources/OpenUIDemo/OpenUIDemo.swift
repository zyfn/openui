import AppKit
import SwiftUI
import OpenUILang
import OpenUISwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@main
struct OpenUIDemoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    var body: some Scene {
        WindowGroup("OpenUI · Swift Playground") {
            Playground().frame(minWidth: 960, minHeight: 650)
        }.defaultSize(width: 1180, height: 780)
    }
}

private enum DemoLibrary {
    static let schema = LibrarySchema(components: [
        "Stack": [ParamDef(name: "children", required: true)],
        "Card": [ParamDef(name: "title", required: true), ParamDef(name: "children", required: false)],
        "Text": [ParamDef(name: "text", required: true), ParamDef(name: "variant", required: false)],
        "Tag": [ParamDef(name: "text", required: true)],
        "Metric": [ParamDef(name: "label", required: true), ParamDef(name: "value", required: true)],
        "Button": [ParamDef(name: "label", required: true)],
    ], callDefs: builtinCallDefs, rootComponent: "Stack")

    static let source = #"""
    root = Stack([
      Text("用 Swift，接住生成的界面", "heading"),
      Text("左侧编辑 OpenUI Lang，右侧由原生 SwiftUI 实时渲染。"),
      Card("周末 · 杭州慢游", [
        Tag("原生 SwiftUI"),
        Text("沿西湖散步，在龙井村喝一杯茶。"),
        Metric("计划天数", 2),
        Button("收藏这份计划")
      ]),
      Card("本地 Query 演示", [Text(trip.message)])
    ])
    trip = Query("loadTrip", {}, {message: "等待获取行程 · 点击上方「模拟 Query」"})
    """#

    static func registry(onButton: @escaping () -> Void) -> ComponentRegistry {
        [
            "Stack": { element, registry in
                AnyView(VStack(alignment: .leading, spacing: 18) {
                    Children(element: element, registry: registry)
                }.frame(maxWidth: .infinity, alignment: .leading))
            },
            "Card": { element, registry in
                AnyView(VStack(alignment: .leading, spacing: 14) {
                    Text(PropValue.string(element, "title") ?? "").font(.headline)
                    Divider()
                    Children(element: element, registry: registry)
                }.padding(22).frame(maxWidth: .infinity, alignment: .leading)
                    .background(.background, in: RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(.quaternary)))
            },
            "Text": { element, _ in
                AnyView(Text(PropValue.string(element, "text") ?? "")
                    .font(PropValue.string(element, "variant") == "heading" ? .title2.weight(.semibold) : .body)
                    .fixedSize(horizontal: false, vertical: true))
            },
            "Tag": { element, _ in
                AnyView(Text(PropValue.string(element, "text") ?? "").font(.caption.weight(.medium))
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .foregroundStyle(.teal).background(.teal.opacity(0.1), in: Capsule()))
            },
            "Metric": { element, _ in
                let value = element.props.first { $0.0 == "value" }?.1
                let number: String
                if case .number(let n) = value { number = n.formatted() } else { number = "—" }
                return AnyView(HStack(alignment: .firstTextBaseline) {
                    Text(number).font(.system(size: 36, weight: .semibold, design: .rounded))
                    Text(PropValue.string(element, "label") ?? "").foregroundStyle(.secondary)
                })
            },
            "Button": { element, _ in
                AnyView(Button(PropValue.string(element, "label") ?? "按钮", action: onButton)
                    .buttonStyle(.borderedProminent).tint(.teal))
            },
        ]
    }
}

private struct Children: View {
    let element: EvaluatedElement
    let registry: ComponentRegistry
    private struct Child: Identifiable {
        let id: String
        let element: EvaluatedElement
    }
    private var children: [Child] {
        PropValue.children(element).enumerated().map { index, child in
            Child(id: child.statementId ?? "child-\(index)", element: child)
        }
    }
    var body: some View {
        ForEach(children) { child in RenderNode(element: child.element, registry: registry) }
    }
}

private struct MockTools: ToolProvider {
    func callTool(name: OpenUIString, arguments: OpenUIObject) async throws -> Value {
        try await Task.sleep(nanoseconds: 1_200_000_000)
        guard name == "loadTrip" else { throw ToolNotFoundError(toolName: name) }
        return .object([ObjectField(key: "message", value: .string("行程已就绪：09:30 西湖散步 → 12:00 龙井村午餐 → 15:00 茶园小坐。"))])
    }
}

@MainActor
private struct Playground: View {
    @StateObject private var state = OpenUIState(schema: DemoLibrary.schema, toolProvider: MockTools())
    @State private var source = DemoLibrary.source
    @State private var playback: Task<Void, Never>?
    @State private var isPlaying = false
    @State private var savedCount = 0
    private var queryLoading: Bool { state.queryStates["trip"]?.status == .loading }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "square.stack.3d.up.fill").foregroundStyle(.teal)
                VStack(alignment: .leading, spacing: 3) {
                    Text("OpenUI / Swift").font(.headline)
                    Text("原生渲染实验室").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("恢复示例") {
                    cancelPlayback(); source = DemoLibrary.source; render()
                }
                Button(isPlaying ? "停止播放" : "流式播放") {
                    if isPlaying { cancelPlayback(); render() } else { stream() }
                }
                Button("模拟 Query") {
                    state.runQuery(statementId: "trip", tool: "loadTrip", args: .object([]))
                }.disabled(isPlaying || queryLoading || !state.isComplete || state.queryStates["trip"] == nil)
            }.padding(20)
            Divider()
            HSplitView {
                VStack(alignment: .leading, spacing: 12) {
                    Label("OPENUI LANG", systemImage: "chevron.left.forwardslash.chevron.right")
                        .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    TextEditor(text: $source).font(.system(size: 13, design: .monospaced))
                        .scrollContentBackground(.hidden).padding(12)
                        .background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 12))
                        .disabled(isPlaying)
                    Text("修改源码自动渲染 · 全部数据在本地模拟").font(.caption).foregroundStyle(.secondary)
                }.padding(20).frame(minWidth: 360, idealWidth: 470)
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack {
                            Label("SWIFTUI PREVIEW", systemImage: "macwindow")
                            Spacer()
                            Text(isPlaying ? "流式生成中" : "已完成")
                                .foregroundStyle(isPlaying ? .orange : .teal)
                        }.font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        if queryLoading {
                            HStack { ProgressView().controlSize(.small); Text("正在获取本地模拟行程…") }
                                .font(.callout).foregroundStyle(.secondary)
                        }
                        OpenUIRenderer(state: state, registry: DemoLibrary.registry { savedCount += 1 })
                        if savedCount > 0 {
                            Label("已收藏 · 点击了 \(savedCount) 次", systemImage: "checkmark.circle.fill")
                                .font(.callout).foregroundStyle(.teal)
                        }
                        if !state.errors.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("解析提示").font(.headline)
                                ForEach(Array(state.errors.enumerated()), id: \.offset) { _, error in
                                    Text(error.message).font(.caption).textSelection(.enabled)
                                }
                            }.padding().background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                        }
                    }.padding(26).frame(maxWidth: .infinity, alignment: .leading)
                }.background(.primary.opacity(0.025)).frame(minWidth: 480)
            }
        }
        .onAppear { render() }
        .onChange(of: source) { _ in if !isPlaying { render() } }
        .onDisappear { cancelPlayback() }
    }

    private func render() { state.reset(); state.push(source); state.complete() }
    private func cancelPlayback() { playback?.cancel(); playback = nil; isPlaying = false }
    private func stream() {
        cancelPlayback(); state.reset(); isPlaying = true
        let characters = Array(source)
        playback = Task { @MainActor in
            for start in stride(from: 0, to: characters.count, by: 7) {
                guard !Task.isCancelled else { return }
                state.push(String(characters[start..<min(start + 7, characters.count)]))
                do { try await Task.sleep(nanoseconds: 45_000_000) } catch { return }
            }
            state.complete(); isPlaying = false; playback = nil
        }
    }
}
