import OpenUILang
import OpenUISwiftUI
import SwiftUI
import UIKit

struct ReviewCanvas: View {
  let library: OpenUIComponentLibrary
  @ObservedObject var state: OpenUIState
  @ObservedObject var evidence: ReviewEvidence
  let programID: String
  let source: String
  let display: ReviewDisplayOptions
  let inspector: Bool
  var sources: [CardSource] = []
  var request: String?
  var exportFull = false
  @StateObject private var capture = ReviewPageCapture()

  // Preview-only host surface, matching ChatResultTheme.assistant and the
  // client's bubble insets. It remains independent of the SDK visual theme.
  private static let clientBubbleColor = Color(uiColor: UIColor { traits in
    traits.userInterfaceStyle == .dark ? .secondarySystemBackground
      : UIColor(red: 232 / 255, green: 235 / 255, blue: 236 / 255, alpha: 1)
  })

  var body: some View {
    ScrollViewReader { scroll in
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          Color.clear.frame(height: 0).id("review.stream.start")
          if let request {
            HStack {
              Spacer(minLength: 44)
              Text(request).font(.subheadline).foregroundStyle(Color(uiColor: .label))
                .padding(.horizontal, 16).padding(.vertical, 12)
                .background(Color(uiColor: .secondarySystemBackground),
                  in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .accessibilityIdentifier("review.user-request")
            }
            .frame(maxWidth: display.width.maximum, alignment: .trailing)
            .frame(maxWidth: .infinity, alignment: .trailing)
          }
          VStack(alignment: .leading, spacing: 0) {
            CardSourceProvider(sources: sources) {
              OpenUIRenderer(state: state, registry: library.registry)
            }
              .openUITheme(display.theme.sdkTheme)
              .openUIResourceContext(OpenUIResourceContext(baseURL: URL(string: "https://sdk-fixture.invalid/")))
              .environment(\.openURL, OpenURLAction { url in
                if inspector { evidence.openedURL = url.absoluteString; return .handled }
                return .systemAction(url)
              })
          }
          .padding(.horizontal, display.clientBubble ? 16 : 0)
          .padding(.vertical, display.clientBubble ? 12 : 0)
          .frame(maxWidth: display.width.maximum, alignment: .leading)
          .background(display.clientBubble ? Self.clientBubbleColor : .clear,
            in: RoundedRectangle(cornerRadius: 24))
          .dynamicTypeSize(display.largeText ? .accessibility2 : .large)
          .accessibilityElement(children: .contain).accessibilityIdentifier("review.canvas")
          .frame(maxWidth: .infinity)
          if state.isComplete && !state.errors.isEmpty {
            Text(state.errors.map(\.message).joined(separator: "\n"))
              .foregroundStyle(.red).accessibilityIdentifier("review.errors")
          }
          if inspector { ReviewEvidenceFooter(state: state, evidence: evidence) }
          Color.clear.frame(height: 0).id("review.stream.end")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20).padding(.vertical, 24)
        .background(ReviewScrollLocator(capture: capture))
      }
      .background(display.theme.sdkTheme.canvas)
      .accessibilityIdentifier("review.surface")
      .onReceive(state.$root) { root in
        guard !exportFull else { return }
        // Follow only the SDK's rendered tree. Reset/replay returns to the
        // request, while growing content follows the newest on-screen element.
        let target = root == nil ? "review.stream.start" : "review.stream.end"
        guard root == nil || !state.isComplete else { return }
        DispatchQueue.main.async { scroll.scrollTo(target, anchor: root == nil ? .top : .bottom) }
      }
      // Only changing the DSL program replaces the renderer. Theme, appearance,
      // width and the preview bubble update values on the existing subtree.
      .id(programID)
      .task(id: state.isComplete) {
        if exportFull && state.isComplete {
          await capture.export(programID: programID, language: display.language.rawValue,
            source: source, request: request, diagnostics: state.errors.map(\.message))
        }
      }
    }
  }
}
