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
Tabs uses stable local selection and horizontal browsing, keeping the selected
label visible when font/container/label metrics change. No undeclared value/key
parameters are read by the default renderer. Source replacement resets presentation
state, while appends and ordinary Store changes preserve it.

## Optional extensions

- `OpenUIMapComponents`: Map for supplied locations, icon markers, default place
  cards and optional ordinary component pages. No geocoding or fabricated routes.
- `OpenUIPopoverComponents`: native contextual explanations.
- `OpenUIWebComponents` from the optional OpenUIWeb product: SVG and WebView.

These extensions are not part of the upstream default 82. Installation extends
existing slots through the core; hosts can independently choose their generation
subset. Component selection and business actions belong to the caller.

## Native presentation scope

Registration and positional-schema parity do not imply web presentation parity.
The current native implementation has these known presentation limits:

| Component | Native presentation limit |
| --- | --- |
| CodeBlock | Selectable monospaced text and language label; no syntax-highlighting or copy toolbar |
| EntityList | Plain left/right text; web rich-text and rightVariant styling are not implemented |
| Tag | Small and medium use the same compact native treatment |
| IconText | Web inverted icon-badge styling is not reproduced |

Layout fallbacks on iOS 15/macOS 12 are documented in [the visual contract](UI-DESIGN.md).
Hosts needing different appearance can override a renderer through the existing
library extension API without changing component names or language syntax.

## Validation

Run the package tests and `scripts/visual-tests.swift` on an owned phone simulator.
The review project separates composition catalog, host shell and native assertions.
Screenshots without approved baselines are visual evidence, not pixel-regression
acceptance. See `Tests/Review/README.md` for reproducible commands.
