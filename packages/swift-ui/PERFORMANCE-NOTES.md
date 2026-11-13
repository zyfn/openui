# Streaming hot-path stabilization — first implementation batch

Baseline: `0a016c8a514acea8641808c6bf1d88aa83288633`.
Scope: execution plan v1.3, PERF-05 / PERF-06 / QA-03 sub-items. No new registered component, token change, global height cache, language rewrite, or deployment-target change.

## Changes

- `OpenUIState.setSource`: replaying the identical UTF-16 buffer while already streaming is a no-op. It does not parse, publish, or advance source identity. `onParseResult` is not a delivery acknowledgment and is not called for this no-op. The first empty streaming snapshot is still accepted. Normal completion, explicit restart after completion/interruption, changed content, and canonically equivalent but code-unit-distinct strings keep their previous paths. This does not make growing full-buffer delivery fully incremental.
- `NativePagerLayout`: reduce the track height once before placing all pages. The reducer filters nonfinite values and clamps the result at zero in one pass. Page height policy, geometry, mounted pages, selection, and gestures are unchanged. This removes the repeated reduction, not all repeated layout work.
- `NativeTableDraft.changes`: build a local first-row-by-ID index once per comparison, preserving the existing first-match behavior for duplicate IDs. The index is not retained across load/reset/commit. This does not solve duplicate row identity or draft lifetime; those remain separate tasks.

## Fitting contract

A host must keep a stable state/hosting instance for a logical document. Submit source in the input/update path, not from sizing callbacks. Sizing reads the current presentation; it must not call `push`, `setSource`, `reset`, or dispatch actions. Notify parent size changes only when relevant geometry actually changes. Do not assume framework body/layout calls are all remounts, and do not suppress valid changes using a global height cache.

`HostSizingIsolationTests` runs 100 fitting queries in a controlled macOS host, both statically and with repeated streaming buffers, and checks parse/publication/action counters and native mounts. It deliberately replaces Markdown text with native Text to isolate the sizing boundary. It is not the client's chat container, an iOS frame-rate benchmark, or proof that all streaming hitches are resolved.

## Validation

Run on macOS from the repository root:

```sh
swift test --filter 'StreamingReplayTests|HotPathReductionTests|HostSizingIsolationTests'
swift test
```

The existing Build Swift pull-request workflow also builds the iOS Simulator target. Device tracing, the actual client adapter, broad observation invalidation, Flex measurement reuse, parser-prefix work, rich-text work, and resource budgets remain open. No v1.3 task is closed solely by this batch.
