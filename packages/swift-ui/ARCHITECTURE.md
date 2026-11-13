# Swift SDK architecture

This repository is a fork of upstream OpenUI. The native extension implements
Swift support; it does not redefine the upstream language or turn the SDK into a
chat application framework. This document is the single architecture entry point.
Use [SDK-REFERENCE.zh-CN.md](SDK-REFERENCE.zh-CN.md) for the component contract and
[PERFORMANCE-NOTES.md](PERFORMANCE-NOTES.md) for historical implementation evidence.
Those documents do not replace the acceptance gates below.

## 1. Keep upstream boundaries; keep two public Swift products

| Boundary | Existing implementation | Owns | Does not own |
| --- | --- | --- | --- |
| Language core and native bridge | `lang-core` -> `swift-lang` / `OpenUILang` | Language parsing, evaluation, Store/action mechanisms, schema and prompt generation, semantic budgets | SwiftUI, fonts, image layout, chat scrolling |
| Native framework adapter | `OpenUIState`, `Renderer`, `RenderNode`, `Context` | One document's lifecycle, native bindings, action coordination, evaluated-node rendering and identity | Another parser, business workflows, cross-session persistence |
| Standard library | `GenUILib`, `Components`, `Theme` | Registered contracts, views, native layouts, design recipes and accessibility | Inferring business intent from names or invented data |
| Host boundary | Existing source, resource, state and action APIs | Input delivery, container constraints, authorization injection and external effects | Patching every standard component to make it usable |

`OpenUILang` and `OpenUISwiftUI` remain the public products. Directories are source
ownership, not new SwiftPM targets, actors or service layers. `OpenUIState` remains
one public facade; do not add a parallel authoritative `DocumentRuntime` Store.
The shared core, React packages, positional language parameters, minimum OS
versions and package dependencies are unchanged by the organization step.

An upstream language change, a new dependency or a public contract change needs
its own compatibility decision and evidence. Do not hide it in a native UI repair.

## 2. Current source ownership

```text
Sources/OpenUISwiftUI/
  OpenUIState.swift          Document/native-state coordination
  Renderer.swift            Public root view
  RenderNode.swift          Node/value traversal, child identity, fallback boundary
  QueryView.swift           Native query-state presentation
  Resources.swift           Injected loading and document-scoped resource sharing
  NativeStringBridge.swift  Native String conveniences, not language semantics
  Context/                  Guarded component operations and environment scopes
  GenUILib/                 Definition + builder assembly, standard registration
  Components/
    Text/                   Markdown, code, math, citations, text presentation buffer
    ...                     Existing named component-family and layout files
  Theme/                    Tokens, semantic roles, recipes, native presentation policy
  Internal/                 Typed private bridges, resource helpers, live-node index
  Resources/                Bundled scripts, licenses, icons and localized strings
```

This step groups the text feature and consolidates `RenderValue`,
`OpenUIRenderChild` and `ElementErrorBoundary` into `RenderNode.swift`. Their public
symbols and imports are unchanged. No compatibility copies or forwarding files
are left at old source paths. Existing public entry files remain in place.

Do not mechanically move every file for cosmetic symmetry. Group another feature
when changing that feature, including all source-link consumers in that change.
A short helper with one owner should normally stay in that owner's file. Keep a
separate file for a meaningful reusable algorithm, platform boundary or independently
testable subsystem. File count alone is not an architecture quality metric; do not
replace many small files with one all-purpose renderer file either.

`Components/Text` is a standard-library feature, not a new SDK-wide engine.
`Internal/NativeRichText.swift` and `Internal/NativeCodeSyntax.swift` remain typed
private adapters for presentation scripts. Components never receive JS handles.

## 3. Data flow and extension seams

```text
Host source -> OpenUIState -> OpenUILang parser/evaluator/Store
                         -> evaluated values + readiness
                         -> Renderer / RenderNode -> registered component builder
User edits/actions       -> ComponentContext -> OpenUIState -> language state/action
Resource consumers       -> injected loader + document resource scope
```

The same `OpenUIComponentLibrary` assembles the definition and native builder.
Exported schema/prompt describes the actual library. Third-party views use this
registration seam; they must not require edits to a central component-name switch.
Expose only necessary typed metadata (layout dependencies, label ownership and
placeholder behavior); do not expose internal JS objects or allow extensions to
fabricate readiness. Broadening that metadata API remains separate work.

Use the existing Theme, Presentation, ToolProvider and resource loader seams.
Do not add a provider protocol for every private helper. Most applications should
use the standard library and root renderer without selecting internal engines.

## 4. State, identity and action ownership

| State | Authority | Lifetime |
| --- | --- | --- |
| Confirmed fields and shared bound selections | Existing language Store | Document |
| Unsubmitted table edits or unrepresentable input text | Small scoped editing records where needed | Document/component identity, not a transient layout branch |
| Focus, hover, press and temporary animation | Native view | Mounted control |
| Download/decoded resource results | Existing resource scope and injected policy | Authorized scope and explicit budget |
| Layout and rich-text projections | Their local subsystem | Discardable cache keyed by actual dependencies |
| Conversation history, navigation and scroll position | Host | Host-defined |

Append, replacement, completion and interruption are different transitions.
Preserve existing API meanings while separating document identity from update
versions internally. A source version is not a universal view ID or cache key.
An earlier asynchronous result must not write into a replacement document.

Submitting a form prepares current edits, validates, then dispatches using the
current authorized state. Button appearance must not decide correctness. Action
sequences retain their declared order; the SDK does not promise distributed
transactions, remote persistence or server-side idempotency.

## 5. Streaming and performance contracts

- Input semantics are lossless and ordered. A replaceable visual snapshot may be
  coalesced; field writes, actions, completion and interruption are not discarded.
- Reading a render projection or fitting its size must not call `setSource`,
  reset state, execute language actions or schedule new semantic work.
- Stable identity does not mean immutable content. Actual dependencies, readiness,
  theme, locale, width and accessibility changes still invalidate the right work.
- Necessary ancestor layout is allowed. Unchanged content should not repeatedly
  parse, prepare rich text, decode images or remount controls because a sibling grew.
- No global height cache. Any local cache must be discardable and give the same
  answer as an uncached calculation for all relevant proposals and dependencies.
- Resolve measured hot paths before changing execution domains. Do not introduce
  actors, snapshots or lazy containers solely to satisfy an architecture diagram.

### Text-specific implementation

One component-local buffer coalesces append-only presentation updates. It does not
own the OpenUI parser, field Store or host scroll position. It compares an incoming
snapshot to the last accepted snapshot (not just the older visible prefix), applies
corrections/completion immediately, and rejects stale scheduled callbacks by generation.
The internal scheduler is injectable for deterministic tests; it is not a new public
service. The current default interval is a tuning parameter, not a frame-rate claim.

There is no second 160ms trailing-edge wait before rich-text preparation. Continuous
input must not postpone preparation indefinitely. Pending work still obeys cancellation.
Native string observation preserves UTF-16 distinctions through `OpenUIString`.

MarkdownUI remains the current backend in this step. The raw/prepared fallback,
whole-prefix processing and actual native fitting costs still require investigation.
Do not claim an incremental Markdown engine or zero jitter from this buffer. A backend
replacement is evaluated separately against existing syntax, citations, math, resources,
accessibility, theme, tools and deployment requirements; choose one default backend,
not multiple per-message engines or different renderers for streaming and completion.

## 6. Implementation sequence and closure gates

| Work | Deliverable | Closure evidence |
| --- | --- | --- |
| A. Boundaries and source organization | Current facade/registration retained; text grouped; owned helpers consolidated | No upstream/shared-core or manifest drift; architecture checks; native CI |
| B. Correctness and document lifetime | Submission, invalid drafts, reset/append equivalence, expired callbacks | Real Store/action tests and mounted-control lifecycle regressions |
| C. Measured streaming performance | Parse/evaluate/publish/layout/fit costs isolated; remove demonstrated duplicate work | Same inputs and constraints in minimal and real self-sizing hosts; Release traces |
| D. Bounded resources and text backend | Downloads, downsampling, cancellation, scope and text-contract validation | Failure injection, resource accounting, syntax differential and native rendering tests |
| E. Native UI and public contract | Existing components, recipes, defaults, extension metadata and docs agree | Component board + mixed pages, narrow/wide, large type, dark/contrast, keyboard/VoiceOver |

These workstreams do not add new components. Existing functional defects remain
in scope; this organization commit does not close the complete execution plan.
Visual review starts with the baseline and proceeds alongside the fixes, not after
all engineering work. A branch is not releasable merely because source organization
or isolated tests pass.

## 7. Test and release policy

`ArchitectureBoundaryTests` guards existing native/module boundaries and the text
backend seam. `StreamingTextPresentationTests` uses a manual scheduler for state
transitions and a separate predicate-based test for the real scheduler. Never use
an arbitrary short sleep as evidence that another task finished. Cancellation tests
also deliver obsolete callbacks deliberately to exercise generation checks.

Required native gates remain: complete root-package tests, authoring validation,
ASan language tests, standalone macOS build and iOS Simulator build. Performance and
visual acceptance require their own evidence; a passing compile cannot establish
smooth streaming, no layout jumps or design quality. Do not weaken these gates to
merge. Keep the PR draft until the reviewed head has the required results.
