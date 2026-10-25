# Native standard component catalog

`OpenUIStandardComponents.library()` registers the 82 pinned upstream default
component names. Names, positional argument order, defaults and component slots
follow `react-ui/src/genui-lib`. SwiftUI owns the platform appearance and measured
layout; library and schema rules use shared `lang-core`.

The packaged `upstream-catalog.json` is generated from that source. Use its actual
LibrarySpec signatures rather than translating HTML props or inventing Row/Grid
components. Some entries (Col, TabItem, Series, options and chart points) are data
nodes consumed by parents and do not independently render.

## Composition

Use Stack for row/column layout and wrapping, Card for meaningful groups, and the
official CardBlock families for repeated objects. Table retains columns, dynamic
row heights and horizontal overflow. Its default cell registry is unrestricted;
`OpenUITableCellPolicy.readOnly` is an explicit host choice, with matching native
PromptOptions available. No form/input capability is removed from the global SDK.

Standard Tabs has only `items`; TabItem defines `value`, `trigger` and `content`.
Tabs follows the upstream renderer's selection rule: until a user changes the
active value, select the last item whose `JSON.stringify(content).length` grows.
A complete initial render follows the same rule. A manual value change stops
automatic following, including across appends and ordinary Store updates. Removing
a manually selected value does not silently select a different item. Horizontal
browsing keeps the selected label visible when font/container/label metrics change.
No undeclared value/key parameters are read. Source replacement resets presentation
state, including the interaction latch and prior content sizes.

Accordion opens the newest item when the item count grows until the user changes
the open value. Table derives its visible safe page without overwriting the
upstream current-page state when rows temporarily disappear. Tabs, Accordion,
Carousel and Table pagination are local browsing, available during streaming;
form writes and business actions keep their separate completion checks.

## Optional extensions

- `OpenUIMapComponents`: Map for supplied locations, icon markers, default place
  cards and optional ordinary component pages. No geocoding or fabricated routes.
- `OpenUIPopoverComponents`: native contextual explanations.
- `OpenUIWebComponents` from the optional OpenUIWeb product: SVG and WebView.

These extensions are not part of the upstream default 82. Installation extends
existing slots through the core; hosts can independently choose their generation
subset. Component selection and business actions belong to the caller.

## Native presentation scope

Registration and positional-schema parity do not imply web pixel equivalence.
The native renderer implements these standard presentation contracts:

| Component | Native presentation |
| --- | --- |
| CodeBlock | Upstream refractor/Prism grammars, selectable native text, lossless copy and copy feedback; unknown languages remain plain text |
| EntityList | Inline Markdown in both cells, text/number variants, default header/footer and compact rows |
| Tag / TagBlock | Distinct small, medium and large metrics; shared icon and semantic color presentation |
| IconText | Semantic icon badges including inverted, with upstream filled/soft normalization |
| TextContent | Block Markdown, GFM tables, shared fenced-code rendering, numbered source citations and offline KaTeX equations |
| Charts | Upstream tick/tooltip number formats, stable polar sorting/colors and interactive legend visibility; SingleStackedBar keeps input order and its static legend |
| Slider | Typed numeric values, discrete choices, multiple range handles and coalesced state commits |
| Modal | Presentation-field binding, including dismissal during streaming; callbacks from a replaced source cannot update the new response |
| Table / PieChart | Empty-data loading skeletons driven by query state; refetch retains existing data |

CodeBlock bundles `refractor@5.0.0`, the grammar library used by the pinned
`react-syntax-highlighter@16.1.1`. Tokens are produced in a private JavaScriptCore
worker and drawn with SwiftUI Text; model code is never evaluated. Its resource
is separate from lang-core, carries dependency licenses and requires no runtime
downloads. Rebuild it with `npm ci --ignore-scripts` then `npm run build` in
`scripts/code-highlighting`. SwiftPM consumers use the checked-in resource.

Rich text similarly bundles the pinned Remark/KaTeX dependencies. Native blocks
remain SwiftUI; a private nonpersistent WebKit view rasterizes equations using
embedded fonts. General SVG/WebView components still require the optional
OpenUIWeb product. Citation metadata is supplied by `CardSourceProvider`, using
the upstream source fields rather than extending the language syntax.

`OpenUIState.isQueryLoading` and `ComponentContext.isQueryLoading` expose the
shared loading condition to native renderers. Empty charts omit a fixed canvas;
loaded values remain visible during refetch.

Layout fallbacks on iOS 15/macOS 12 are documented in [the visual contract](UI-DESIGN.md).
Hosts needing different appearance can override a renderer through the existing
library extension API without changing component names or language syntax.

## Validation

Run the package tests and `scripts/visual-tests.swift` on an owned phone simulator.
The review project separates composition catalog, host shell and native assertions.
Screenshots without approved baselines are visual evidence, not pixel-regression
acceptance. See `Tests/Review/README.md` for reproducible commands.
