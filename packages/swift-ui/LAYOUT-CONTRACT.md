# Layout ownership and streaming presentation

Reference: thesysdev/openui `f08a660535e55b5b2a24a0eb68568edaf9e4fe4b`,
React components, their styles and their GenUI wrappers together. This document
does not change the exported Lang definitions or add a column-count argument.

## Space ownership

| Family | Final layout contract | Native boundary |
| --- | --- | --- |
| Stack | Direction, gap, cross-axis alignment, main-axis distribution, wrapping | Native measurement is not a complete browser CSS engine; no implicit equal-column rule |
| Card | Participates in parent row space allocation; manages its own content/surface | Clear has no content inset; card/sunk retain surface insets. This is an explicit Swift visual adaptation from the pinned React clear padding |
| Buttons | Owns action-group direction and wrapping | Buttons keep natural widths unless an existing stretch relationship supplies width; row touch-target alignment does not stretch painted button heights |
| Image | Uses its media role within the space assigned by its parent | The existing cover role/ratio is a native visual adaptation, not a Lang parameter |
| ImageText / IconText | Owns media and copy composition | Explicit image size stays fixed; common typography remains shared |
| Gallery / Carousel / card blocks | Owns its internal grid/page/collection arrangement | Do not duplicate this arrangement with another Stack |
| Charts / tables | Owns data presentation inside its allotted region | Missing streamed values never become fabricated zeros/rows |

A layout container operates on its direct children. Wrapping a flexing Card in a
plain Stack can change the outer flex item and therefore the result. Stack is
used to express a real grouping relationship, not to make arbitrary components
"safer". Parent-consumed data records such as Col/Series remain in their typed
slots and must not be wrapped as display components.

## Changes in this convergence

- Standard Stack/Card, Buttons, IconText/ImageText and card collections register
  their existing geometry parameters as presentation dependencies. The final
  renderer is released when those fields are committed, not when a default can
  be guessed. Custom renderer replacements opt out automatically.
- An unfinished Stack/Card may show an already readable leading text prefix in
  a neutral reading flow. It stops at a complex or unresolved item and never
  skips it to show later content first. This is provisional presentation, not a
  new meaning of Stack. The final declared layout is applied when known.
  The prefix is selected before dropping unresolved source slots. Later unknown
  items cannot erase earlier text. The same container and keyed child views
  remain mounted when its layout becomes known; there is no replacement reading
  tree. Nested containers inherit the unresolved ancestor geometry state.
- A row's unfinished intrinsic content can still change its width. Fluid media
  in that scope waits compactly instead of displaying a repeatedly resized
  picture; committed sources can continue loading. Fixed-size thumbnails retain
  their known geometry. This is conservative: some media can appear later while
  other properties of the same source item remain unfinished.
- Gallery waits for known collection shape before deciding its initial columns;
  a refresh preserves previously presented items. Source order stays intact.
- Card groups use an already declared item count to allocate page/grid widths
  before all references arrive. They render only available items and do not
  manufacture future cards or scroll targets. Named card statements retain their
  identity while an optional data id streams. Unknown counts retain normal flow.
- First chart presentation is compact waiting feedback. No large gray plot,
  artificial grid or empty ring is drawn. Confirmed values create a real plot;
  normalized charts wait for sufficient data. Waiting uses a delayed visual
  indicator, with resource-state text exposed only to accessibility. The SDK
  does not narrate business activity such as "preparing content". Natural height growth is allowed.
  Refresh retains safe existing data; empty/error/interrupted first results use
  compact terminal feedback. The obsolete chart-skeleton view was removed.

These changes do not make a plain row of content-sized Stacks equal width. If
the intended composition needs shared space, it must use existing components
that express it. Never infer equal columns from the number of images, travel
content or wording. No fixture rewrite or generated-prompt restriction is hidden
in the SDK.

## Audit of native choices

| Choice | Disposition |
| --- | --- |
| Distinct Stack versus flexing Card behavior | Retain; matches the reference division of responsibility |
| Standard image's thumbnailSize ideal proposal | Existing native choice, not official parity; does not authorize freezing a final width or using it as a column-count heuristic |
| Shared 16:9 cover and image failure presentation | Retain prior approved media role; no new per-scene ratio |
| Gallery adaptive grid versus official mosaic | Existing native adaptation; not claimed pixel-equivalent or changed in this batch |
| Font/color/capsule action tokens | Retain current shared roles; no new type scale or scene styles |
| Plot-sized initial skeletons and known-root plot reservations | Superseded by compact initial waiting |
| Applying geometry parameters one at a time during source arrival | Replaced with standard-renderer dependency gating |
| Automatic Stack wrapping or global equal-width row behavior | Rejected; changes final component composition semantics |

## Evidence and acceptance

Use ordinary text size at narrow and wide widths, varying source order, text
length, child count, image readiness, stop/failure and refresh. Large-type visual
acceptance is excluded from this task at the user's request; existing accessibility
support is not removed. Verify the streaming trajectory as well as the final view.

Closed layouts with unresolved data can render progressively. Fully inline source
that declares crucial layout arguments last may defer more of the local region;
the SDK cannot predict future arguments. No universal zero-motion guarantee is
made. A frozen first measurement, fake data and a global host `.disabled` do not
solve these constraints.

Button surfaces use the authored size and natural label height, including wrapped lines. The outer minimum touch target may be taller than the painted surface. Row layout may align those outer targets, but must not feed their height back into the label. Column fill affects width only; mixed-size or multiline peers do not enlarge a short label’s surface.
