import SwiftUI

/// One layout pass measures all pages and places them in a clipped viewport.
/// Page height is intrinsic, including updates inside a mounted page; it is not
/// fed back asynchronously through a horizontal ScrollView's fixed frame.
struct NativePager<ID: Hashable, Content: View>: View {
  let ids: [ID]
  @Binding var selection: ID
  let enabled: Bool
  let identifier: String
  var showsControls = true
  var maximumHeight: CGFloat? = nil
  var maximumPageWidth: CGFloat? = nil
  var trailingPeek: CGFloat = 0
  var pageSpacing: CGFloat = 0
  @ViewBuilder let content: (ID) -> Content
  @Namespace private var scope
  @State private var width: CGFloat = 0
  @State private var naturalHeight: CGFloat = 0
  @GestureState private var translation: CGFloat = 0
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.layoutDirection) private var direction
  @Environment(\.openUITheme) private var theme
  private var index: Int { ids.firstIndex(of: selection) ?? 0 }
  private var isCarousel: Bool { maximumPageWidth != nil }
  private var fallbackWidth: CGFloat { maximumPageWidth ?? theme.minimumCardWidth }
  private var geometry: NativePagerGeometry {
    NativePagerGeometry(
      width: max(1, width), count: ids.count, selected: index,
      maximumPageWidth: maximumPageWidth, minimumPageWidth: theme.minimumCardWidth,
      peek: trailingPeek, spacing: pageSpacing)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      if let maximumHeight {
        // Only explicitly capped map previews need a vertical scroll viewport.
        ScrollView(.vertical, showsIndicators: naturalHeight > maximumHeight) { strip }
          .frame(height: min(max(1, naturalHeight), maximumHeight))
      } else {
        strip
      }
      if showsControls && ids.count > 1 {
        NativePageControls(page: index, count: ids.count, enabled: enabled, identifier: identifier, select: select)
      }
    }
    .frame(idealWidth: fallbackWidth, maxWidth: .infinity, alignment: .leading)
    .animation(
      reduceMotion
        ? nil
        : .interactiveSpring(
          response: theme.motion.pagingResponse,
          dampingFraction: theme.motion.pagingDamping), value: selection
    )
    .onChange(of: ids) { available in
      if !available.contains(selection), let first = available.first { selection = first }
    }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier(identifier + ".pager")
    .accessibilityAdjustableAction { action in
      switch action {
      case .increment: select(index + 1)
      case .decrement: select(index - 1)
      @unknown default: break
      }
    }
  }

  private var strip: some View {
    NativePagerLayout(
      selected: index, maximumPageWidth: maximumPageWidth,
      minimumPageWidth: theme.minimumCardWidth, peek: trailingPeek, spacing: pageSpacing,
      fallbackWidth: fallbackWidth, translation: translation, rightToLeft: direction == .rightToLeft
    ) {
      ForEach(ids, id: \.self) { id in
        content(id).id(id).accessibilityHidden(!isCarousel && id != selection)
      }
    }
    .clipped().contentShape(Rectangle())
    .background(
      GeometryReader { measured in
        Color.clear.preference(key: NativePagerSizes.self, value: [scope: measured.size])
      }
    )
    .onPreferenceChange(NativePagerSizes.self) { sizes in
      guard let size = sizes[scope], size.width.isFinite, size.height.isFinite else { return }
      if abs(size.width - width) > 0.5 { width = size.width }
      if maximumHeight != nil, abs(size.height - naturalHeight) > 0.5 { naturalHeight = size.height }
    }
    .simultaneousGesture(
      DragGesture(minimumDistance: 16)
        .updating($translation) { value, current, _ in
          guard enabled, ids.count > 1, abs(value.translation.width) > abs(value.translation.height) else { return }
          let movement = value.translation.width * (direction == .rightToLeft ? -1 : 1)
          let edge = (index == 0 && movement > 0) || (index == ids.count - 1 && movement < 0)
          current = movement * (edge ? 0.2 : 1)
        }
        .onEnded { value in
          guard enabled, abs(value.translation.width) > abs(value.translation.height),
            abs(value.predictedEndTranslation.width) > max(24, geometry.stride * 0.2)
          else { return }
          let movement = value.predictedEndTranslation.width * (direction == .rightToLeft ? -1 : 1)
          select(index + (movement < 0 ? 1 : -1))
        })
  }

  private func select(_ next: Int) {
    guard enabled, ids.indices.contains(next) else { return }
    selection = ids[next]
  }
}

struct NativePagerGeometry {
  let width: CGFloat
  let pageWidth: CGFloat
  let stride: CGFloat
  let offset: CGFloat

  init(
    width: CGFloat, count: Int, selected: Int, maximumPageWidth: CGFloat?,
    minimumPageWidth: CGFloat, peek: CGFloat, spacing: CGFloat
  ) {
    self.width = max(1, width.isFinite ? width : 1)
    if let maximumPageWidth {
      let visiblePeek = min(max(0, peek), max(0, self.width - minimumPageWidth - spacing))
      let reservation = count > 1 && visiblePeek > 0 ? visiblePeek + spacing : 0
      pageWidth = min(max(1, maximumPageWidth), max(1, self.width - reservation))
    } else {
      pageWidth = self.width
    }
    stride = pageWidth + spacing
    let end = max(0, CGFloat(count) * pageWidth + CGFloat(max(0, count - 1)) * spacing - self.width)
    offset = min(max(0, CGFloat(selected) * stride), end)
  }
}

private struct NativePagerLayout: Layout {
  let selected: Int
  let maximumPageWidth: CGFloat?
  let minimumPageWidth: CGFloat
  let peek: CGFloat
  let spacing: CGFloat
  let fallbackWidth: CGFloat
  let translation: CGFloat
  let rightToLeft: Bool

  private func geometry(_ proposal: ProposedViewSize, count: Int) -> NativePagerGeometry {
    let width = proposal.width.flatMap { $0.isFinite ? $0 : nil } ?? fallbackWidth
    return NativePagerGeometry(
      width: width, count: count, selected: selected,
      maximumPageWidth: maximumPageWidth, minimumPageWidth: minimumPageWidth, peek: peek, spacing: spacing)
  }
  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let layout = geometry(proposal, count: subviews.count)
    let height =
      subviews.map { $0.sizeThatFits(ProposedViewSize(width: layout.pageWidth, height: nil)).height }
      .filter { $0.isFinite }.max() ?? 0
    return CGSize(width: layout.width, height: height)
  }
  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    let layout = geometry(ProposedViewSize(width: bounds.width, height: nil), count: subviews.count)
    let pageHeight = subviews.map { $0.sizeThatFits(ProposedViewSize(width: layout.pageWidth, height: nil)).height }
      .filter { $0.isFinite }.max() ?? 0
    for (index, view) in subviews.enumerated() {
      let position = CGFloat(index) * layout.stride - layout.offset + translation
      let x = rightToLeft ? bounds.width - layout.pageWidth - position : position
      view.place(
        at: CGPoint(x: bounds.minX + x, y: bounds.minY), anchor: .topLeading,
        proposal: ProposedViewSize(width: layout.pageWidth, height: pageHeight))
    }
  }
}

private struct NativePagerSizes: PreferenceKey {
  static let defaultValue: [Namespace.ID: CGSize] = [:]
  static func reduce(value: inout [Namespace.ID: CGSize], nextValue: () -> [Namespace.ID: CGSize]) {
    value.merge(nextValue(), uniquingKeysWith: { _, next in next })
  }
}
