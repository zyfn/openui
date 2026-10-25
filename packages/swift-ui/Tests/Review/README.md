# Native SDK review

This is a finite composition matrix for the installed SwiftUI component library.
The host and tests use the SDK renderer and bundled lang-core directly. They do
not maintain another component schema, parser or business-specific renderer.

## Responsibilities

```text
Review/
├── Catalog/       Composition families, variants and registration coverage
│   └── Programs/  Ordinary OpenUI Lang programs
├── Host/          Preview, scene navigation, source editor and diagnostics
├── Acceptance/    Core audit and Swift/XCUITest interaction assertions
│   └── UITests/   Shared support and focused behavioral suites
└── Fixtures/      Offline resources, boundary programs and approved baselines
```

`Catalog` obtains component names and parameters from the installed LibrarySpec.
Tokenized references establish registration coverage. An external replay does not
increase the fixed matrix's coverage. Data helpers are covered within their real
parent components rather than displayed as standalone views.

`Host` owns one `OpenUIState` per workspace. Changing a program replaces that state;
changing width, theme, appearance or the surrounding bubble preserves the current
program and its local interactions. The header keeps scene names, previous/next
navigation and variant selection accessible. Component search, source, conditions
and diagnostics have separate entries. The bubble toggle only simulates a generic
chat host surface and is not a component or protocol field.

The header's language button switches the host and all 25 built-in samples between
Simplified Chinese and English. Foundation bundle localization supplies host copy;
English samples are ordinary DSL resources, not a renderer translation layer.
Changing language restarts the selected catalog sample. Manual drafts and imported
replays retain their exact source. The language choice is remembered by the host;
`--language zh-Hans|en` overrides it for reproducible runs.

The width indicator shows **Full**, **320**, or **240** beside preview conditions.
The default fills the available content area with the host's 20pt reading margins.
The finite native matrix deliberately alternates width constraints. Its narrow
stress captures should not be presented as the default full-width appearance.

The source editor retains an in-memory draft separately from executed source.
Run submits the draft unchanged to the SDK. A single enclosing `openui-lang` fence
may be removed, but mixed prose is not searched for a program or rewritten. Core
errors are displayed without falling back to a sample. Cancel preserves the draft
and live state. Restoring a sample does not delete a manual draft.

## Bounded matrix

| Family | Variants | Representative boundaries |
| --- | ---: | --- |
| Adaptive layout | 3 | Direction, wrapping, intrinsic size and nested media |
| Reading and media | 4 | Summaries, gallery, loading, failure, retry and return |
| Cards and actions | 3 | Hierarchy, density, explicit sizes and click ownership |
| Input and feedback | 4 | Choices, validation, dates, draft/save and presentations |
| Mixed tables | 2 | Component cells, measured rows and horizontal scrolling |
| Charts and metrics | 3 | Trends, shares, distributions and interactive details |
| Content and navigation | 3 | Hierarchy, grouping, tabs, steps and rich text |
| Spatial selection | 3 | Default/custom map cards, routes, tabs and shared selection |

Eight families contain 25 variants. Empty/single/multiple media, content changes
and selections are exercised by updating the same programs. Container constraints
are test inputs, not new SDK breakpoints. Boundary programs remain outside this
count so negative coverage does not inflate the visual catalog.

## Run

Use a dedicated simulator; do not share it with another acceptance run.

```sh
swift packages/swift-ui/scripts/visual-tests.swift \
  --simulator <dedicated-simulator-UDID> --suite full --phone-only \
  --package-tests --output work/component-review/phone
```

| Option | Meaning |
| --- | --- |
| `--suite quick` | Core integrity, representative families and workspace controls |
| `--suite full` | All selected native methods and all 25 composition variants |
| `--only-testing Class/method` | A focused regression; mutually exclusive with suite |
| `--phone-only` | Phone acceptance without wide-screen or broad large-text sweeps |
| `--package-tests` | Run the package-level checks too |
| `--prepare-only` | Generate a project for Xcode or XcodeBuildMCP |
| `--stream-program file.openui` | Replay an unchanged saved streaming source |
| `--review-program file.openui` | Inspect an external program and its table geometry |
| `--review-examples file.json` | Add external exported guidance examples |

The host accepts `--case`, `--language zh-Hans|en`, `--theme default|accent`, `--bubble`,
`--width available|standard|narrow`, `--appearance light|dark` and `--large-text`.
These flags affect the review host only. External-source methods explicitly skip
when their optional input is absent; report these skips with the acceptance scope.

## Assertions and evidence

- **Core integrity:** every variant has a valid complete root; the final chunked
  result agrees with the shared streaming/batch behavior expected by the fixture.
  Both language versions are checked. Shared-core tokens must match exactly except
  for translated Chinese string literals, preserving names, arguments and state IDs.
- **Composition:** all installed registrations occur in valid containing programs;
  layout measures actual content and keeps the final table row reachable.
- **Interaction:** one action writes state once, async results respect source
  replacement, and view identities survive appends and appearance changes.
- **Streaming:** incomplete form writes and business actions remain read-only;
  local tab, disclosure, carousel and table browsing stay available. Tabs follows
  growing content and Accordion follows new items until a manual value change.
  Table derives its safe visible page without discarding current-page state.
  Replacement resets local state. Original source is replayed without asking a
  model to regenerate it.
- **Resources:** initial loading, appends, retry, relative/encoded URLs and gallery
  previews use the same SDK resource context.
- **Contextual UI:** chart details appear inside the chart presentation without
  inserting document rows; map markers, internal cards and fullscreen return stay
  synchronized. Read-only table policy is explicitly installed by the review host.
- **Manual execution:** attachments retain source, ActionPlan evaluation, before/
  after state and write counts. A later passing replay does not prove the cause of
  an earlier failure when its original runtime evidence is missing.

Screenshots document native output; they do not independently prove aesthetics.
Structural checks and approved pixel comparisons are distinct. The runner exports
an xcresult bundle, bounded logs, attachments and its last result path into the
chosen output directory. Avoid changing source during a recorded acceptance run.
