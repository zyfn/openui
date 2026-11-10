// OpenUISwiftUI — Query loading view.
//
// Optional host-owned Query UI. Standard data/media components separately own
// their source-aware loading surfaces; custom loading closures remain untouched.

import SwiftUI
import OpenUILang

/// Renders a Query's lifecycle: spinner while loading, content on success.
///
/// - Parameters:
///   - state: The query's `QueryState` (from `OpenUIState.queryStates`).
///   - loading: Custom loader view.
///   - content: Rendered with the query data on success.
public struct QueryView<Loading: View, Content: View>: View {
    private let state: QueryState?
    private let loading: () -> Loading
    private let content: (Value) -> Content
    private let usesDefaultLoading: Bool

    public init(
        state: QueryState?,
        @ViewBuilder loading: @escaping () -> Loading,
        @ViewBuilder content: @escaping (Value) -> Content
    ) {
        self.state = state
        self.loading = loading
        self.content = content
        self.usesDefaultLoading = false
    }

    /// Convenience init with the default `ProgressView` spinner.
    public init(
        state: QueryState?,
        @ViewBuilder content: @escaping (Value) -> Content
    ) where Loading == ProgressView<EmptyView, EmptyView> {
        self.state = state
        self.loading = { ProgressView() }
        self.content = content
        self.usesDefaultLoading = true
    }

    public var body: some View {
        Group {
            switch state?.status {
            case .loading:
                if usesDefaultLoading {
                    NativeDelayedPresentation(active: true) { visible in
                        NativeLoadingIndicator().opacity(visible ? 1 : 0)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text("Loading data", bundle: NativeControlResources.bundle))
                } else { loading() }
            case .success:
                if let data = state?.data {
                    content(data)
                }
            case .error:
                // Keep the last successful value (or defaults) visible on error.
                if let data = state?.data { content(data) }
            case .idle, .none:
                // Idle: render with defaults (data may be nil).
                if let data = state?.data {
                    content(data)
                }
            }
        }
    }
}
