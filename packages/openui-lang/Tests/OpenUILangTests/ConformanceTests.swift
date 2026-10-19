import XCTest
@testable import OpenUILang
import Foundation

/// Conformance fixture harness — Level 1 (parse + evaluate).
/// Mirrors packages/lang-core/src/__tests__/conformance.test.ts `evaluateResult` + `summarize`.
final class ConformanceTests: XCTestCase {
    var fixturesDir: String = ""
    var schema: LibrarySchema!

    override func setUp() {
        super.setUp()
        fixturesDir = ProcessInfo.processInfo.environment["OPENUI_FIXTURES"]
            ?? URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent().deletingLastPathComponent()
                .deletingLastPathComponent().deletingLastPathComponent()
                .deletingLastPathComponent().appendingPathComponent("spec/fixtures/1.0").path
        schema = loadFixtureSchema()
    }

    // MARK: - Schema loading

    func loadFixtureSchema() -> LibrarySchema {
        let libPath = (fixturesDir as NSString).appendingPathComponent("library.json")
        let libText = try! String(contentsOfFile: libPath, encoding: .utf8)
        let libJSON = try! parseJSONPreservingOrder(libText)
        guard case .object(let libFields) = libJSON,
              let schemaJSON = libFields.first(where: { $0.key == "schema" })?.value else {
            fatalError("library.json missing schema")
        }
        var compiled = compileLibrarySchema(schemaJSON)
        if case .object(let fields) = libJSON,
           let root = fields.first(where: { $0.key == "root" })?.value,
           case .string(let rootName) = root {
            compiled.rootComponent = rootName
        }
        // Mark bindable props from signatures: (\w+)\??: \$binding<
        if case .object(let fields) = libJSON,
           let comps = fields.first(where: { $0.key == "components" })?.value,
           case .object(let compFields) = comps {
            for compField in compFields {
                let name = compField.key
                guard case .object(let cf) = compField.value,
                      let sig = cf.first(where: { $0.key == "signature" })?.value,
                      case .string(let sigStr) = sig else { continue }
                let pattern = "(\\w+)\\??: \\$binding<"
                guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
                let matches = regex.matches(in: sigStr, range: NSRange(sigStr.startIndex..., in: sigStr))
                let bindableNames = Set(matches.compactMap { m -> String? in
                    guard let r = Range(m.range(at: 1), in: sigStr) else { return nil }
                    return String(sigStr[r])
                })
                if var params = compiled.components[name] {
                    for i in params.indices where bindableNames.contains(params[i].name) {
                        params[i].isBindable = true
                    }
                    compiled.components[name] = params
                }
            }
        }
        // Custom Upper function.
        compiled.callDefs["Upper"] = CallDef(
            kind: .function,
            params: [ParamDef(name: "text", required: true,
                              schema: .object([JSONField(key: "type", value: .string("string"))]))],
            isBuiltin: false
        )
        return compiled
    }

    func makeEvaluator(result: ParseResult) -> Evaluator {
        let store = createStore()
        var defaults: [(String, Materialized)] = []
        for (name, m) in result.stateDeclarations {
            defaults.append((name, m))
        }
        (store as! OUIStateStore).initialize(defaults: defaults, persisted: [:])

        let upper = CustomFunction(
            params: [ParamDef(name: "text", required: true)],
            fn: { args in
                guard case .string(let s) = args["text"] else { return .null }
                return .string(s.uppercased())
            }
        )

        // Box for the evaluator (resolveRef needs it for query defaults).
        final class EvalBox { var evaluator: Evaluator! }
        let box = EvalBox()

        let ctx = EvaluationContext(
            getState: { [store] name in store.get(name) ?? .null },
            resolveRef: { [result] name in
                if let q = result.queryStatements.first(where: { $0.statementId == name }) {
                    if let defaultsAST = q.defaultsAST {
                        return box.evaluator.evaluate(defaultsAST)
                    }
                    return .null
                }
                if result.mutationStatements.contains(where: { $0.statementId == name }) {
                    return .object([
                        ObjectField(key: "status", value: .string("idle")),
                        ObjectField(key: "data", value: .null),
                        ObjectField(key: "error", value: .null),
                    ])
                }
                return .null
            },
            functions: ["Upper": upper],
            actions: schema.callDefs.filter { $0.value.kind == .action }
        )
        let evaluator = Evaluator(context: ctx, store: store, schema: schema)
        box.evaluator = evaluator
        return evaluator
    }

    // MARK: - Summary (mirrors summarize in conformance.test.ts)

    func summarize(_ value: Value, evaluator: Evaluator) -> Any {
        switch value {
        case .null: return NSNull()
        case .string(let s): return s
        case .number(let n): return n
        case .boolean(let b): return b
        case .array(let items): return items.map { summarize($0, evaluator: evaluator) }
        case .object(let fields):
            var out: [String: Any] = [:]
            for f in fields { out[f.key] = summarize(f.value, evaluator: evaluator) }
            return out
        case .element(let el):
            var props: [String: Any] = [:]
            for (k, v) in el.props {
                let s = summarize(v, evaluator: evaluator)
                // Filter null props (like the TS: .filter(([, s]) => s !== null)).
                if !(s is NSNull) { props[k] = s }
            }
            return ["type": el.typeName, "props": props]
        case .actionPlan(let plan):
            return ["actions": plan.steps.map { summarizeAction($0, evaluator: evaluator) }]
        case .binding(let name):
            return ["$binding": name]
        }
    }

    func summarizeAction(_ step: ActionStep, evaluator: Evaluator) -> [String: Any] {
        switch step {
        case .continueConversation(let msgAST, let ctxAST):
            let msg = summarize(evaluator.evaluate(msgAST), evaluator: evaluator)
            if let ctxAST = ctxAST {
                let ctx = summarize(evaluator.evaluate(ctxAST), evaluator: evaluator)
                return ["action": "ToAssistant", "args": [msg, ctx]]
            }
            return ["action": "ToAssistant", "args": [msg]]
        case .openUrl(let urlAST):
            let url = summarize(evaluator.evaluate(urlAST), evaluator: evaluator)
            return ["action": "OpenUrl", "args": [url]]
        case .set(let target, let valueAST):
            let val = summarize(evaluator.evaluate(valueAST), evaluator: evaluator)
            return ["action": "Set", "args": [target, val]]
        case .reset(let targets):
            return ["action": "Reset", "args": targets]
        case .run(let statementId, _):
            return ["action": "Run", "args": [statementId]]
        case .custom(let name, let args):
            // args are [(String, ASTNode)] — evaluate each.
            let evaluated = args.map { summarize(evaluator.evaluate($0.1), evaluator: evaluator) }
            return ["action": name, "args": evaluated]
        }
    }

    // MARK: - Test runner

    func testConformance() {
        let fm = FileManager.default
        guard let cases = try? fm.contentsOfDirectory(atPath: fixturesDir) else {
            XCTFail("Cannot list fixtures dir")
            return
        }
        var passed = 0
        var failed: [String] = []
        var skipped = 0
        for group in cases.sorted() {
            let groupPath = (fixturesDir as NSString).appendingPathComponent(group)
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: groupPath, isDirectory: &isDir), isDir.boolValue else { continue }
            // Skip interactions (Level 2) and editing (needs patch.oui, not in fixtures) for now.
            if group == "interactions" || group == "editing" { continue }
            guard let caseNames = try? fm.contentsOfDirectory(atPath: groupPath) else { continue }
            for caseName in caseNames.sorted() {
                let casePath = (groupPath as NSString).appendingPathComponent(caseName)
                var isCaseDir: ObjCBool = false
                guard fm.fileExists(atPath: casePath, isDirectory: &isCaseDir), isCaseDir.boolValue else { continue }
                let files = (try? fm.contentsOfDirectory(atPath: casePath)) ?? []
                let label = "\(group)/\(caseName)"
                if files.contains("chunks.json") {
                    // Streaming case.
                    if runStreamingCase(casePath: casePath, label: label) {
                        passed += 1
                    } else {
                        failed.append(label)
                    }
                    continue
                }
                if files.contains("patch.oui") {
                    skipped += 1
                    continue
                }
                if files.contains("validation.json") {
                    let validationPath = (casePath as NSString).appendingPathComponent("validation.json")
                    if runValidationCase(validationPath: validationPath, label: label) {
                        passed += 1
                    } else {
                        failed.append(label)
                    }
                    continue
                }
                let inputPath = (casePath as NSString).appendingPathComponent("input.oui")
                let expectedPath = (casePath as NSString).appendingPathComponent("expected.json")
                guard fm.fileExists(atPath: inputPath), fm.fileExists(atPath: expectedPath) else {
                    skipped += 1
                    continue
                }
                if runCase(inputPath: inputPath, expectedPath: expectedPath, label: label) {
                    passed += 1
                } else {
                    failed.append(label)
                }
            }
        }
        print("Conformance: \(passed) passed, \(failed.count) failed, \(skipped) skipped")
        for f in failed { print("  FAILED: \(f)") }
        XCTAssertEqual(failed.count, 0, "Failed cases: \(failed)")
    }

    func runCase(inputPath: String, expectedPath: String, label: String) -> Bool {
        guard let input = try? String(contentsOfFile: inputPath, encoding: .utf8),
              let expectedText = try? String(contentsOfFile: expectedPath, encoding: .utf8),
              let expectedJSON = try? parseJSONPreservingOrder(expectedText),
              case .object(let expectedFields) = expectedJSON else {
            print("  \(label): cannot read files")
            return false
        }
        let parser = createParser(schema: schema)
        let result = parser.parse(input)
        return checkResult(result: result, expectedFields: expectedFields, label: label)
    }

    func runStreamingCase(casePath: String, label: String) -> Bool {
        let chunksPath = (casePath as NSString).appendingPathComponent("chunks.json")
        let expectedPath = (casePath as NSString).appendingPathComponent("expected.json")
        guard let chunksText = try? String(contentsOfFile: chunksPath, encoding: .utf8),
              let chunksJSON = try? parseJSONPreservingOrder(chunksText),
              case .array(let chunkValues) = chunksJSON,
              let expectedText = try? String(contentsOfFile: expectedPath, encoding: .utf8),
              let expectedJSON = try? parseJSONPreservingOrder(expectedText),
              case .object(let expectedFields) = expectedJSON else {
            print("  \(label): cannot read files")
            return false
        }
        let chunks = chunkValues.compactMap { v -> String? in
            if case .string(let s) = v { return s }
            return nil
        }
        // Streamed.
        let parser = createStreamingParser(schema: schema)
        for (i, chunk) in chunks.enumerated() {
            parser.push(chunk, complete: i == chunks.count - 1)
        }
        let streamed = parser.getResult(complete: true)
        if !checkResult(result: streamed, expectedFields: expectedFields, label: label + " (streamed)") {
            return false
        }
        // Batch must match too.
        let batchParser = createParser(schema: schema)
        let batch = batchParser.parse(chunks.joined())
        if !checkResult(result: batch, expectedFields: expectedFields, label: label + " (batch)") {
            return false
        }
        return true
    }

    func runValidationCase(validationPath: String, label: String) -> Bool {
        guard let text = try? String(contentsOfFile: validationPath, encoding: .utf8),
              let json = try? parseJSONPreservingOrder(text),
              case .object(let fields) = json,
              let casesField = fields.first(where: { $0.key == "cases" })?.value,
              case .array(let cases) = casesField else {
            print("  \(label): cannot read validation.json")
            return false
        }
        var failed = 0
        for (i, c) in cases.enumerated() {
            guard case .object(let cf) = c,
                  let rulesJSON = cf.first(where: { $0.key == "rules" })?.value,
                  let valueJSON = cf.first(where: { $0.key == "value" })?.value,
                  let validField = cf.first(where: { $0.key == "valid" })?.value,
                  case .boolean(let valid) = validField else {
                print("  \(label): case \(i) malformed")
                failed += 1
                continue
            }
            // Convert JSONValue rules to [ValidationRule] and value to Value.
            let rules = parseStructuredRules(rulesJSON)
            let value = jsonValueToValue(valueJSON)
            let error = validate(value, rules: rules)
            let isValid = (error == nil)
            if isValid != valid {
                print("  \(label): case \(i) rules=\(rulesJSON) value=\(valueJSON): expected valid=\(valid), got error=\(String(describing: error))")
                failed += 1
            }
        }
        return failed == 0
    }

    func checkResult(result: ParseResult, expectedFields: [JSONField], label: String) -> Bool {
        let evaluator = makeEvaluator(result: result)
        let root = evaluator.evaluateRoot(result)
        let actualRoot: Any = root.map { summarize(.element($0), evaluator: evaluator) } ?? NSNull()

        // Compare root.
        let expectedRoot = expectedFields.first(where: { $0.key == "root" })?.value
        if !jsonEqual(actualRoot, jsonValueToAny(expectedRoot)) {
            print("  \(label): root mismatch")
            print("    actual: \(actualRoot)")
            print("    expected: \(String(describing: jsonValueToAny(expectedRoot)))")
            return false
        }
        // Compare errors (code + statementId).
        let expectedErrors = expectedFields.first(where: { $0.key == "errors" })?.value
        let actualErrors = (result.meta.errors.map { ["code": $0.code.rawValue, "statementId": $0.statementId as Any] }
            + evaluator.errors.map { ["code": $0.code.rawValue, "statementId": $0.statementId as Any] })
        if !errorsMatch(expected: expectedErrors, actual: actualErrors) {
            print("  \(label): errors mismatch")
            print("    actual: \(actualErrors)")
            return false
        }
        return true
    }

    // MARK: - Comparison helpers

    func jsonValueToValue(_ v: JSONValue) -> Value {
        switch v {
        case .null: return .null
        case .string(let s): return .string(s)
        case .number(let n): return .number(n)
        case .boolean(let b): return .boolean(b)
        case .array(let items): return .array(items.map(jsonValueToValue))
        case .object(let fields):
            return .object(fields.map { ObjectField(key: $0.key, value: jsonValueToValue($0.value)) })
        }
    }

    func jsonValueToAny(_ v: JSONValue?) -> Any {
        guard let v = v else { return NSNull() }
        switch v {
        case .null: return NSNull()
        case .string(let s): return s
        case .number(let n): return n
        case .boolean(let b): return b
        case .array(let items): return items.map(jsonValueToAny)
        case .object(let fields):
            var out: [String: Any] = [:]
            for f in fields { out[f.key] = jsonValueToAny(f.value) }
            return out
        }
    }

    func jsonEqual(_ a: Any, _ b: Any) -> Bool {
        // Deep equality with numeric tolerance.
        if a is NSNull, b is NSNull { return true }
        if let x = a as? String, let y = b as? String { return x == y }
        if let x = a as? Bool, let y = b as? Bool { return x == y }
        if let x = a as? Double, let y = b as? Double { return x == y }
        if let x = a as? [Any], let y = b as? [Any] {
            guard x.count == y.count else { return false }
            return zip(x, y).allSatisfy(jsonEqual)
        }
        if let x = a as? [String: Any], let y = b as? [String: Any] {
            guard x.count == y.count else { return false }
            for (k, v) in x {
                guard let yv = y[k], jsonEqual(v, yv) else { return false }
            }
            return true
        }
        return false
    }

    func errorsMatch(expected: JSONValue?, actual: [[String: Any]]) -> Bool {
        // Each expected entry claims an actual entry agreeing on listed keys.
        guard let expected = expected, case .array(let items) = expected else {
            return actual.isEmpty
        }
        var pool = actual
        // Entries listing more keys go first.
        let sorted = items.sorted { a, b in
            let ca = a.objectFields?.count ?? 0
            let cb = b.objectFields?.count ?? 0
            return ca > cb
        }
        for item in sorted {
            guard case .object(let fields) = item else { continue }
            let idx = pool.firstIndex { actual in
                fields.allSatisfy { f in
                    let av = actual[f.key]
                    let ev = jsonValueToAny(f.value)
                    if ev is NSNull { return av == nil || av is NSNull }
                    return jsonEqual(av as Any, ev)
                }
            }
            guard let i = idx else { return false }
            pool.remove(at: i)
        }
        return true
    }
}
