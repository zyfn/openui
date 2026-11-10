import SwiftUI

/// Source generation and in-flight execution are not business-disabled styles.
enum NativeActionAppearance { case inherited, ready, pending, performing, disabled }
private struct NativeActionAppearanceKey: EnvironmentKey {
    static let defaultValue: NativeActionAppearance = .inherited
}
extension EnvironmentValues {
    var openUIActionAppearance: NativeActionAppearance {
        get { self[NativeActionAppearanceKey.self] }
        set { self[NativeActionAppearanceKey.self] = newValue }
    }
}

/// A delayed indicator changes only pixels, never the action's measured size.
struct NativeActionProgress: ViewModifier {
    let active: Bool
    func body(content: Content) -> some View {
        NativeDelayedPresentation(active: active) { visible in
          content.opacity(visible ? 0 : 1)
            .overlay {
                if visible {
                    NativeLoadingIndicator()
                }
            }
        }
    }
}

struct NativeDelayedPresentation<Content: View>: View {
    let active: Bool
    @ViewBuilder var content: (Bool) -> Content
    @Environment(\.openUIPresentation) private var presentation
    @State private var visible = false
    var body: some View {
        content(visible).task(id: active) {
                visible = false
                guard active else { return }
                do { try await Task.sleep(nanoseconds: presentation.motion.loadingDelayNanoseconds) }
                catch { return }
                guard !Task.isCancelled else { return }
                visible = true
            }
    }
}

struct NativeLoadingIndicator: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        Group {
            if reduceMotion { Image(systemName: "ellipsis") }
            else { ProgressView().controlSize(.small) }
        }.allowsHitTesting(false).accessibilityHidden(true)
    }
}

private struct NativeStreamActiveKey: EnvironmentKey { static let defaultValue = false }
extension EnvironmentValues {
    var openUIStreamActive: Bool {
        get { self[NativeStreamActiveKey.self] }
        set { self[NativeStreamActiveKey.self] = newValue }
    }
}
