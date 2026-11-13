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

## Fitting contract

A host must keep a stable state/hosting instance for a logical document. Submit source in the input/update path, not from sizing callbacks. Sizing reads the current presentation; it must not call `push`, `setSource`, `reset`, or dispatch actions. Notify parent size changes only when relevant geometry actually changes. Do not assume framework body/layout calls are all remounts, and do not suppress valid changes using a global height cache.

`HostSizingIsolationTests` runs 100 fitting queries in a controlled macOS host, both statically and with repeated streaming buffers, and checks parse/publication/action counters and native mounts. It deliberately replaces Markdown text with native Text to isolate the sizing boundary. It is not the client's chat container, an iOS frame-rate benchmark, or proof that all streaming hitches are resolved.

## Validation

Run on macOS from the repository root:

```sh
swift test --filter 'StreamingReplayTests|HotPathReductionTests|HostSizingIsolationTests|LiveElementIndexTests|AuxiliaryPublicationTests'
swift test
```

The first batch adds 14 XCTest methods; the second adds 18. The second batch covers candidate identity/order, duplicate and unnamed declarations, Unicode key semantics, reference release, live resolution, error clearing, query/mutation removal, field writes, reset, and readiness-only completion. These test counts describe added coverage, not passed test results.

The existing Build Swift pull-request workflow also runs language AddressSanitizer checks and builds the iOS Simulator target. A successful SDK-test step does not mean the whole workflow passed; sanitizer and platform-build failures remain release blockers. Device tracing, the actual client adapter, broad observation invalidation, Flex measurement reuse, parser-prefix work, rich-text work, and resource budgets remain open. No v1.3 task is closed solely by these batches.
