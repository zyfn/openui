# Native SDK review

Six authored personal-agent tasks share one native review host:

| Task | Main composition and interaction |
| --- | --- |
| One day in Paris | Place rows, booking links, independent map and budget |
| Two days in Paris | Flight and hotel carousels, overview/day tabs, map and budget |
| Choose a camera | Product cards, comparison and product links |
| Spending review | Stacked bars, category shares and period selection |
| An evening together | Venue cards, selection and shared cost |
| Learn through objects | Image gallery, linked visual cards and comparison chart |

The request appears first. Saved Lang bytes then arrive on an independent,
configurable token clock and go through `OpenUIState.push` and `complete`.
The public `OpenUIRenderer` renders the complete root. The host adds scrolling,
navigation, an editor and diagnostics; it never extracts or rearranges SDK nodes.
These are authored examples, not live model responses or live inventory.

## Files

- `Catalog/`: the six task definitions.
- `Host/`: one workspace, request bubble, TPS replay, manual Lang input and diagnostics.
- `Fixtures/`: licensed offline images and the two-day task data/source generator.
- `Acceptance/`: six-task batch/streaming audit and native tests of these tasks.
- `Tools/`: offline token-boundary preparation for the same six sources.

The older component catalog, 25 variants, standalone query/streaming pages,
external projection fixtures and quick/full/stress test matrices have been removed.
Parser, protocol and renderer unit tests remain in their package test targets.
The six tasks do not claim exhaustive component coverage.

## Prepare and run

Run from the repository root, using a dedicated iPhone simulator:

```sh
swift packages/swift-ui/scripts/visual-tests.swift --prepare-only --output ../openui-tests
python3 -m venv ../openui-tests/.review-tokens-venv
../openui-tests/.review-tokens-venv/bin/pip install -r packages/swift-ui/scripts/review-token-requirements.txt
swift build --package-path packages/swift-ui
../openui-tests/.review-tokens-venv/bin/python packages/swift-ui/scripts/review-tokens.py --output ../openui-tests
swift packages/swift-ui/scripts/visual-tests.swift --simulator <UDID> --suite scenarios --output ../openui-tests
```

Open the generated `ComponentVisualReview.xcodeproj` to explore the same host.
All six scenes default to SDK streaming. The tools menu controls 20/40/80/160/320
TPS and retains manual language, bubble and appearance options. Automated acceptance
uses phone available width, normal text and the default SDK theme. There is no
wide-screen, large-text, language or theme matrix.

`--only-testing Class/method` selects a focused check within this same chain.
`--package-tests` additionally runs the separate SDK unit tests. Regenerate token
resources whenever a scene's source changes; stale/missing resources fail visibly.
`o200k_base` is a reproducible test tokenizer, not a claim about a model's private
tokenization. Tests assert UTF-8 identity, delivery timing, complete rendering,
geometry and real SDK actions. Native screenshots are evidence, not automatic
visual approval. Test data and transport remain outside SDK Sources.
