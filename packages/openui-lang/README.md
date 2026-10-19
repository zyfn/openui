# OpenUILang

Pure-Swift implementation of the OpenUI Lang 1.0 protocol — lexer, parser, streaming parser, evaluator, and runtime. No SwiftUI, Combine, AppKit, or UIKit dependency; uses Foundation and builds on Linux and macOS.

## Usage

```swift
import OpenUILang

// 1. Define your component library.
var schema = LibrarySchema()
schema.components["Stack"] = [
    ParamDef(name: "children", required: true,
             schema: .object([JSONField(key: "type", value: .string("array"))]))
]
schema.components["Text"] = [
    ParamDef(name: "text", required: true,
             schema: .object([JSONField(key: "type", value: .string("string"))]))
]
schema.rootComponent = "Stack"

// Or compile from a JSON Schema document:
let json = try parseJSONPreservingOrder(schemaText)
schema = compileLibrarySchema(json)

// 2. Parse.
let parser = createParser(schema: schema)
let result = parser.parse("""
    root = Stack([Text("Hello"), Text($name)])
    $name = "world"
    """)

// 3. Evaluate.
let store = createStore()
store.initialize(defaults: result.stateDeclarations, persisted: [:])
let ctx = EvaluationContext(
    getState: { store.get($0) ?? .null },
    resolveRef: { _ in .null },
    functions: [:]
)
let evaluator = Evaluator(context: ctx, store: store, schema: schema)
if let root = evaluator.evaluateRoot(result) {
    print(root.typeName) // "Stack"
}

// 4. Streaming.
let stream = createStreamingParser(schema: schema)
stream.push("root = Stack([Text(\"Hel")
stream.push("lo\")])", complete: true)
let final = stream.getResult(complete: true)
// final.root == batch parse result
```

## API

### Parsing
- `createParser(schema:) -> OUIParserProtocol` — batch parser.
- `createStreamingParser(schema:) -> OUIStreamingParserProtocol` — streaming parser with `push(_:complete:)`, `set(_:complete:)`, `getResult(complete:)`.
- `ParseResult` — `root: ElementNode?`, `rootExpression: ASTNode?`, `meta: ParseMeta`, `stateDeclarations`, `queryStatements`, `mutationStatements`.

### Evaluation
- `Evaluator(context:store:schema:)` — `evaluate(_:) -> Value`, `evaluateRoot(_:) -> EvaluatedElement?`, `evaluateElementNode(_:) -> EvaluatedElement`.
- `EvaluationContext` — `getState`, `resolveRef`, `functions`, `actions`, `reportError`, `extraScope`.
- `Value` — `.string`, `.number`, `.boolean`, `.null`, `.array`, `.object`, `.element(EvaluatedElement)`, `.actionPlan(ActionPlan)`, `.binding(String)`.

### Runtime
- `createStore() -> StateStore` — reactive state with pristine-set semantics.
- `QueryManager` — query/mutation lifecycle with `ToolProvider`.
- `runActionPlan(_:context:)` — execute action steps in order.
- `validate(_:rules:)` — form validation (9 rules).

### Library
- `compileLibrarySchema(_:) -> LibrarySchema` — from JSON Schema.
- `defineComponent(_:_:)` / `LibrarySpec` — Swift DSL for component registration.
- `buildParamsSignature(_:)` — signature strings.
- `jsonToOpenUI(_:)` / `serialize` — JSON ↔ openui-lang.
- `mergeStatements(_:_:)` — patch merge.
- `createMessageParser` — message parsing.

## ECMA-262 semantics

- `toNumber`: never NaN (unparseable → 0).
- `==`/`!=`: JS loose equality (`5 == "5"`, `"" == 0`, `null == 0` is false).
- `/` and `%` by zero → 0 (not Infinity/NaN).
- `+`: string concat if either operand is a string (null → "").
- `@Sort`: locale-aware collation (`localizedCompare`); numeric strings sort numerically.
- `@Round`: half towards +∞ (JS `Math.round`).

## Error codes (14)

`unknown-component`, `unknown-function`, `inline-reserved`, `not-component`, `no-root`, `orphan-reference`, `unresolved-reference`, `ref-cycle`, `missing-required-prop`, `excess-args`, `invalid-prop-type`, `invalid-prop-value`, `tool-not-found`, `runtime-error`, plus `parse-failed` (defined by spec, never emitted — mirrors upstream).

## Upstream differences

1. **`parse-failed`**: defined in spec §8.3 but never emitted by upstream code and has zero fixtures. We mirror upstream (do not emit).
2. **`mergeStatements`**: upstream's `splitStatementSource` has no ternary continuation despite spec §7 claiming it must. We port faithfully (fixtures are executable truth).
3. **Error `hint`**: upstream does not populate it for validation errors; we leave it unpopulated.
4. **Dynamic state defaults**: if a `$var` default is a non-literal expression, `store.get` returns `.null` (upstream stores the AST; no fixture covers this).
5. **`@Sort` locale**: uses Foundation `localizedCompare` (ICU). Results match the fixtures on Linux; macOS collation should be identical (same ICU).

## Monorepo development

This is a SwiftPM package, independent of the pnpm workspace. It contains language and runtime code only; it must not import the SwiftUI renderer or application components.

```sh
swift test --package-path packages/openui-lang
```

The conformance harness reads the shared `spec/fixtures/1.0` directory from this checkout. Set `OPENUI_FIXTURES` to use an external fixture directory. The harness currently covers parse/evaluate, streaming, and validation; it does not run editing or action interaction scenarios end to end. Fixtures are not copied into this package.

A local SwiftPM consumer can depend on this package with `.package(path: "../openui/packages/openui-lang")` and select the `OpenUILang` product. Requires a Swift 6 toolchain; sources currently use Swift 5 language mode. Apple deployment targets are macOS 12+ and iOS 15+.
