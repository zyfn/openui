# Native component authoring

`OpenUILang` and `OpenUISwiftUI` keep their names and dependency direction. The optional standard collection and authoring helpers live in `OpenUISwiftUI`; the parser does not import SwiftUI or product types. Existing dictionary-based `ComponentRegistry` registrations still work.

## Define and render

```swift
let note = OpenUIComponent(
    name: "Note",
    description: "A short note",
    params: [OpenUIParameter.string("text")]
) { context in
    Text(context.string("text") ?? "")
}
let components = try OpenUIStandardComponents.library()
    .extending(adding: [note])
let state = OpenUIState(schema: components.library.toSchema())
// Keep `state` in one stable owner for this message, such as @StateObject.
OpenUIRenderer(state: state, registry: components.registry)
```

Generate the model's prompt with `components.prompt(...)` and export the actual definition with `components.toSpec()`. The server and the other platform use that contract. Component parameter order stays explicit and follows the upstream positional language.

`OpenUIComponentLibrary.prompt` forwards options to the shared-core prompt generator.
Use `components.prompt()` for the standard prompt, or pass the official
`PromptOptions` when the caller explicitly needs additional rules or examples.

## Control the model's component scope

Keep the installed registry complete and derive the per-message library through
lang-core. For example, a host can offer a read-only subset:

```swift
let installed = try OpenUIStandardComponents.library() // 84 registered names
var generation = try installed.library.extend(
    LibraryExtension(removeComponents: ["EditableTable"])
)
// Upstream group notes describe the full catalog. Omit them in this minimal
// example; a production host can supply curated notes/examples for its subset.
generation.componentGroups = generation.componentGroups?.map { group in
    var group = group
    group.notes = nil
    return group
}
let spec = generation.toSpec()
let prompt = generateSystemPrompt(library: spec)
let state = OpenUIState(schema: generation.toSchema())
OpenUIRenderer(state: state, registry: installed.registry)
```

The same schema controls generation and parsing; the full registry can still
serve historical messages that use installed component names under their saved contracts.
Stored programs containing removed native-only names must be migrated using the
mapping in NATIVE-COMPONENTS.md, or rendered by an explicitly retained legacy host
adapter. Keeping an old Schema alone cannot restore a removed renderer. Core updates component
unions and groups on removal and rejects dangling mandatory dependencies. Plain
text notes/examples need explicit host curation; do not claim schema removal
automatically rewrites prose. No second schema-filtering framework is needed.

## Named slots

`OpenUIParameter.slot` defines an ordinary component-valued JSON Schema prop. Choose a single value or an array and optionally constrain accepted component names. In the renderer, use `context.slot("header")` or `context.render(value)`; both use the shared recursive renderer. Extend constrained slots with `extending(adding: ..., slots: ["Note": ["Notice.header"]])`. Generic Stack children already accept registered components and do not need ref-union edits.

Standard Card uses exactly the official seven parameters (`children`, `variant`, `direction`, `gap`, `align`, `justify`, `wrap`). Compose titles, images and action groups through children. Named slots belong in explicitly authored host components, such as a Notice that declares its own header; the slot helpers do not add fields to Card.

## Theme overrides

`OpenUITheme` is a partial override set using the pinned React Theme names.
`OpenUIThemeValues` is the complete value read by `context.theme` and
`EnvironmentValues.openUITheme`. A missing override uses the SDK default.

```swift
var light = OpenUITheme()
light.interactiveAccentDefault = .blue
light.interactiveAccentPressed = .blue
light.interactiveAccentDisabled = .blue.opacity(0.4)
light.textAccentPrimary = .white
light.spaceM = 16
light.textBodyDefault = OpenUIFont(size: 17)

OpenUIRenderer(state: state, registry: installed.registry)
    .openUITheme(mode: .system, lightTheme: light)
```

Pass `darkTheme:` for independent dark overrides. When omitted, the light
**overrides** are applied to the dark defaults. `.system` follows the nearest
SwiftUI color scheme; `.light` and `.dark` affect this subtree only. An inner
`.openUITheme(...)` starts from SDK defaults plus its own overrides, matching
the pinned React ThemeProvider. Ordinary children inherit the active resolved
theme. The closure overload also creates a fresh override set.

Typography roles are independent complete `OpenUIFont` values. For example,
`textBodyDefaultHeavy` does not change when `textBodyDefault` is overridden.
`ImageTextLarge` and CardHeader use `textBodyLgHeavy`; ImageText and default-size `BoldText` use `textBodyDefaultHeavy` when emphasized;
headings use `textHeadingXs`, `textHeadingSm` and `textHeadingMd`.
Each role controls its own font family, size, weight and tracking.
`lineHeight` requests a baseline height as a font-size multiplier, clamped to
native glyph metrics. `lineSpacing` retains the native additional-spacing
setting in em; an explicit `lineHeight` takes precedence. When both are omitted,
components resolve role-specific leading: body 1.50, detail 1.45, caption 1.40,
title/field-label 1.35, section 1.30 and display/control/metric 1.25.
These native font values replace CSS font strings, not the Lang contract.

Known descriptions, subtext, list subtitles, gallery details and hints share the
14pt secondary reading role; field errors share its font and leading with error
ink. Source/position metadata uses the 12pt caption role. Native text, Markdown
and geometry consume the same resolved font, including explicit host leading.
TextContent small/small-heavy keep primary ink. No content-priority inference or
new text role parameter is added to the language.

Spacing uses the official `space*` tokens. `gap="none"` is always zero.
Buttons groups occupy their available width. Column groups stretch each text
button; row groups wrap item by item using spaceM on both axes. Stack column
stretch reaches a direct text button's visible surface; center/start/end retain
its content width. Nested Stack does not implicitly grow along a parent's row;
Card retains its explicit row-sharing behavior. These policies preserve the same
mounted controls when placement changes. Horizontal ImageText centers image and
copy vertically; horizontal IconText retains top alignment.
Card families consume their own tokens directly: object and fact-card padding
uses `spaceM`; generic Card uses `spaceML` (clear has zero vertical inset).
Fact-card groups add no outer margin. The corresponding
radii are `radius3xl`, `radius2xl` or `radiusXl`. There are no competing
`cardPadding`, `contentSpacing` or `cornerRadius` overrides.

Native-only metrics and motion are supplied separately:

```swift
var presentation = OpenUIPresentation()
presentation.coverAspectRatio = 3.0 / 2.0
renderer.openUIPresentation(presentation)
```

This includes touch targets, thumbnails, carousel widths, chart axes and
native motion. Changing a theme does not reset this environment value.
The renderer stays transparent; the app owns its page and message background.

Callout/TextCallout use a neutral leading rule instead of a warning/status icon;
their variant, visibility binding and dismissal contracts are unchanged. Horizontal
cards and Carousel use swipe/drag paging without a visible navigation-button row.
Accessibility page navigation and focused macOS arrow keys remain available;
Table retains its own pagination controls.

Ordinary cards and secondary actions use `borderDefault`; clear/sunk content
containers have no grouping stroke, and sunk has no outer shadow. Editable fields use the stronger
`borderInteractive`. Set
`presentation.cardBorderColor` when a product needs a different card boundary
without changing form controls, Steps or other users of the shared theme tokens.

`ImageText` without an explicit `imageSize` uses an 80pt preferred thumbnail and
can reduce toward 64pt inside a narrow local row. `inlineThumbnailSize` remains
the host's preferred dimension; `minimumTextColumnWidth` supplies the reading
budget. Explicit imageSize and direction remain authoritative. This policy does
not change photo cropping or the separate gallery-thumbnail size.

`IconText` uses a consistent glyph column. `neutral`, `filled`, and `soft` share
the same unplated presentation; state variants keep colored glyphs, while
`inverted` retains its contrasting plate. Tag stays informational: its vertical
insets are 2/4/4pt for sm/md/lg and complete wrapped copy remains visible.

Background-photo Visual/Context cards keep neutral placeholders and readable
copy until their image loads; they no longer reserve a black loading panel.
Loaded photos use a dark scrim and overlay ink only behind overlapping copy;
copy moved below the image uses the original host surface and text colors. On-photo
tags retain their capsule with translucent charcoal, soft white text/icons and no
border. Tags off the photograph use their ordinary host theme and semantic colors.
This changes native presentation only; bgImageSrc, tag, title and action slots
retain their existing contracts.

### Shared appearance configuration and button shape

Use an explicit common override set when typography and geometry should be shared:

```swift
var common = OpenUITheme()
common.textBodyDefault = OpenUIFont(size: 17, lineHeight: 1.5)
var light = OpenUITheme()
light.background = .white
var dark = OpenUITheme()
dark.background = .black
renderer.openUITheme(commonTheme: common, lightTheme: light, darkTheme: dark)
```

Resolution is defaults, common, then the selected appearance. Calls without
`commonTheme` and nested scopes retain the existing reset behavior.

Text buttons are capsules, sized from their actual bounds. Very tall wrapped
labels bound the corner radius to keep all text inside the painted surface.
IconButton's declared circle/square shape remains authoritative.
`OpenUIPresentation.buttonCornerRadius` is nil by default; set it to 10 (or
another finite radius) to opt into rounded rectangular text buttons independently
of inputs and cards. The minimum hit target remains separate from the visible shape.
See [UI-DESIGN.md](UI-DESIGN.md) for the complete default design.

### Migrating from 0.1.1-rc.1

This RC changes the theme API. In particular, `foreground` now means a surface
color, as in React; use `textNeutralPrimary` for the old text-color setting.
`secondary` becomes `textNeutralSecondary`, `canvas` becomes `background`,
`accent` becomes `interactiveAccentDefault`, and `dataColors` becomes
`defaultChartPalette`. Configure pressed/disabled colors separately.
Replace `typography.body` / `bodyHeavy` / `detail` / `title` with
`textBodyDefault` / `textBodyDefaultHeavy` / `textBodySm` / `textHeadingSm`.
Move cover, size and motion options to `OpenUIPresentation`.
Custom component builders now read `OpenUIThemeValues` and
`context.presentation`. Published older tags retain their old API.

## Layout and theme

The collection contains the pinned upstream default library's 84 registrations, including chart data items and parent-consumed records; see [NATIVE-COMPONENTS.md](NATIVE-COMPONENTS.md). On iOS 16/macOS 13, row/column layout uses child measurement, real first-text baselines and distinct space-around/space-evenly distribution. Wrapped rows measure each line independently. The package minimum is iOS 16/macOS 13, so the older stack/grid approximation is not shipped. Use Stack for list/wrapping layouts and Carousel for container-width horizontal pages; these respond to their actual parent proposal, not a device-specific layout template.

Use `.openUITheme(theme)` for appearance and `.openUIPresentation(options)` for native media and layout metrics. Text uses Dynamic Type semantic fonts. There are no screen-global measurements. Override any standard component with `extending(overriding: ...)` when a product needs its own loader or view.

## State, resources and actions

`OpenUIRenderer` injects its existing OpenUIState. Registered components receive a context with binding, action execution, named child rendering, semantic theme, and message-scoped resource values. `.openUIResources(...)` supplies product data; this is a host convention, not a new OpenUI language feature or a network service. `.openUIForm(name)` forwards a form scope. Built-in Form also preserves its exact `OpenUIString` name; `context.exactFormName` and context field/action helpers retain these code units.

The component layer uses the upgraded runtime's immutable reference containers and `OpenUIString` values. `context.string(...)` is a display convenience; `context.codeUnitString(...)` and `context.value(...)` retain exact semantic data. Resource lookup also accepts `OpenUIString` and compares exact keys. Stable render keys keep canonical Unicode variants and isolated UTF-16 units distinct. Native host transports must explicitly convert or reject values their own JSON representation cannot carry; see the [language package](../swift-lang/README.md).

`OpenUIActionSurface` presents a single native button with a presentation-only label. Use it for an entire clickable resource card; do not nest other buttons in that label. `context.perform(plan)` uses the existing asynchronous runtime and host callback. The message/action overload uses the runtime's legacy/default-action dispatcher as well. `OpenUIActions.openURL(...)` and `continueConversation(...)` construct existing action plans; the host still owns navigation and business execution. Choose returned events or the state callback for host routing, never both; the standard surface uses the callback and does not route returned events a second time. Interactions require complete control dependencies in the current source revision; ready controls can act while unrelated content streams. Replacing source invalidates callbacks and context bindings from the previous source revision. Construct component contexts on the main actor; registered component hosts already do this.

`context.isStreaming` is the streaming flag for the current render. Component hosts pass a new snapshot when a stream completes, so indirect child views refresh even when their props are unchanged. `context.canInteract` checks the live completion state and source revision; use it to gate controls and context action helpers to dispatch guarded operations.

Custom input/form views can use context.fieldBinding, fieldValue and initializeField in the nearest `.openUIForm(...)` scope. Field initialization must happen on mount rather than while evaluating a view body.

Stateful dynamic children should declare a stable `key`, `id`, or `resourceId` prop. An explicit instance key separates duplicate presentations of one resource. Named statements retain statementId identity; anonymous positional content is suitable for static/append-only presentation, not stateful reordering. Store a message's source, library version, and runtime snapshot for history restoration.

The next RC removes the earlier Map, SVG, WebView and Popover installers.
Consumers upgrading from rc.4 should use `OpenUIStandardComponents.library()`
and export its matching spec. Older programs that depend on the removed names
are not part of this standard catalogue; the SDK does not silently rewrite them.

## Local selection and navigation

Standard `Tabs(items)` owns native local selection and keeps its horizontal label
row, even for one item. `TabItem.value` is the stable identity. The renderer does
not read undeclared Tabs value/key props. A host needing another controlled
container declares its own component and renderer rather than relying on hidden
standard-component behavior.

Use `OpenUIParameter.selection` and `context.binding` for declared bindings.
Standard inputs can share the same variable without changing their contracts.
Presentations share the existing runtime and resource scope.

Declare host actions and invoke them with standard Button/ActionPlan. Business
facts, transactions and application navigation stay with the caller. The SDK
provides native rendering and resource hooks.
`replacingDefinition` can reuse a native builder when the extended definition
preserves the semantics that builder implements; new behavior needs its own
renderer. Export the actual resulting LibrarySpec.

Native PromptOptions and Table cell policies are explicit caller choices; base
prompt generation and unrestricted Table rendering retain the upstream default
capabilities.
