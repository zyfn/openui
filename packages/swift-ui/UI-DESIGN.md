# Native visual and layout contract

The native renderer preserves OpenUI component names and language contracts.
Appearance follows SwiftUI platform conventions; it does not reproduce web CSS.
`OpenUITheme` supplies shared typography, colors, spacing, surfaces and motion.
Hosts may replace theme values without redefining components or rewriting programs.

## Composition

- The parent proposes available space; containers measure their children. Text wraps
  and contributes its natural height. Missing optional content consumes no space.
- `Stack` and `Card` respect explicit direction, alignment, justification and wrap.
  A row with `wrap=true` flows when its children no longer fit. The renderer does
  not infer a layout from destination names, image counts or business categories.
- Responsive grids derive columns from their available width and declared settings.
  An explicit nonresponsive layout keeps its declaration and remains scrollable.
- Tables preserve column alignment and measured row heights. Wider content scrolls
  horizontally rather than turning the table into an unrelated card template.
- Carousel and map pages use the same native pager and current container width.
  A page selection survives appends; removing a selected page clamps the selection.
- Stable statement and component identities preserve local UI during streaming,
  state updates and theme changes. Replacing a program resets that program only.

## Visual hierarchy

Use the shared semantic text roles instead of local font constants. Titles, body
text and supporting details retain a clear hierarchy across standard components.
Semantic surface and text colors support light and dark appearances. Chart colors
come from a shared data palette rather than a single host accent. A compact
chart omits left-axis ticks when its measured gutter cannot fit complete labels;
the plot, inspection values and accessible dataset remain available.

Buttons use semantic variants, declared sizes and native hit targets. Cards provide
compact action density by default; an explicitly declared size still takes priority.
Do not enlarge a local action merely to fill a row or add a separate action below a
whole-card button. A clickable card label must not contain another button.

Images retain explicit sizing contracts; ordinary content images measure from
their source proportions instead of inheriting a fixed web aspect ratio. Very tall
sources fit completely inside a portrait preview region derived from the current
container width. Thumbnail and gallery slots retain their visual roles. These are
native visual defaults, not additional language rules. Resource state,
retry and previews share `OpenUIResourceContext`. A missing or failed image must
not erase adjacent text or actions. Do not assume every horizontal composition has
one image and one fixed-width text column.

The optional Map renders supplied coordinates and valid point facts. Its default
bottom cards are compact, internal to the map and synchronized with icon markers.
Custom content uses ordinary registered components. No ratings, metadata or routes
are inferred from labels. SVG and WebView are installed through `OpenUIWeb`.

## Platform boundaries

The modern Layout implementation is available on iOS 16/macOS 13 and later. iOS 15
and macOS 12 retain stack/scroll fallbacks; identical layout algorithms or pixels
across OS versions are not promised. MarkdownUI manages its internal semantic font
roles; the SDK shares supported colors, spacing and media styling through its
public API rather than reflection.

The 82 standard registrations have upstream names and positional signatures.
Tabs follows the upstream content-growth selection rule until a user changes the
active value. Native presentation may differ: controls use Apple interaction
conventions, and web-specific styling is not a native API contract.
Optional native extensions are documented separately
in [the component catalog](NATIVE-COMPONENTS.md).

## Verification

The [native review](Tests/Review/README.md) uses eight composition families and
25 variants, plus independent boundary fixtures. Tests operate real SwiftUI views
in a dedicated iOS Simulator and record interaction, geometry and screenshots.
Capturing an image or covering a registration does not establish visual approval.
Approved pixel baselines, when present, are separate from structural assertions.
