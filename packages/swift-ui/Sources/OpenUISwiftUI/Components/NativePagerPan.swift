import SwiftUI
#if os(iOS)
import UIKit
#endif

struct NativePagerPan<Fallback: Gesture>: ViewModifier {
  let enabled: Bool
  let fallback: Fallback
  let changed: (CGFloat) -> Void
  let ended: (CGFloat?) -> Void
  @ViewBuilder func body(content: Content) -> some View {
    #if os(iOS)
    if #available(iOS 18, *) {
      content.gesture(NativeHorizontalPanGesture(enabled: enabled, changed: changed, ended: ended))
    } else { content.simultaneousGesture(fallback, including: enabled ? .all : .subviews) }
    #else
    content.simultaneousGesture(fallback, including: enabled ? .all : .subviews)
    #endif
  }
}

#if os(iOS)
@available(iOS 18, *)
struct NativeHorizontalPanGesture: UIGestureRecognizerRepresentable {
  let enabled: Bool
  let changed: (CGFloat) -> Void
  let ended: (CGFloat?) -> Void
  var located: ((CGPoint, CGPoint) -> Void)? = nil
  func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator { Coordinator() }
  func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
    let pan = UIPanGestureRecognizer()
    pan.maximumNumberOfTouches = 1
    pan.delegate = context.coordinator
    pan.isEnabled = enabled
    return pan
  }
  func updateUIGestureRecognizer(_ recognizer: UIPanGestureRecognizer, context: Context) { recognizer.isEnabled = enabled }
  func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
    switch recognizer.state {
    case .began, .changed:
      let location = context.converter.localLocation
      let delta = context.converter.localTranslation ?? .zero
      located?(location, CGPoint(x: location.x - delta.x, y: location.y - delta.y))
      changed(recognizer.translation(in: recognizer.view).x)
    case .ended:
      let location = context.converter.localLocation
      let delta = context.converter.localTranslation ?? .zero
      located?(location, CGPoint(x: location.x - delta.x, y: location.y - delta.y))
      ended(recognizer.translation(in: recognizer.view).x + recognizer.velocity(in: recognizer.view).x * 0.15)
    case .cancelled, .failed: ended(nil)
    default: break
    }
  }
  final class Coordinator: NSObject, UIGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
      guard let pan = recognizer as? UIPanGestureRecognizer else { return false }
      let v = pan.velocity(in: pan.view)
      return abs(v.x) > abs(v.y)
    }
  }
}
#endif

struct NativeSliderPan<Fallback: Gesture>: ViewModifier {
  let enabled: Bool
  let fallback: Fallback
  let changed: (CGPoint, CGPoint) -> Void
  let ended: () -> Void
  @ViewBuilder func body(content: Content) -> some View {
    #if os(iOS)
    if #available(iOS 18, *) {
      content.gesture(NativeHorizontalPanGesture(enabled: enabled, changed: { _ in }, ended: { _ in ended() }, located: changed))
        .simultaneousGesture(SpatialTapGesture().onEnded { value in if enabled { changed(value.location, value.location); ended() } })
    } else { content.gesture(fallback) }
    #else
    content.gesture(fallback)
    #endif
  }
}
