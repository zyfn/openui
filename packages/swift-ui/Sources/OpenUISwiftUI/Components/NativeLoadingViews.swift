import SwiftUI

/// One loading surface for known media/data regions. Its motion changes only
/// pixels, never the region's dimensions or its containing layout.
struct NativeLoadingSurface: View {
  var active = true
  var showsMediaSymbol = false
  @Environment(\.openUIPresentation) private var nativePresentation

  @Environment(\.openUITheme) private var theme
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.layoutDirection) private var direction
  @Environment(\.scenePhase) private var scenePhase
  @State private var sweeping = false
  @State private var animating = false

  var body: some View {
    GeometryReader { geometry in
      ZStack {
        theme.sunk
        theme.textNeutralSecondary.opacity(0.035)
        if showsMediaSymbol && geometry.size.width >= 64 && geometry.size.height >= 48 {
          Image(systemName: "photo")
            .openUIFont(theme.textBodyDefault)
            .foregroundStyle(theme.textNeutralSecondary.opacity(0.22))
        }
        if animating {
          LinearGradient(colors: [.clear, .white.opacity(colorScheme == .dark ? 0.10 : 0.55), .clear],
            startPoint: .leading, endPoint: .trailing)
            .frame(width: geometry.size.width * 0.55)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .offset(x: (sweeping ? 1.1 : -0.65) * geometry.size.width
              * (direction == .rightToLeft ? -1 : 1))
            .animation(.linear(duration: nativePresentation.motion.loadingCycle)
              .repeatForever(autoreverses: false), value: sweeping)
            .onAppear { sweeping = true }
        }
      }
    }
    .allowsHitTesting(false).accessibilityHidden(true)
    .task(id: active && !reduceMotion && scenePhase == .active) {
      animating = false; sweeping = false
      guard active, !reduceMotion, scenePhase == .active else { return }
      do { try await Task.sleep(nanoseconds: nativePresentation.motion.loadingDelayNanoseconds) }
      catch { return }
      guard !Task.isCancelled else { return }
      animating = true
    }
  }
}

/// Only image opacity animates. A successful download never animates the
/// parent layout, the crop, or the dimensions of its neighboring text.
struct NativeMediaReveal: ViewModifier {
    @Environment(\.openUIPresentation) private var nativePresentation

  var enabled = true
  @Environment(\.openUITheme) private var theme
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var visible = false
  func body(content: Content) -> some View {
    ZStack {
      theme.sunk.opacity(visible || !enabled ? 0 : 1)
      content.opacity(visible || !enabled ? 1 : 0)
    }
      .onAppear {
        withAnimation(reduceMotion ? nil : .easeOut(duration: nativePresentation.motion.mediaRevealDuration)) {
          visible = true
        }
      }
  }
}
