import SwiftUI

/// Paging accepts arbitrary views and stable selection ids. Current systems use
/// SwiftUI scroll targets; the older-system gesture adapter shares the same
/// content measurement and selection, without a second card implementation.
struct NativePager<ID: Hashable, Content: View>: View {
  let ids: [ID]
  @Binding var selection: ID
  let enabled: Bool
  let identifier: String
  var showsControls = true
  var maximumHeight: CGFloat? = nil
  @ViewBuilder let content: (ID) -> Content
  @Namespace private var measurementScope
  @State private var width: CGFloat = 0
  @State private var heights: [ID: CGFloat] = [:]
  @GestureState private var translation: CGFloat = 0
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.openUITheme) private var theme
  private var index: Int { ids.firstIndex(of: selection) ?? 0 }
  private var height: CGFloat? { heights[selection] ?? heights.values.max() }
  private var visibleHeight: CGFloat? { height.map { min($0, maximumHeight ?? $0) } }
  private var position: Binding<ID?> {
    Binding(get: { selection }, set: { if let id = $0, enabled, ids.contains(id) { selection = id } })
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      if width > 0 {
        ScrollView(.vertical, showsIndicators: false) {
          viewport.frame(height: height, alignment: .top)
        }
        .frame(idealHeight: visibleHeight, maxHeight: visibleHeight)
        if showsControls && ids.count > 1 {
          NativePageControls(page: index, count: ids.count, enabled: enabled, identifier: identifier, select: select)
        }
      } else {
        // Establish a real viewport before measuring text or images. A synthetic
        // one-point proposal can produce invalid intrinsic text dimensions.
        Color.clear.frame(height: 1)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(GeometryReader { geometry in
      Color.clear.preference(key: NativePagerWidths.self, value: [measurementScope: geometry.size.width])
    })
    .onPreferenceChange(NativePagerWidths.self) { measurements in
      guard let next = measurements[measurementScope], next.isFinite, next > 0 else { return }
      if abs(next - width) > 0.5 { width = next }
    }
    .onPreferenceChange(NativePagerHeights<ID>.self) { measurements in
      let measured = (measurements[measurementScope] ?? [:]).filter { $0.value.isFinite && $0.value > 0 }
      let updated = heights.merging(measured, uniquingKeysWith: { _, next in next })
      if updated != heights { heights = updated }
    }
    .onChange(of: ids) { available in
      heights = heights.filter { available.contains($0.key) }
      if !available.contains(selection), let first = available.first { selection = first }
    }
    .animation(reduceMotion ? nil : .interactiveSpring(response: theme.motion.pagingResponse,
        dampingFraction: theme.motion.pagingDamping), value: selection)
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier(identifier + ".pager")
    .accessibilityAdjustableAction { direction in
      switch direction {
      case .increment: select(index + 1)
      case .decrement: select(index - 1)
      @unknown default: break
      }
    }
  }

  private var pages: some View {
    ForEach(ids, id: \.self) { id in
      content(id)
        .frame(width: width, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .background(GeometryReader { geometry in
          Color.clear.preference(key: NativePagerHeights<ID>.self,
            value: [measurementScope: [id: geometry.size.height]])
        })
        .id(id)
        .accessibilityHidden(id != selection)
    }
  }

  @ViewBuilder private var viewport: some View {
    if #available(iOS 17, macOS 14, *) {
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(alignment: .top, spacing: 0) { pages }.scrollTargetLayout()
      }
      .scrollTargetBehavior(.paging)
      .scrollPosition(id: position, anchor: .leading)
      .scrollDisabled(!enabled)
    } else {
      HStack(alignment: .top, spacing: 0) { pages }
        .offset(x: -CGFloat(index) * width + translation)
        .frame(width: width, alignment: .leading)
        .clipped()
        .contentShape(Rectangle())
        .simultaneousGesture(
          DragGesture(minimumDistance: 16)
            .updating($translation) { value, current, _ in
              guard enabled, ids.count > 1, abs(value.translation.width) > abs(value.translation.height) else { return }
              let edge = (index == 0 && value.translation.width > 0) || (index == ids.count - 1 && value.translation.width < 0)
              current = value.translation.width * (edge ? 0.2 : 1)
            }
            .onEnded { value in
              guard abs(value.translation.width) > abs(value.translation.height),
                abs(value.predictedEndTranslation.width) > max(24, width * 0.2) else { return }
              select(index + (value.predictedEndTranslation.width < 0 ? 1 : -1))
            })
    }
  }

  private func select(_ index: Int) {
    guard enabled, ids.indices.contains(index) else { return }
    selection = ids[index]
  }
}

// Each pager has its own key within the preference, so nested pagers cannot
// overwrite each other's dimensions and empty sibling values cannot erase them.
private struct NativePagerWidths: PreferenceKey {
  static let defaultValue: [Namespace.ID: CGFloat] = [:]
  static func reduce(value: inout [Namespace.ID: CGFloat], nextValue: () -> [Namespace.ID: CGFloat]) {
    value.merge(nextValue(), uniquingKeysWith: { _, next in next })
  }
}
private struct NativePagerHeights<ID: Hashable>: PreferenceKey {
  static var defaultValue: [Namespace.ID: [ID: CGFloat]] { [:] }
  static func reduce(value: inout [Namespace.ID: [ID: CGFloat]], nextValue: () -> [Namespace.ID: [ID: CGFloat]]) {
    value.merge(nextValue(), uniquingKeysWith: { current, next in
      current.merging(next, uniquingKeysWith: { _, next in next })
    })
  }
}
