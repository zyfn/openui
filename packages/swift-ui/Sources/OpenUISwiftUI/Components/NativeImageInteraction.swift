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
      HStack {
        Group {
          if alt.isEmpty { Text("Image", bundle: NativeControlResources.bundle) } else { Text(alt) }
        }.nativeTextStyle(theme.textStyle(.supporting)).lineLimit(2)
        Spacer(minLength: theme.spaceM)
        Button { dismiss() } label: { Image(systemName: "xmark").openUIControlTarget() }
          .buttonStyle(.plain).accessibilityLabel(Text("Close image preview", bundle: NativeControlResources.bundle))
          .keyboardShortcut(.cancelAction).accessibilityIdentifier("openui.image.preview.close")
      }
      GeometryReader { _ in
        NativeRemoteImage(src: source, alt: alt, layout: .fit, cachedImage: image, previewEnabled: false)
          .modifier(NativeImageZoom())
      }
    }
    .padding(theme.spaceML).frame(idealWidth: 720, idealHeight: 640)
    .foregroundStyle(theme.textNeutralPrimary)
    .accessibilityIdentifier("openui.image.preview")
  }
}

struct NativeImageZoom: ViewModifier {
  @State private var scale: CGFloat = 1
  @GestureState private var magnification: CGFloat = 1
  @State private var offset = CGSize.zero
  @GestureState private var translation = CGSize.zero
  private func bounded(_ value: CGSize, scale: CGFloat, size: CGSize) -> CGSize {
    let x = max(0, size.width * (scale - 1) / 2), y = max(0, size.height * (scale - 1) / 2)
    return CGSize(width: min(x, max(-x, value.width)), height: min(y, max(-y, value.height)))
  }
  func body(content: Content) -> some View {
    GeometryReader { geometry in
      let zoom = min(5, max(1, scale * magnification))
      let position = bounded(CGSize(width: offset.width + translation.width, height: offset.height + translation.height), scale: zoom, size: geometry.size)
      content.scaleEffect(zoom).offset(position)
        .frame(width: geometry.size.width, height: geometry.size.height).clipped().contentShape(Rectangle())
        .gesture(MagnificationGesture().updating($magnification) { value, state, _ in state = value }
          .onEnded { value in
            scale = min(5, max(1, scale * value))
            offset = bounded(offset, scale: scale, size: geometry.size)
          })
        .simultaneousGesture(DragGesture().updating($translation) { value, state, _ in if scale > 1 { state = value.translation } }
          .onEnded { value in if scale > 1 {
            offset = bounded(CGSize(width: offset.width + value.translation.width, height: offset.height + value.translation.height), scale: scale, size: geometry.size)
          } }, including: scale > 1 ? .all : .subviews)
        .onTapGesture(count: 2) { scale = scale > 1 ? 1 : 2; offset = .zero }
    }
  }
}
