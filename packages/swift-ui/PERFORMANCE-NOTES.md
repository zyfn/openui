# Streaming hot-path stabilization

Baseline: `0a016c8a514acea8641808c6bf1d88aa83288633`.
Scope: execution plan v1.3, PERF-05 / PERF-06 / QA-03 sub-items. No new registered component, token change, global height cache, language rewrite, or deployment-target change.

## First batch

- `OpenUIState.setSource`: replaying the identical UTF-16 buffer while already streaming is a no-op. It does not parse, publish, or advance source identity. `onParseResult` is not a delivery acknowledgment and is not called for this no-op. The first empty streaming snapshot is still accepted. Normal completion, explicit restart after completion/interruption, changed content, and canonically equivalent but code-unit-distinct strings keep their previous paths. This does not make growing full-buffer delivery fully incremental.
- `NativePagerLayout`: reduce the track height once before placing all pages. The reducer filters nonfinite values and clamps the result at zero in one pass. Page height policy, geometry, mounted pages, selection, and gestures are unchanged. This removes the repeated reduction, not all repeated layout work.
- `NativeTableDraft.changes`: build a local first-row-by-ID index once per comparison, preserving the existing first-match behavior for duplicate IDs. The index is not retained across load/reset/commit. This does not solve duplicate row identity or draft lifetime; those remain separate tasks.

## Second batch

- `NativeLiveElementIndex` replaces the existing type-only bucket with a structured `(typeName, statementId)` key. A lookup no longer scans other declarations of the same component type. The key intentionally uses the same Swift String equality as the previous predicate and distinguishes a missing statement ID from an empty one. Candidates retain insertion order, including duplicates. Property comparison, recursive readiness comparison, ambiguity rejection, depth limits, and snapshot-cache clearing remain unchanged in `OpenUIState`.
- This is a candidate index, not an incremental evaluator or an authorization decision. Unnamed inline elements still share their type's unnamed bucket. Rebuilding the index still traverses the evaluated tree, and candidate props still require comparison. For 1,000 distinct named TextContent declarations, each lookup has one candidate rather than a 1,000-element type bucket; this is not a measured frame-rate gain.
- `OpenUIState.update` skips assigning `queryStates`, `mutationStates`, and `errors` only when both their existing and next values are empty. Transitions into and out of nonempty values still publish. Root and presentation-readiness publication, reset lifecycle notifications, and error callbacks retain their existing behavior. The auxiliary publishers are value channels, not input-delivery acknowledgments; consumers must not use an empty emission to count source chunks.
- No deep tree equality/hash scan, extra Store, actor, scheduler, or retained layout cache was added. Reducing publisher sends does not prove a proportional reduction in SwiftUI body executions: framework updates can be coalesced, and the root still changes on real input.

## Third batch

- `NativeFlexRowWidths` extracts the existing nonwrapping row negotiation into a testable helper. Nongrowing children reuse a width measured at the exact same proposal earlier in that call. Different clamped proposals are measured again. Sorting, width sharing, subsequent baseline/dimension reads, stretch probes, wrapped rows, and columns are unchanged. There is no cache between sizing and placement or across updates.
- `NativeMediaRowPlacement` now measures only copy used by the selected layout: full width for vertical rows or exhausted horizontal space, remaining width for a fitting horizontal row, and full width again only if the horizontal proposal is rejected. Fixed image dimensions, the 0.5-point overflow threshold, centering, and horizontal scroll geometry are unchanged. The existing internal helper and axis type move to `NativeLayoutMeasurement.swift`; no component/API is added.
- Twelve `LayoutMeasurementReductionTests` methods cover probe counts, proposal changes after clamping, changed content/width between calls, and differential geometry against the previous algorithm (1,152 Flex cases and 3,200 media cases). These are measurement/geometry checks, not an FPS benchmark. Running the exact Foundation-only helper and these tests in an isolated Linux package checks their logic, but does not typecheck the surrounding SwiftUI SDK.
- Diagnostic artifacts record the actual checkout SHA, PR head/base, run/attempt and toolchain. Check artifact metadata and this provenance before assigning a log to a commit; a retrieved legacy job-log response contained a different checkout and must not be used as evidence for this PR. `pipefail`, all native checks, and the existing failure policy remain enabled.

## Fitting contract

A host must keep a stable state/hosting instance for a logical document. Submit source in the input/update path, not from sizing callbacks. Sizing reads the current presentation; it must not call `push`, `setSource`, `reset`, or dispatch actions. Notify parent size changes only when relevant geometry actually changes. Do not assume framework body/layout calls are all remounts, and do not suppress valid changes using a global height cache.

`HostSizingIsolationTests` runs 100 fitting queries in a controlled macOS host, both statically and with repeated streaming buffers, and checks parse/publication/action counters and native mounts. It deliberately replaces Markdown text with native Text to isolate the sizing boundary. It is not the client's chat container, an iOS frame-rate benchmark, or proof that all streaming hitches are resolved.

## Validation

Run on macOS from the repository root:

```sh
swift test --filter 'StreamingReplayTests|HotPathReductionTests|HostSizingIsolationTests|LiveElementIndexTests|AuxiliaryPublicationTests|LayoutMeasurementReductionTests'
swift test
```

The first batch adds 14 XCTest methods; the second adds 18. The second batch covers candidate identity/order, duplicate and unnamed declarations, Unicode key semantics, reference release, live resolution, error clearing, query/mutation removal, field writes, reset, and readiness-only completion. These test counts describe added coverage, not passed test results.

The existing Build Swift pull-request workflow also runs language AddressSanitizer checks and builds the iOS Simulator target. A successful SDK-test step does not mean the whole workflow passed; sanitizer and platform-build failures remain release blockers. Device tracing, the actual client adapter, broad observation invalidation, cross-pass Flex measurement reuse, parser-prefix work, rich-text work, and resource budgets remain open. No v1.3 task is closed solely by these batches.

## Verified checkpoint before batch three

At head `4803d11e53323d45f8a173726c7bf5efba56435c`, Build Swift run `43395100837` succeeded: 493 SDK XCTest methods, 100 language XCTest methods under AddressSanitizer, the authoring validator, the standalone macOS example and the iOS Simulator compile. Build JS and Changeset check also succeeded. Artifact `14023312235` (`swift-diagnostics-43395100837-1`) was downloaded and its SHA-256 verified as `e12628378920e5319f133b7963d8593f91b5a895943a03ce96a860c360d96ab3`; its four logs support the test counts and platform builds. This checkpoint is not proof that a later head passes. The historical earlier sanitizer-step failure was not reproduced at this checkpoint; its cause is not claimed fixed or identified from the mismatched log.


## Independent acceptance repairs D1–D5

Input: integration candidate `2308c31367c55cefc4f36bff3bebd11e08537823` and the user's independent macOS acceptance report. That report passed 571 SDK tests, 3 Release fitting tests, 102 language ASan tests and platform builds, but failed complete acceptance on D1–D5. Those are baseline results, not results for the repaired tree.

- **D1 — chart/category coordinates:** the category-label container explicitly uses the physical left-to-right coordinates already used by Canvas and inspection. Label text retains the caller's writing direction. Source labels and series are not reversed. The surrounding chart legend and UI retain RTL behavior.
- **D2 — RTL range slider:** one geometry mapping converts value to physical x and x back to value. Fill, dots, thumb placement, nearest-thumb selection and drag use that mapping. A narrowly scoped LTR layout prevents SwiftUI from mirroring physical offsets again. RTL value progression is reversed; stored range values are not. Accessibility keeps the external direction.
- **D3 — image subscribers:** each waiter owns a continuation, independent cancellation and a final caller cancellation check. Shared work survives one cancellation but stops when the last waiter leaves. Reset drains waiters, and generation/group identity prevents obsolete completion from refilling or removing a replacement request. Cache hits also reject cancelled callers. Existing image budgets and resource scopes remain unchanged.
- **D4 — formula rasterization:** remove the hidden host's requestAnimationFrame dependency. A native navigation completion starts trusted code in WKContentWorld.defaultClient; font readiness and forced DOM layout precede a snapshot that does not wait for a visible-screen refresh. No longer timeout or retries are introduced. Host replacement/dismantling is identity-checked, and WebContent termination completes the job. Internal bounded phase history and content-free `dev.openui.swift / Math` failure logs identify waiting-for-host, loading, fonts, layout or snapshot failures. This addresses code-level starvation/lifecycle hazards; the original intermittent symptom still requires the same native reentry replay to confirm closure.
- **D5 — error feedback:** a slider displays one draft message only until the common field wrapper presents an error. Both invalid range inputs still produce one message. Standalone/unsubmitted fields keep immediate feedback; validation and action blocking are unchanged.

Regression tests were added to the existing ChartInspectionTests, StreamingFormCorrectnessTests, ResourceStoreTests and NativeRenderingTests; no new public component, target, dependency or production source file is introduced. Hosted RTL tests compare actual NSHostingView bitmaps and also reject blank output. Native formula tests rasterize three distinct formulas across clipped/near-transparent host reentries, check nontransparent pixels and exercise old-host teardown after replacement. They export `d1-*`, `d2-*` and `d4-*` PNGs under OPENUI_SNAPSHOT_DIR.

Run on macOS at the exact repair commit (keep failures and exit codes):

```sh
export OPENUI_SNAPSHOT_DIR="$(mktemp -d /tmp/openui-d1-d5.XXXXXX)"
swift test --filter 'ChartInspectionTests|StreamingFormCorrectnessTests|ResourceStoreTests|NativeRenderingTests|StreamingTextPresentationTests'
swift test
swift test -c release --filter HostSizingIsolationTests
```

Local Linux validation of the repair checks syntax and the unchanged extracted cache/subscriber and slider-geometry code. Its image/platform types are test stand-ins; it is not ImageIO, SwiftUI, WebKit, Apple SDK or client UI acceptance. Client follow-up should rerun RTL value/tooltip/drag association, one-visible-error feedback, one-cancelled/one-live image requests, and repeated formula page reentry on iOS as well as macOS. No FPS or zero-bug claim is made from these tests.
