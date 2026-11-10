import SwiftUI

struct NativeTableSkeleton: View {
  @Environment(\.openUITheme) private var theme
  @Environment(\.displayScale) private var displayScale
  @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1
  var body: some View {
    NativeLoadingSurface()
      .frame(height: theme.textBodySmHeavy.resolved(for: .control).measuredLineHeight(scale: scale)
        + theme.spaceS * 2 + 1 / displayScale)
      .clipShape(RoundedRectangle(cornerRadius: theme.radius3xs))
      .frame(maxWidth: .infinity)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(Text("Loading data", bundle: NativeControlResources.bundle))
      .accessibilityIdentifier("openui.table.loading")
  }
}

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

/// No numeric labels, bars or percentage arcs are invented while data arrives.
struct NativeChartPlaceholder: View {
  let name: String
  let loading: Bool
  let failed: Bool
  let incomplete: Bool
  @Environment(\.openUITheme) private var theme
  private var message: LocalizedStringKey {
    failed ? "Unable to load chart" : incomplete ? "Chart is incomplete" : "No data"
  }
  var body: some View {
    ZStack {
      NativeLoadingSurface(active: loading)
      if loading {
        if ["PieChart", "RadialChart", "RadarChart"].contains(name) {
          Circle().stroke(theme.borderDefault, lineWidth: 1).padding(theme.space2xl)
        } else {
          GeometryReader { geometry in
            Path { path in
              let rect = CGRect(origin: .zero, size: geometry.size).insetBy(dx: theme.spaceML, dy: theme.spaceML)
              for fraction in [CGFloat(0), 0.5, 1] {
                let y = rect.minY + rect.height * fraction
                path.move(to: CGPoint(x: rect.minX, y: y))
                path.addLine(to: CGPoint(x: rect.maxX, y: y))
              }
            }.stroke(theme.borderDefault, lineWidth: 1)
          }
        }
      } else {
        ViewThatFits(in: .vertical) {
          Text(message, bundle: NativeControlResources.bundle)
            .nativeTextStyle(theme.textStyle(.supporting)).lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true).padding(theme.spaceML)
          Image(systemName: "chart.xyaxis.line")
            .nativeTextStyle(theme.textStyle(.supporting))
        }
      }
    }
    .clipShape(RoundedRectangle(cornerRadius: theme.radiusM))
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Text(loading ? "Loading data" : message, bundle: NativeControlResources.bundle))
    .accessibilityIdentifier(loading ? "openui.chart.loading" : failed ? "openui.chart.unavailable" : incomplete ? "openui.chart.incomplete" : "openui.chart.empty")
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
