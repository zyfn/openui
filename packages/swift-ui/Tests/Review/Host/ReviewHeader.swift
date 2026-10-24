import SwiftUI

struct ReviewHeader: View {
  let scenario: ReviewScenario?
  let program: ReviewProgram?
  let position: Int?
  let display: ReviewDisplayOptions
  let select: (ReviewProgram) -> Void
  let move: (Int) -> Void
  let toggleTheme: () -> Void
  let toggleBubble: () -> Void
  let isManual: Bool
  let restoreSample: () -> Void
  let open: (ReviewPanel) -> Void

  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: 4) {
        Button { open(.scenarios) } label: { Image(systemName: "sidebar.left") }
          .accessibilityLabel("场景目录").accessibilityIdentifier("review.scenarios")
        Button { move(-1) } label: { Image(systemName: "chevron.left") }
          .disabled(position == nil).accessibilityLabel("上一场景").accessibilityIdentifier("review.previous")
        VStack(spacing: 2) {
          Text(isManual ? "手动输入" : scenario?.title ?? "原样回放").font(.headline).lineLimit(1)
            .accessibilityIdentifier("review.family-title")
          if let position {
            Text("\(position + 1) / \(ReviewCatalog.scenarios.count)").font(.caption).foregroundStyle(.secondary)
              .accessibilityIdentifier("review.scene-position")
          }
        }.frame(maxWidth: .infinity)
        Button { move(1) } label: { Image(systemName: "chevron.right") }
          .disabled(position == nil).accessibilityLabel("下一场景").accessibilityIdentifier("review.next")
        Button { open(.source) } label: { Image(systemName: "chevron.left.forwardslash.chevron.right") }
          .accessibilityLabel("编写 openui-lang").accessibilityIdentifier("review.editor")
        Menu {
          Button("编写 openui-lang") { open(.source) }.accessibilityIdentifier("review.open-editor")
          if isManual {
            Button("恢复目录样例", action: restoreSample).accessibilityIdentifier("review.restore-sample")
          }
          Button("组件目录") { open(.components) }.accessibilityIdentifier("review.open-components")
          Button("覆盖与核心验收") { open(.coverage) }
          Button("运行诊断") { open(.diagnostics) }
        } label: { Image(systemName: "ellipsis") }
          .accessibilityLabel("检查工具").accessibilityIdentifier("review.tools")
      }.buttonStyle(ReviewToolbarButtonStyle())

      HStack(spacing: 4) {
        Text(program?.title ?? "原样回放").font(.subheadline.weight(.medium))
          .lineLimit(1)
          .accessibilityIdentifier("review.scene-title")
        if let scenario, scenario.variants.count > 1 {
          Menu {
            ForEach(scenario.variants) { item in
              Button(item.title) { select(item) }.accessibilityIdentifier("review.variant.\(item.id)")
            }
          } label: { Image(systemName: "chevron.down").font(.caption.weight(.semibold)) }
            .frame(minWidth: 32, minHeight: 44).accessibilityLabel("切换变体")
            .accessibilityIdentifier("review.variants")
        }
        Spacer(minLength: 0)
        Button(action: toggleTheme) {
          Text(display.theme.compactTitle).font(.caption.weight(.semibold))
            .frame(width: 44, height: 44).contentShape(Rectangle())
        }
        .accessibilityLabel("主题覆盖")
        .accessibilityValue(display.theme.rawValue)
        .accessibilityHint("切换为 \(display.theme.next.title)，保留内容与交互状态")
        .accessibilityIdentifier("review.theme-toggle")
        Button(action: toggleBubble) {
          Image(systemName: display.clientBubble ? "bubble.left.fill" : "bubble.left").frame(width: 44, height: 44)
        }
        .accessibilityLabel("客户端灰色气泡")
        .accessibilityValue(display.clientBubble ? "开启" : "关闭")
        .accessibilityIdentifier("review.toggle-bubble")
        Button { open(.conditions) } label: {
          Image(systemName: "slider.horizontal.3").frame(width: 44, height: 44)
        }.accessibilityLabel("预览条件").accessibilityValue(display.width.title).accessibilityHint(display.summary)
          .accessibilityIdentifier("review.conditions-menu")
      }.buttonStyle(.plain).padding(.horizontal, 16)
    }
    .foregroundStyle(.primary).padding(.horizontal, 4)
    .accessibilityElement(children: .contain).accessibilityIdentifier("review.scene-navigation")
  }
}

private struct ReviewToolbarButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label.font(.body.weight(.medium)).frame(width: 44, height: 44)
      .contentShape(Rectangle()).opacity(configuration.isPressed ? 0.5 : 1)
  }
}

struct ReviewConditions: View {
  @Binding var display: ReviewDisplayOptions

  var body: some View {
    Form {
      Section("宿主主题覆盖测试") {
        Picker("主题", selection: $display.theme) {
          ForEach(ReviewVisualTheme.allCases, id: \.rawValue) { theme in Text(theme.title).tag(theme) }
        }.pickerStyle(.segmented).accessibilityIdentifier("review.theme-picker")
      }
      Section("容器宽度") {
        Picker("可用宽度", selection: $display.width) {
          ForEach(ReviewWidth.allCases, id: \.rawValue) { width in Text(width.title).tag(width) }
        }.pickerStyle(.segmented).accessibilityIdentifier("review.width-picker")
      }
      Section("显示") {
        Toggle("大字体", isOn: $display.largeText).accessibilityIdentifier("review.toggle-text")
        Toggle("深色外观", isOn: $display.dark).accessibilityIdentifier("review.toggle-appearance")
        Toggle("客户端灰色气泡", isOn: $display.clientBubble).accessibilityIdentifier("review.bubble-switch")
      }
      Section {
        Text(display.summary).font(.footnote).foregroundStyle(.secondary).accessibilityIdentifier("review.conditions")
        Button("恢复默认条件") { display = ReviewDisplayOptions() }
        Text("只改变预览约束，保留当前程序和本地交互状态。大字体只应用于 SDK 预览。")
          .font(.footnote).foregroundStyle(.secondary)
      }
    }
  }
}
