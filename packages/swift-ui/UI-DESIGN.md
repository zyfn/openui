# Native visual and layout contract

The native renderer preserves OpenUI component names and language contracts.
Visual defaults map to the pinned react-ui reference (f08a6605); native interaction,
font metrics and resource geometry use the documented platform adaptations.
See [the official-to-native mapping](OFFICIAL-VISUAL-MAPPING.md) for the source,
exceptions and acceptance status. This is not a claim of pixel-identical CSS.
`OpenUITheme` overrides shared typography, colors, spacing and surfaces;
`OpenUIPresentation` supplies native media metrics, hit targets and motion.
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
- Carousel and card collections use the same native pager and current container width.
  A page selection survives appends; removing a selected page clamps the selection.
- Horizontal collections have no visible previous/next button row. Drag paging,
  card peeking and accessibility page actions remain; macOS provides arrow-key
  navigation when the pager itself has keyboard focus. Table pagination is separate.
- Stable statement and component identities preserve local UI during streaming,
  state updates and theme changes. Replacing a program resets that program only.

## Visual hierarchy

Use the shared semantic text roles instead of local font constants. Titles, body
text and supporting details retain a clear hierarchy across standard components.
Object-card families use the theme's normal `foreground` surface whether or not
an action is present. Explicit gray variants retain `sunk`; background-photo cards
own their image and overlay. Basic `Card` containers keep their clear/sunken variants.
Semantic surface and text colors support light and dark appearances. Chart colors
come from a shared data palette rather than a single host accent. A compact
chart omits left-axis ticks when its measured gutter cannot fit complete labels;
the plot, inspection values and accessible dataset remain available.

Body variants follow the upstream semantic relationship: `large` and
`large-heavy` share a reading size and differ by weight; `small` does not imply
secondary ink. Native defaults use the reference's 16pt body, 14pt supporting reading/neutral label,
12pt caption, 18pt card title and 26/20/18pt Markdown H1/H2/H3 headings. MetricIndicator
uses the reference's 16pt emphasized numeric role instead of a separate giant number.
Inline headers use the 18pt heading-xs role; CardHeader uses the 18pt large-body title role.
ImageText titles use 16pt in both orientations and ImageTextLarge uses 18pt.
Title/detail pairs share a 4pt gap and supporting copy uses 14pt. Neutral
tags stay regular-weight so they do not dominate explanations. These are native
platform defaults with Dynamic Type, not a conversion of CSS pixels into points.

Buttons use semantic variants, declared sizes and native hit targets. Cards provide
compact action density by default; an explicitly declared size still takes priority.
Do not enlarge a local action merely to fill a row or add a separate action below a
whole-card button. A clickable card label must not contain another button.

Object-card titles retain their natural line count. The first title line keeps
its normal image inset; short names do not reserve an invisible second line.
Grid peers align within measured rows, while carousel items retain their own
natural content extent. Explicit text-size variants remain intact.

Photo covers and gallery preview tiles use the native `OpenUIPresentation.coverAspectRatio`
(16:9 by default), calculated from their available width before the resource loads.
The standard `Image` component also uses the same 16:9/fill
cover default. Loading, loaded and unavailable states occupy that same frame. Photos fill the
frame proportionally and are clipped at its boundary; their source dimensions
do not resize the frame. Original-image viewing and document illustrations in
Markdown retain their complete source proportions. Photo navigation thumbnails
use the same cover ratio; square icon/thumbnail roles remain square. These are
native visual defaults, not additional language rules. Resource state,
retry and previews share `OpenUIResourceContext`. A missing or failed image must
not erase adjacent text or actions. Loading and failure retain the declared media
slot and show a neutral placeholder; detailed failure controls live in optional
diagnostics. Do not assume every horizontal composition has one image and one
fixed-width text column.

Background-photo cards use the same width-derived photo frame. Copy overlays the
photo when its complete measured content fits; larger copy and accessibility text
move below that unchanged photo. This is a placement change of the same mounted
children, not a new image instance. A responsive block with one recommendation
uses one full-width column instead of leaving a second column empty. Explicit
nonresponsive column declarations keep their existing meaning.

Card collections use one mounted subtree for grid and carousel placement. A
positional layout argument can arrive after a large inline item array; until it
is known, a browsable card viewport avoids temporarily stacking every card into
a tall document. Resolving the mode changes placement without remounting card
content. Grid rows measure complete text, share the tallest cell height and keep
their declared responsive or fixed-column behavior. A width or layout declaration
that has not arrived cannot establish final geometry in advance; the provisional
viewport is local to that collection and does not wait for the whole response.

On platforms using SwiftUI Layout (iOS 16+/macOS 13+), rows negotiate their
available width and measured content. Photo previews retain the common cover
ratio, including in stretched rows; they no longer introduce a separate 4:5
image rule. Preferred thumbnail widths, column minimums and carousel maximums
are measurement hints or bounds, not fixed photo heights. Ordinary Image follows
the container's current direction, including the standard column default. Its
width does not depend on unrelated descendants becoming executable or on stream
completion. A later explicit row argument changes the actual parent layout.

## Platform boundaries

The SDK requires iOS 16/macOS 13 or later and uses one measured Layout
implementation. Pager height reserves the tallest mounted page so selecting or dragging does not
move following prose. Content growth, including offscreen content, can change that
measured track height. Grid rows still share their tallest cell height; both modes retain
the same mounted children without an asynchronous scroll-height cache. MarkdownUI manages its internal semantic font
roles; the SDK shares supported colors, spacing and media styling through its
public API rather than reflection.

The 84 standard registrations have upstream names and positional signatures.
Tabs follows the upstream content-growth selection rule until a user changes the
active value. Native presentation may differ: controls use Apple interaction
conventions, and web-specific styling is not a native API contract.
Optional native extensions are documented separately
in [the component catalog](NATIVE-COMPONENTS.md).

## Verification

A separate native acceptance application presents complete task scenes using
one request-to-stream-to-interaction chain. Its checks operate real SwiftUI views
in an owned iOS Simulator and record interaction, geometry and screenshots; the
SDK-only distribution includes SDK regressions, not those business scenes.
Capturing an image or covering a registration does not establish visual approval.
Approved pixel baselines, when present, are separate from structural assertions.


Grid peer cards accept their measured row extent, with object actions at the
bottom. Carousel cards keep their natural extent. EntityList text values use the
ordinary body role; explicit number values and totals keep their emphasized
roles. Short values remain at the row's trailing edge; a stacked text value
reads from the leading edge. Read-only body rows use spaceS above and below,
while headers/totals retain their group spacing. Table retains its column grid. Supporting callout
copy uses the detail text role. These defaults preserve the supplied structure
and data rather than classifying business content or reordering a response.

SingleStackedBarChart uses the shared native strip thickness, theme spacing and
minimum control target to size its plot. Its static wrapping legend is measured
separately; charts with axes retain their normal plotting area. No Lang height
parameter is added. Code-copy controls use the existing platform hit-target
policy, and syntax-category colors are owned by the theme palette.

Reading roles stay independent. ContextCard uses a 16pt emphasized title and 14pt body; use TextContent or Markdown
for ordinary explanations rather than forcing paragraphs into that family.
CardHeader identifies an object/section; large-heavy is emphasized body text,
not an inferred document heading. The SDK does not remove or reorder headings.

MarkdownUI combines its internal block margins using their maximum. Do not treat
markdownMargin as unconditional outer padding or delete paragraph spacing to
compensate for a host's Stack gap. Mixed block rhythm is checked using complete
fixed-input reading fixtures, alongside the host's actual container spacing.

Composite card footers measure one mounted price/action pair for a row when both
complete natural widths fit, otherwise a column. Missing slots reserve no gap;
width or text changes do not create alternate controls. The reference's always-
column treatment was rejected in native user review. Step badges use a scaled minimum extent
and retain the complete measured numeral rather than clipping it to a fixed box.

IconText's declared sizes select a base glyph and scale its container with the
same nearest-view text environment. The standard aliases remain supported.
Table carries Col's numeric type into trailing alignment and monospaced digits;
long text columns use the theme's reading-width hint instead of a scalar-only
minimum. Values are not reformatted or rewritten.
SDK-generated Context/Composite group actions are siblings of their independent
content controls inside the item surface; no nested Button is introduced.
Callout and TextCallout use a quiet quote treatment: a 3pt neutral leading rule,
16pt body copy and an optional emphasized title, without a status icon. The variant
remains an accessibility value; visible binding and the existing auto-dismiss
behavior are unchanged. Reading disclosure labels align with their body. Large failed media slots show
a brief localized status; small thumbnails retain a distinct status glyph.

### Density and mounted controls

OptionCards choose their column count from the current container and measured title/subtitle height. A narrower cell may add at most about one body line over the full-width copy; otherwise the group reduces its column count. Accessibility text sizes use a single column. These are density preferences, not truncation limits: complete copy remains visible. Copy-only probes never render topContent, load images, or create actions.

Buttons use one layout subtree across row/column reflow, preserving native control identity. The explicit column direction remains authoritative. Form and FormControl now use the reference's open vertical composition, without
a grouped outer card or a second inline/stacked field subtree. This removes the
previous adaptive branch; active editing continuity still requires native interaction proof.

Chart legends balance equally sized reading columns (four comparable entries become two plus two when three plus one would otherwise fit). Their complete labels wrap, while existing minimum control targets remain intact. Bar/Line/Area charts with up to four categories reserve a second label line before omitting ticks; dense axes and numeric axes retain sparse ticks. Explicit chart height remains authoritative, and crowded previews omit ticks rather than overlap axis titles. Inspection placement is unchanged and still requires visual review.

Chart default canvas height scales with the reading size, preserving space for plotted values when labels grow. Explicit authored height retains the existing bounds and takes priority. Short category labels use one line; a second line is reserved only when measured labels require it.


### Reference convergence

Spacing names resolve to the pinned reference values: xs=6, s=8, m=12, l=18,
xl=24 and 2xl=36. Native-only internal intermediate tokens do not add DSL enum
values. Explicit legal component parameters retain their meaning.

The default theme uses opaque neutral surfaces and a neutral assistant brand.
Text actions are capsules based on their actual height, with flat primary and
secondary treatments. Hosts may set OpenUIPresentation.buttonCornerRadius without
changing inputs or cards. Secondary actions use transparent surfaces and the quiet
borderDefault; editable fields use borderInteractive. Tags remain informational,
with 12/14/16pt text for sm/md/lg. Tabs use a selected capsule with a neutral fill
and the shared selection border. Accordion
is a continuous open disclosure list, not one card per section. Generic Card
uses a padded foreground panel with a quiet border by default; clear keeps its
transparent side-inset layout, and sunk keeps its recessed surface. This is a
native presentation choice; the existing variants and layout parameters are
unchanged. Composite object cards remain independent surfaces.

The baseline typeface remains the platform system face with nearest-view Dynamic
Type. CSS line-box height, variable Inter axes, inset shadows and hover are not
claimed as exact native equivalents. Fixed photo-height rules are intentionally
replaced by the user-approved width-derived 16:9 cover contract.


Overview and Snippet facts are outlined cards without a default fill, with
12pt insets; an explicit gray background still applies. Compact fact cards reflow their complete value below the description before
compressing digits. MetricIndicator keeps oversized amounts on one horizontally
scrollable line. Long accessibility tab labels wrap within the viewport. Radar axes use
short numbers and a native full-label key, sharing drawing/inspection geometry.


## Fixed native visual system

The defaults are one coherent system. Component roles are resolved centrally from
OpenUIThemeValues and OpenUIPresentation, with no business-label inference or
per-scene rules. The 84 definitions, language runtime and action semantics remain
unchanged. Native unit checks and consuming-app visual checks have distinct scopes.

### Reading

Reading leading is filled only when both lineHeight and lineSpacing are omitted:
body/code 1.50, detail 1.45, caption 1.40, object title 1.35, section 1.30 and
display/control/metric 1.25. A complete host font keeps its family, size, weight,
tracking, digit setting and explicit leading. Native Text and Markdown receive
the same resolved font. Measured native line height replaces fixed 1.2 estimates
for constrained metric and text-editor content. Links are underlined by default.

### Surfaces and states

| Role | Light | Dark |
| --- | --- | --- |
| Page | #FFFFFF | #0B0B0D |
| Content | #FFFFFF | #17171B |
| Subtle | #F5F5F7 | #1F1F24 |
| Field | #FAFAFC | #17171B |
| Selection | #F1F1F4 | #2A2A30 |
| Overlay | #FFFFFF | #242429 |
| Primary text / accent | #202024 | #F4F4F5 |
| Secondary text | #64646E | #A1A1AA |
| Disabled text | #AAAAB4 | #686874 |
| Surface border | #E0E0E5 | #393940 |
| Editable boundary | #8A8A94 | #767680 |

Primary/secondary ink and boundaries strengthen under the native high-contrast
appearance. Semantic status hues and the independent chart palette remain.
Cards default to borderDefault, with cardBorderColor as an independent override.
Choice markers, selected borders and focus use interactiveAccentDefault. Focus is
2pt and remains outside image clipping. Disabled fields and choices use explicit
state colors, without a second SDK-wide opacity multiplication. Floating surfaces
use the full border token, without an additional 0.45 multiplier.

### Density and shape

Object/fact/choice insets are 12pt. Generic Card variants share 16pt insets; clear
retains zero vertical padding. Fact-card groups add no outer padding: parent Stack
gap controls their relationship to neighbors. Object footer gap is 8pt. Markdown
block margins are collapsed by MarkdownUI; they are not extra component insets.

Images/code use 8pt corners, inputs 10pt, Context 12pt, fact/choice cards 14pt,
Composite/Visual/generic cards 16pt and overlays 24pt. Text actions use capsules,
with a corner limit for very tall wrapped labels to keep text inside the fill;
declared circular IconButton remains circular. Ordinary borders are 1pt; explicit
separators, table rules and disclosure rules use a physical-pixel hairline.
The default button press opacity is 0.92, with the existing 120ms feedback,
0.985 scale and Reduce Motion behavior. Native target size remains independent.

### Explicit shared themes

The commonTheme overload resolves defaults, common overrides, then light/dark
overrides. Existing calls and nested reset behavior retain their contract. See
COMPONENTS.md for migration details. SVG/Map implementations supplied by a host
consume the public theme explicitly; arbitrary SVG attributes are not rewritten.
