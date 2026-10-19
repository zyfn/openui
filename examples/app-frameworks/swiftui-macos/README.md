# OpenUI macOS Demo

Independent SwiftPM executable using the two local packages. Requires macOS 13+ and Xcode with Swift 6 support.

```bash
cd examples/app-frameworks/swiftui-macos
./build-app.sh
open '.build/OpenUI Demo.app'
```

You can also open `Package.swift` in Xcode and run the `OpenUIDemo` scheme on My Mac.

Edit source to render immediately, use 流式播放 to watch incremental parsing, and 模拟 Query to fetch local mock data with a 1.2-second delay. The demo Button uses an app-owned callback to show click feedback; it does not demonstrate the language action runtime. Component views and mock tools live entirely in this example. No network, credentials, or core package changes are required.

## Architecture and extension points

- `Package.swift` depends on `OpenUILang` and `OpenUISwiftUI` by local path; no web runtime or JavaScript bridge is used.
- `Sources/OpenUIDemo/OpenUIDemo.swift` defines the component schema, native view registry, editor, stream playback, and mock `ToolProvider`. Replace the registry to use app-specific views or the provider to call an app-owned backend.
- `build-app.sh` builds and ad-hoc signs a local `.app` bundle under `.build`; it does not launch or distribute the app.
- The language core contains no UI imports; the renderer contains no demo components, travel content, credentials, or backend clients.

## Verification

```sh
cd examples/app-frameworks/swiftui-macos
./verify.sh
```

This runs the renderer's state/registry regression tests and builds the standalone app without credentials or external services. Language conformance can be checked separately from the repository root with `swift test --package-path packages/openui-lang`. The example is outside the JavaScript example registry and npm release workflow.
