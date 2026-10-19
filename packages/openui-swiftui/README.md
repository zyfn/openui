# OpenUISwiftUI

SwiftUI render layer for OpenUI Lang. Depends only on the sibling `OpenUILang` SwiftPM product; applications provide component views and tool backends.

> Verified on macOS with Xcode and Swift 6.3.3: build succeeds and 3 regression tests pass. The separate local macOS playground has been visually exercised; iOS builds have not been verified.

## Usage

```swift
import SwiftUI
import OpenUILang
import OpenUISwiftUI

// 1. Build your schema (see OpenUILang README).
let schema: LibrarySchema = ...

// 2. Create state and register components.
@StateObject var uiState = OpenUIState(schema: schema)

let registry: ComponentRegistry = [
    "Stack": { el, registry in
        AnyView(VStack(alignment: .leading) {
            ForEach(0..<PropValue.children(el).count, id: \.self) { i in
                RenderNode(element: PropValue.children(el)[i], registry: registry)
            }
        })
    },
    "Text": { el, _ in
        AnyView(Text(PropValue.string(el, "text") ?? ""))
    },
    "Button": { el, _ in
        AnyView(Button(PropValue.string(el, "label") ?? "") {
            // Run the action plan via OpenUILang's runActionPlan.
            if let plan = PropValue.actionPlan(el, "action") {
                // ... execute with your ActionContext
            }
        })
    },
]

// 3. Render.
OpenUIRenderer(state: uiState, registry: registry)
    .onAppear {
        uiState.push("root = Stack([Text(\"Hello\")])")
        uiState.complete()
    }
```

## API

### `OpenUIState` (ObservableObject)
Streaming state machine (port of `useOpenUIState`).
- `push(_:)` — feed a chunk; publishes updates.
- `complete()` — mark stream complete.
- `@Published var root: EvaluatedElement?`
- `@Published var errors: [OpenUIError]`
- `@Published var isComplete: Bool`
- `@Published var queryStates: [String: QueryState]`

Queries do NOT run during streaming; they read defaults until the app explicitly fetches via `OpenUIState.runQuery(statementId:tool:args:defaults:)` after `complete()`.

### `OpenUIRenderer` (View)
Top-level renderer. Takes `OpenUIState` and `ComponentRegistry`.

### `RenderNode` (View)
Recursively renders an `EvaluatedElement`. Unknown components render as `EmptyView` (upstream drops them).

### `ComponentRegistry`
A dictionary-literal-compatible `ComponentRegistry` wrapper around component builders. The renderer has **no built-in components or theme** — apps provide their own (like react-ui is separate from react-lang).

### `ElementErrorBoundary` (View)
Keeps the latest registered element; falls back when the input is unavailable or its component is unregistered. It cannot catch arbitrary SwiftUI runtime crashes.

### `QueryView` (View)
Shows a spinner **only** while a Query is loading. Customizable via the `loading` view builder; defaults to `ProgressView`.

```swift
QueryView(state: uiState.queryStates["tickets"]) { data in
    // Render with data on success.
    Text("Loaded")
}
```

### `PropValue`
Helpers: `string(_:_:)`, `children(_:_:)`, `actionPlan(_:_:)`.

## Design notes

- **Unresolved references are omitted** (no placeholders) — handled by OpenUILang.
- **Spinner only for Query loading** — no spinners elsewhere.
- **No built-in theme/components** — the registry is the app's job.

`OpenUIState` is main-actor isolated. `reset()` starts a fresh stream and discards old query completions. The error boundary retains the last registered element when its input becomes unavailable; it does not catch arbitrary SwiftUI runtime crashes.

## Monorepo development

```sh
swift test --package-path packages/openui-swiftui
cd packages/openui-swiftui
xcodebuild -scheme OpenUISwiftUI -destination 'platform=macOS' build
```

This package owns SwiftUI rendering and main-actor UI state. Foundation-only language semantics remain in `OpenUILang`. Component catalogs, themes, app navigation, authentication, and backend clients belong to the consuming app. No sample app or built-in component catalog is included.

A local SwiftPM consumer can use `.package(path: "../openui/packages/openui-swiftui")` and select `OpenUISwiftUI`. The dependency on the sibling language package resolves automatically. Requires a Swift 6 toolchain; sources currently use Swift 5 language mode. Deployment targets are macOS 12+ and iOS 15+.
