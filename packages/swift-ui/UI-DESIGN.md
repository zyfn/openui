# Native rendering and verification contract

The overall design is maintained in the [SDK README](README.md#整体设计).
The [component reference](SDK-REFERENCE.zh-CN.md) owns component-by-component
presentation rules. This document owns compatibility, source ownership and
verification boundaries; it does not maintain another table of default tokens.

This describes main, including local candidates after RC19. A design statement
is not evidence that an older release or a consuming app has adopted it.

## 1. Preserve the contract; document native choices

Component names, positional argument order, values, bindings and actions come
from the actual registered library and the pinned shared language core. Default
registrations are the 84 pinned definitions plus Map, MapPoint and SVG. Hosts
can derive a different generation/rendering library; export its actual prompt,
spec, schema and identity rather than copying the default SDK contract by hand.

Native styling is a platform adaptation, not a claim of CSS pixel equivalence or
an Apple requirement. No business name, destination or case ID selects a renderer.
Public authoring and theme APIs are documented in [COMPONENTS.md](COMPONENTS.md).
Pinned source mappings in [OFFICIAL-VISUAL-MAPPING.md](OFFICIAL-VISUAL-MAPPING.md)
provide provenance; dated captures and older design decisions must be read with
their recorded revision, not treated as current visual acceptance.

## 2. Resolve roles from shared sources

- `OpenUITheme` overrides shared fonts, colors, spacing and surfaces.
- `OpenUIPresentation` supplies native geometry, reading widths, touch targets
  and motion. These are host settings, not additional Lang fields.
- `Theme/TextStyles.swift` maps explicit slots to complete text recipes. Primary
  copy, supporting copy, numeric emphasis and action text remain independent.
- Native Text, rich text and measurement use resolved typography. Complete host
  overrides retain their family, weight, size, tracking, digits and explicit leading.
- Nearest-view locale, available space, text scale and appearance are environment
  inputs. Process-global screen dimensions do not determine layout.
- System chart colors distinguish data series/categories; status colors describe
  actual states. An action's presence does not randomly recolor an object.

The current defaults are shown in the [shared role table](SDK-REFERENCE.zh-CN.md#31-文字和颜色)
and exported [token data](../../sites/swift-sdk/public/generated/tokens.json).
When a component looks too weak or too large, check its role mapping before
changing the global token. Host theme scopes and supported override keys retain
their existing reset/migration behavior.

## 3. Keep layout and interaction predictable

Parents propose space; children measure within it. Explicit direction, alignment,
wrap and responsive settings retain their meaning. Card's surface and flexible
allocation are separate responsibilities: clear has no inset or grouping border;
sunk has a recessed fill without a grouping stroke; card has an object boundary.
A generic Stack wrapper does not forward an inner Card's flex preference.

Card and collection layouts use existing reading widths. Body text grows inside
allocated columns. Tables preserve column relationships and horizontal scrolling;
name/value text wraps inside its assigned cells, while numeric roles retain their
alignment and readable values. Slot and item constraints remain authoritative:
Card is not Stack's unrestricted children array, and the generic Carousel takes
page arrays rather than arbitrary nested Card/Stack wrappers.

Top-edge object images and original-image previews have different jobs. A leading
card image can extend to the card's top/side edges, with top corners matching the
surface; text and actions retain their content inset. Body media does not inherit
that edge treatment. Original viewing uses fit, independently of the card's crop.
ImageGallery currently retains equal-width tiles on its last row. The proposed
last-row fill change is paused, not an implemented or required design rule.

Use one mounted subtree when geometry changes. Footers reflow the same price and
action; grids measure row extents; horizontal browsing reserves the tallest mounted
page so changing selection does not move following prose. Actual content growth
can still change that height. Do not add hidden copies of controls for measurement.

Preview paging and zoom share an interaction boundary: paging operates at normal
scale; zoomed dragging moves the current image; changing images resets zoom.
Thumbnail selection and accessibility actions remain available. The close action,
page position and image description stay distinct. Built-in chrome localizes;
source captions and business content are not automatically translated.

Form owns a submission scope and its default panel. A surrounding host panel may
opt out through the existing presentation setting; the renderer does not infer
business intent or add another form. Form/ActionEvent values must reach the host;
clicking an action does not prove a business operation succeeded.

## 4. Streaming preserves known content, not an invented finished page

Source completeness, layout readiness, collection shape, URL readiness and resource
completion are separate inputs. A leading reading prefix can render while complex
content waits. Unknown row contributors can affect width; media waits until that
allocation is safe. A known native Card role can allocate reading space while its
copy continues to stream.

Stable statements/keys and presentation scope preserve native control, browsing
and resource state. Appends and growing snapshots are distinct from a new program.
An identical terminal snapshot and an empty chunk are idempotent; an explicit
reset is a new presentation. Obsolete resource/query callbacks cannot overwrite
the current program. Resource permission, authorization and transport stay in
the injected host resource context.

A loading indicator does not narrate the Agent's business activity. Missing data
is not zero or a successful execution result. Charts use confirmed values and
respect the data dependencies of their chart type; ratio graphics must not use
an invented total. Existing content can remain during a refresh or failure.
Markdown parser/compatibility work remains a separate responsibility; this design
does not authorize stripping spaces, stars or rewriting source text.

These rules do not guarantee zero movement for unknown text height, arbitrary
source order, a host replacing State, or a genuinely changed layout.

## 5. Verify each responsibility with the right evidence

| Layer | What it establishes | What it does not establish |
| --- | --- | --- |
| Parser/schema regressions | Grammar, parameter order, references, state and evaluation | Readability, truthful facts or visual quality |
| Native layout/resource tests | Geometry, state retention, loading/retry and role propagation | Every device's appearance or physical gesture feel |
| Simulator UI tests | Real controls, paging/zoom cooperation, locale and visible caption placement in the recorded setup | All widths, inputs, streaming frames or physical devices |
| Visual review | Hierarchy, density, image/word relationship and alignment in a named capture | Runtime/Agent execution outside the captured scope |
| End-to-end product checks | Current values and correct object context actually reach the next action/Agent | Unrelated SDK or service scenarios |

The SDK distribution owns SDK tests. The separate consuming CaseLab app owns
its programs, native UI automation, screenshots and recordings; they are not a
runtime dependency. Record SDK and host revision, exact source, width, language,
appearance, playback mode and artifact identity. A screenshot, registration count
or compile is not a substitute for acceptance at the other layers.

Current normal-text Simulator evidence covers representative cards, selected
Case02 areas, English/Chinese previews and specific paging/zoom actions. Pinch
behavior, extreme image proportions, long descriptions and physical-device
interaction need their own targeted evidence before broader claims are made.
A manual source-file rendering is not a TPS stream replay.

## 6. Keep one design baseline

A design change should update the README's relevant principle, the owning
component row, code-derived guide data and a representative verification result.
Do not append successive conflicting token tables or promote a suggested layout
to an implemented default. Release notes and exported client contracts identify
what was shipped; main documents may also describe explicitly marked candidates.

The public integration APIs and development commands remain in [README.md](README.md).
