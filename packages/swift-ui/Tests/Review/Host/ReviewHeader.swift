import SwiftUI

struct ReviewHeader: View {
  @Environment(\.reviewLanguage) private var language
  let scenario: ReviewScenario?
  let program: ReviewProgram?
  let position: Int?
  let display: ReviewDisplayOptions
  let move: (Int) -> Void
  let toggleTheme: () -> Void
  let toggleBubble: () -> Void
  let toggleLanguage: () -> Void
  let isManual: Bool
  let isPlaying: Bool
  let playbackRate: ReviewPlaybackRate
  let setPlaybackRate: (ReviewPlaybackRate) -> Void
  let replay: () -> Void
  let restoreSample: () -> Void
  let open: (ReviewPanel) -> Void

  var body: some View {
    HStack(spacing: 4) {
      Button { open(.scenarios) } label: { Image(systemName: "sidebar.left") }
        .accessibilityLabel(language.text("场景目录")).accessibilityIdentifier("review.scenarios")
      Button { move(-1) } label: { Image(systemName: "chevron.left") }
        .disabled(position == nil).accessibilityLabel(language.text("上一场景")).accessibilityIdentifier("review.previous")
      VStack(spacing: 2) {
        Text(language.text(program?.title ?? scenario?.title ?? "原样回放"))
          .font(.headline).lineLimit(1).minimumScaleFactor(0.8)
          .accessibilityIdentifier("review.scene-title")
        if let position {
          Text("\(position + 1) / \(ReviewCatalog.scenarios.count)")
            .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            .accessibilityIdentifier("review.scene-position")
        }
      }.frame(maxWidth: .infinity)
      Button { move(1) } label: { Image(systemName: "chevron.right") }
        .disabled(position == nil).accessibilityLabel(language.text("下一场景")).accessibilityIdentifier("review.next")
      Button(action: replay) { Image(systemName: "arrow.clockwise") }
        .accessibilityLabel(language.text("重新播放"))
        .accessibilityValue(language.text(isPlaying ? "播放中" : "可重新播放"))
        .accessibilityIdentifier("review.replay")
      Menu {
        Button(language.text("编写 openui-lang")) { open(.source) }
          .accessibilityIdentifier("review.open-editor")
        Menu {
          ForEach(ReviewPlaybackRate.allCases) { rate in
            Button { setPlaybackRate(rate) } label: {
              if rate == playbackRate { Label(rate.title, systemImage: "checkmark") }
              else { Text(rate.title) }
            }
          }
        } label: { Text(language.text("回放速度") + " · " + playbackRate.title) }
          .accessibilityIdentifier("review.playback-rate")
        if isManual {
          Button(language.text("恢复目录样例"), action: restoreSample)
            .accessibilityIdentifier("review.restore-sample")
        }
        Section {
          Button(language == .english ? "简体中文" : "English", action: toggleLanguage)
            .accessibilityIdentifier("review.language-toggle")
          Button(language.text(display.theme.next.title), action: toggleTheme)
            .accessibilityIdentifier("review.theme-toggle")
          Button(language.text("客户端灰色气泡"), action: toggleBubble)
            .accessibilityIdentifier("review.toggle-bubble")
          Button(language.text("预览条件")) { open(.conditions) }
            .accessibilityIdentifier("review.conditions-menu")
        }
        Section {
          Button(language.text("组件目录")) { open(.components) }
            .accessibilityIdentifier("review.open-components")
          Button(language.text("覆盖与核心验收")) { open(.coverage) }
          Button(language.text("运行诊断")) { open(.diagnostics) }
        }
      } label: { Image(systemName: "ellipsis") }
        .accessibilityLabel(language.text("检查工具")).accessibilityIdentifier("review.tools")
    }
    .buttonStyle(ReviewToolbarButtonStyle())
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
