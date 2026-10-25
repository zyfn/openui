import SwiftUI

struct ReviewHeader: View {
  @Environment(\.reviewLanguage) private var language
  let scenario: ReviewScenario?
  let program: ReviewProgram?
  let position: Int?
  let display: ReviewDisplayOptions
  let select: (ReviewProgram) -> Void
  let move: (Int) -> Void
  let toggleTheme: () -> Void
  let toggleBubble: () -> Void
  let toggleLanguage: () -> Void
  let isManual: Bool
  let restoreSample: () -> Void
  let open: (ReviewPanel) -> Void

  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: 4) {
        Button { open(.scenarios) } label: { Image(systemName: "sidebar.left") }
          .accessibilityLabel(language.text("场景目录")).accessibilityIdentifier("review.scenarios")
        Button { move(-1) } label: { Image(systemName: "chevron.left") }
          .disabled(position == nil).accessibilityLabel(language.text("上一场景")).accessibilityIdentifier("review.previous")
        VStack(spacing: 2) {
          Text(language.text(isManual ? "手动输入" : scenario?.title ?? "原样回放")).font(.headline).lineLimit(1)
            .accessibilityIdentifier("review.family-title")
          if let position {
            Text("\(position + 1) / \(ReviewCatalog.scenarios.count)").font(.caption).foregroundStyle(.secondary)
              .accessibilityIdentifier("review.scene-position")
          }
        }.frame(maxWidth: .infinity)
        Button { move(1) } label: { Image(systemName: "chevron.right") }
          .disabled(position == nil).accessibilityLabel(language.text("下一场景")).accessibilityIdentifier("review.next")
        Button { open(.source) } label: { Image(systemName: "chevron.left.forwardslash.chevron.right") }
          .accessibilityLabel(language.text("编写 openui-lang")).accessibilityIdentifier("review.editor")
        Menu {
          Button(language.text("编写 openui-lang")) { open(.source) }.accessibilityIdentifier("review.open-editor")
          if isManual {
            Button(language.text("恢复目录样例"), action: restoreSample).accessibilityIdentifier("review.restore-sample")
          }
          Button(language.text("组件目录")) { open(.components) }.accessibilityIdentifier("review.open-components")
          Button(language.text("覆盖与核心验收")) { open(.coverage) }
          Button(language.text("运行诊断")) { open(.diagnostics) }
        } label: { Image(systemName: "ellipsis") }
          .accessibilityLabel(language.text("检查工具")).accessibilityIdentifier("review.tools")
      }.buttonStyle(ReviewToolbarButtonStyle())

      HStack(spacing: 4) {
        Text(language.text(program?.title ?? "原样回放")).font(.subheadline.weight(.medium))
          .lineLimit(1)
          .accessibilityIdentifier("review.scene-title")
        if let scenario, scenario.variants.count > 1 {
          Menu {
            ForEach(scenario.variants) { item in
              Button(language.text(item.title)) { select(item) }.accessibilityIdentifier("review.variant.\(item.id)")
            }
          } label: { Image(systemName: "chevron.down").font(.caption.weight(.semibold)) }
            .frame(minWidth: 32, minHeight: 44).accessibilityLabel(language.text("切换变体"))
            .accessibilityIdentifier("review.variants")
        }
        Spacer(minLength: 0)
        Button(action: toggleLanguage) {
          Text(language == .english ? "EN" : "中文").font(.caption.weight(.semibold))
            .frame(width: 44, height: 44).contentShape(Rectangle())
        }
        .accessibilityLabel(language.text("切换预览语言"))
        .accessibilityValue(language.rawValue)
        .accessibilityHint(language.text("切换语言会重新运行目录样例；手动输入与外部回放保留原文。"))
        .accessibilityIdentifier("review.language-toggle")
        Button(action: toggleTheme) {
          Text(language.text(display.theme.compactTitle)).font(.caption.weight(.semibold))
            .frame(width: 44, height: 44).contentShape(Rectangle())
        }
        .accessibilityLabel(language.text("主题覆盖"))
        .accessibilityValue(display.theme.rawValue)
        .accessibilityHint(language.format("切换为 %@，保留内容与交互状态", language.text(display.theme.next.title)))
        .accessibilityIdentifier("review.theme-toggle")
        Button(action: toggleBubble) {
          Image(systemName: display.clientBubble ? "bubble.left.fill" : "bubble.left").frame(width: 44, height: 44)
        }
        .accessibilityLabel(language.text("客户端灰色气泡"))
        .accessibilityValue(language.text(display.clientBubble ? "开启" : "关闭"))
        .accessibilityIdentifier("review.toggle-bubble")
        Button { open(.conditions) } label: {
          VStack(spacing: 2) {
            Image(systemName: "slider.horizontal.3").font(.caption)
            Text(display.width == .available ? language.text("铺满") : display.width.title)
              .font(.caption2.monospacedDigit())
          }.frame(width: 44, height: 44)
        }.accessibilityLabel(language.text("预览条件")).accessibilityValue(language.text(display.width.title)).accessibilityHint(display.summary)
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
  @Environment(\.reviewLanguage) private var language
  @Binding var display: ReviewDisplayOptions

  var body: some View {
    Form {
      Section(language.text("宿主主题覆盖测试")) {
        Picker(language.text("主题"), selection: $display.theme) {
          ForEach(ReviewVisualTheme.allCases, id: \.rawValue) { theme in Text(language.text(theme.title)).tag(theme) }
        }.pickerStyle(.segmented).accessibilityIdentifier("review.theme-picker")
      }
      Section(language.text("容器宽度")) {
        Picker(language.text("可用宽度"), selection: $display.width) {
          ForEach(ReviewWidth.allCases, id: \.rawValue) { width in Text(language.text(width.title)).tag(width) }
        }.pickerStyle(.segmented).accessibilityIdentifier("review.width-picker")
      }
      Section(language.text("显示")) {
        Picker(language.text("语言"), selection: $display.language) {
          ForEach(ReviewLanguage.allCases, id: \.rawValue) { item in Text(language.text(item.title)).tag(item) }
        }.pickerStyle(.segmented).accessibilityIdentifier("review.language-picker")
        Toggle(language.text("大字体"), isOn: $display.largeText).accessibilityIdentifier("review.toggle-text")
        Toggle(language.text("深色外观"), isOn: $display.dark).accessibilityIdentifier("review.toggle-appearance")
        Toggle(language.text("客户端灰色气泡"), isOn: $display.clientBubble).accessibilityIdentifier("review.bubble-switch")
      }
      Section {
        Text(display.summary).font(.footnote).foregroundStyle(.secondary).accessibilityIdentifier("review.conditions")
        Button(language.text("恢复默认条件")) {
          let currentLanguage = display.language
          display = ReviewDisplayOptions()
          display.language = currentLanguage
        }
        Text(language.text("只改变预览约束，保留当前程序和本地交互状态。大字体只应用于 SDK 预览。"))
          .font(.footnote).foregroundStyle(.secondary)
      }
    }
  }
}
