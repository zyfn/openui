import SwiftUI

/// A tap never competes with a reading drag. Action cards retain their primary
/// tap; their images expose preview through the native touch-and-hold menu.
struct NativeImageInteraction: ViewModifier {
  let source: String?
  let image: Image?
  let alt: String
  var enabled = true
  var previewEnabled = true
  var failed = false
  var previewTheme: OpenUIThemeValues? = nil
  let retry: () -> Void
  @Environment(\.openUITheme) private var theme
  @Environment(\.isEnabled) private var hostEnabled
  @Environment(\.openUICardIsAction) private var cardIsAction
  @Environment(\.openUIMediaSourceReady) private var sourceReady
  @Environment(\.openUIMediaWidthReady) private var widthReady
  @Environment(\.openUIActivationIntent) private var intent
  @State private var preview = false

  private var ready: Bool { enabled && hostEnabled && sourceReady && widthReady }
  private var canPreview: Bool { ready && previewEnabled && image != nil }
  private var canTap: Bool { ready && (failed || (canPreview && !cardIsAction)) }
  private func activate() {
    guard canTap, intent?.permitsActivation != false else { return }
    if failed { retry() } else { preview = true }
  }
  func body(content: Content) -> some View {
    content
      .gesture(TapGesture().onEnded { activate() }, including: canTap && !failed ? .all : .subviews)
      .highPriorityGesture(TapGesture().onEnded { activate() }, including: canTap && failed ? .all : .subviews)
      .contextMenu {
        if canPreview {
          Button { guard intent?.permitsActivation != false else { return }; preview = true } label: {
            Label { Text("View image", bundle: NativeControlResources.bundle) } icon: { Image(systemName: "photo") }
          }
        }
      }
      .accessibilityActions {
        if canTap {
          Button(action: activate) { Text(failed ? "Tap image to retry" : "View image", bundle: NativeControlResources.bundle) }
        } else if canPreview {
          Button { preview = true } label: { Text("View image", bundle: NativeControlResources.bundle) }
        }
      }
      .accessibilityHint(Text(canTap ? (failed ? "Tap image to retry" : "Tap to preview") : canPreview ? "Touch and hold to preview" : "", bundle: NativeControlResources.bundle))
      .sheet(isPresented: $preview) {
        NativeSingleImagePreview(source: source, image: image, alt: alt)
          .environment(\.openUITheme, previewTheme ?? theme)
      }
  }
}

struct NativeSingleImagePreview: View {
  let source: String?
  var image: Image? = nil
  var alt = ""
  @Environment(\.dismiss) private var dismiss
  @Environment(\.openUITheme) private var theme
  var body: some View {
    VStack(spacing: theme.spaceM) {
      NativeImagePreviewHeader(closeIdentifier: "openui.image.preview.close", close: { dismiss() })
      GeometryReader { _ in
        NativeRemoteImage(src: source, alt: alt, layout: .fit, cachedImage: image, previewEnabled: false)
          .modifier(NativeImageZoom())
      }
      if !alt.isEmpty {
        Text(alt).nativeTextStyle(theme.textStyle(.body)).lineLimit(2)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
    .padding(theme.spaceML).frame(idealWidth: 720, idealHeight: 640)
    .foregroundStyle(theme.textNeutralPrimary)
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("openui.image.preview")
  }
}

struct NativeImagePreviewHeader: View {
  var position: Int? = nil
  var count: Int = 1
  let closeIdentifier: String
  let close: () -> Void
  @Environment(\.openUITheme) private var theme
  var body: some View {
    HStack(spacing: theme.spaceM) {
      Text("Image preview", bundle: NativeControlResources.bundle).nativeTextStyle(theme.objectTitleStyle())
      Spacer(minLength: theme.spaceM)
      if let position, count > 1 {
        Text("\(position + 1) / \(count)").nativeTextStyle(theme.textStyle(.supporting)).monospacedDigit()
          .accessibilityIdentifier("openui.image.preview.position")
      }
      Button(action: close) { Image(systemName: "xmark").openUIControlTarget() }
        .buttonStyle(.plain).accessibilityLabel(Text("Close image preview", bundle: NativeControlResources.bundle))
        .keyboardShortcut(.cancelAction).accessibilityIdentifier(closeIdentifier)
    }
  }
}

struct NativeImageZoomState {
  var scale: CGFloat = 1
  var offset = CGSize.zero
  var isZoomed: Bool { scale > 1 }
  mutating func reset() { scale = 1; offset = .zero }
  mutating func setScale(_ proposed: CGFloat, size: CGSize) {
    scale = min(5, max(1, proposed))
    offset = bounded(offset, scale: scale, size: size)
  }
  func bounded(_ value: CGSize, scale: CGFloat, size: CGSize) -> CGSize {
    let x = max(0, size.width * (scale - 1) / 2), y = max(0, size.height * (scale - 1) / 2)
    return CGSize(width: min(x, max(-x, value.width)), height: min(y, max(-y, value.height)))
  }
}

struct NativeImageZoom: ViewModifier {
  var resetID: AnyHashable? = nil
  var zoomChanged: (Bool) -> Void = { _ in }
  @State private var state = NativeImageZoomState()
  @GestureState private var magnification: CGFloat = 1
  @GestureState private var translation = CGSize.zero
  func body(content: Content) -> some View {
    GeometryReader { geometry in
      let zoom = min(5, max(1, state.scale * magnification))
      let position = state.bounded(CGSize(width: state.offset.width + translation.width, height: state.offset.height + translation.height), scale: zoom, size: geometry.size)
      content.scaleEffect(zoom).offset(position)
        .frame(width: geometry.size.width, height: geometry.size.height).clipped().contentShape(Rectangle())
        .gesture(MagnificationGesture().updating($magnification) { value, state, _ in state = value }
          .onEnded { value in
            state.setScale(state.scale * value, size: geometry.size)
          })
        .simultaneousGesture(DragGesture().updating($translation) { value, translation, _ in if state.isZoomed { translation = value.translation } }
          .onEnded { value in if state.isZoomed {
            state.offset = state.bounded(CGSize(width: state.offset.width + value.translation.width, height: state.offset.height + value.translation.height), scale: state.scale, size: geometry.size)
          } }, including: state.isZoomed ? .all : .subviews)
        .onTapGesture(count: 2) { if state.isZoomed { state.reset() } else { state.setScale(2, size: geometry.size) } }
        .onChange(of: state.isZoomed) { zoomChanged($0) }
        .onChange(of: resetID) { _ in state.reset(); zoomChanged(false) }
        .accessibilityElement(children: .combine)
        .accessibilityValue(Text("\(Int(state.scale * 100))%"))
        .accessibilityAdjustableAction { direction in
          switch direction {
          case .increment: state.setScale(state.scale + 1, size: geometry.size)
          case .decrement: state.setScale(state.scale - 1, size: geometry.size)
          @unknown default: break
          }
        }
        .accessibilityIdentifier("openui.image.preview.zoom")
    }
  }
}
