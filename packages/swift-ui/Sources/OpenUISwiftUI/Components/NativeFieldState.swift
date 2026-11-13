import OpenUILang
import SwiftUI

@MainActor
final class NativeFormValidation: ObservableObject {
    struct Field {
        let rules: [ParsedRule]
        let value: () -> Value
        var prepare: () -> Void = {}
        var draftError: () -> String? = { nil }
    }
    private var declaredFields: [OpenUIString: Field] = [:]
    private var fields: [OpenUIString: Field] = [:]
    private var owners: [OpenUIString: UUID] = [:]
    // Field-local pending edits are flushed before semantic form actions.
    // Owner identity prevents a disappearing view from unregistering its replacement.
    private var pendingWrites: [OpenUIString: (owner: UUID, flush: () -> Void, error: () -> String?)] = [:]
    private var fieldOrder: [OpenUIString] = []
    @Published private(set) var errors: [OpenUIString: String] = [:]
    @Published private(set) var firstInvalid: OpenUIString?

    static func requiresValidation(_ plan: ActionPlan?) -> Bool {
        guard let plan else { return true }
        return plan.steps.contains { step in
            switch step {
            case .continueConversation, .custom: return true
            case .run(_, let kind): return kind == .mutation
            default: return false
            }
        }
    }
    static func requiresValidation(action: Value?) -> Bool {
        if case .actionPlan(let plan) = action { return requiresValidation(plan) }
        if case .object(let fields) = action,
           case .string(let type) = fields.last(where: { $0.key == "type" })?.value,
           type == "open_url" { return false }
        return true
    }
    func register(
        _ name: OpenUIString, owner: UUID? = nil, rules: [ParsedRule], value: @escaping () -> Value
    ) {
        if fields[name] == nil && !fieldOrder.contains(name) { fieldOrder.append(name) }
        fields[name] = Field(rules: rules, value: value)
        owners[name] = owner ?? owners[name] ?? UUID()
    }
    func unregister(_ name: OpenUIString, owner: UUID? = nil) {
        if let owner, owners[name] != owner { return }
        owners.removeValue(forKey: name)
        fields.removeValue(forKey: name)
        if declaredFields[name] == nil {
            fieldOrder.removeAll { $0 == name }
            if errors[name] != nil { errors.removeValue(forKey: name) }
        }
        updateFirstInvalid()
    }
    func registerPendingWrite(_ name: OpenUIString, owner: UUID,
        flush: @escaping () -> Void, error: @escaping () -> String? = { nil }) {
        if !fieldOrder.contains(name) { fieldOrder.append(name) }
        pendingWrites[name] = (owner, flush, error)
        if var declared = declaredFields[name] {
            declared.prepare = flush; declared.draftError = error
            declaredFields[name] = declared
        }
    }
    func setDeclarations(_ fields: [(OpenUIString, Field)]) {
        declaredFields = Dictionary(fields, uniquingKeysWith: { _, latest in latest })
        let retained = Set(declaredFields.keys).union(self.fields.keys).union(pendingWrites.keys)
        fieldOrder = fieldOrder.filter { retained.contains($0) }
        let next = errors.filter { retained.contains($0.key) }
        if next != errors { errors = next }
        setFieldOrder(fields.map { $0.0 })
    }
    func setFieldOrder(_ names: [OpenUIString]) {
        var seen = Set<OpenUIString>()
        fieldOrder = (names + fieldOrder).filter { seen.insert($0).inserted }
        updateFirstInvalid()
    }
    private func updateFirstInvalid() {
        let next = fieldOrder.first { errors[$0] != nil }
            ?? errors.keys.sorted().first
        if firstInvalid != next { firstInvalid = next }
    }
    /// Validate unrepresentable editing text before any Store writes occur.
    /// Disabling declarative form rules must not submit an older numeric value.
    @discardableResult func preparePendingWrites() -> Bool {
        let mounted = pendingWrites
        let declared = declaredFields
        var next = errors
        var invalid = false
        for name in fieldOrder {
            let error = mounted[name]?.error() ?? declared[name]?.draftError()
            if let error { next[name] = error; invalid = true }
            else {
                let field = fields[name] ?? declared[name]
                next[name] = field.flatMap { OpenUILang.validate($0.value(), rules: $0.rules) }
            }
        }
        if errors != next { errors = next }
        updateFirstInvalid()
        guard !invalid else { return false }
        for name in fieldOrder {
            if let write = mounted[name] {
                guard pendingWrites[name]?.owner == write.owner else { continue }
                write.flush()
            } else { declared[name]?.prepare() }
        }
        return true
    }
    func unregisterPendingWrite(_ name: OpenUIString, owner: UUID) {
        guard pendingWrites[name]?.owner == owner else { return }
        pendingWrites.removeValue(forKey: name)
    }
    func flushPendingWrites() { _ = preparePendingWrites() }
    @discardableResult func validateAll() -> Bool {
        guard preparePendingWrites() else { return false }
        let candidates = declaredFields.merging(fields, uniquingKeysWith: { _, mounted in mounted })
        let next = candidates.reduce(into: [OpenUIString: String]()) { result, entry in
            if let error = OpenUILang.validate(entry.value.value(), rules: entry.value.rules) {
                result[entry.key] = error
            }
        }
        if errors != next { errors = next }
        updateFirstInvalid()
        return next.isEmpty
    }
    func changed(_ name: OpenUIString, value: Value, rules: [ParsedRule]) {
        let error = OpenUILang.validate(value, rules: rules)
        if errors[name] != error { errors[name] = error }
        updateFirstInvalid()
    }
}

private struct OpenUIFormValidationKey: EnvironmentKey {
    static let defaultValue: NativeFormValidation? = nil
}
private struct OpenUIFieldLabelKey: EnvironmentKey { static let defaultValue: String? = nil }
private struct OpenUIExactFormNameKey: EnvironmentKey { static let defaultValue: OpenUIString? = nil }
extension EnvironmentValues {
    var openUIFieldLabel: String? {
        get { self[OpenUIFieldLabelKey.self] }
        set { self[OpenUIFieldLabelKey.self] = newValue }
    }

    var openUIFormValidation: NativeFormValidation? {
        get { self[OpenUIFormValidationKey.self] }
        set { self[OpenUIFormValidationKey.self] = newValue }
    }
    var openUIExactFormName: OpenUIString? {
        get { self[OpenUIExactFormNameKey.self] }
        set { self[OpenUIExactFormNameKey.self] = newValue }
    }
}

/// Shared field adapter; no additional store or server state protocol.
@MainActor
struct NativeFieldState {
    let context: OpenUIComponentContext
    var name: OpenUIString { context.codeUnitString("name") ?? "" }
    private var componentType: String { context.element.typeName }
    var rules: [ParsedRule] {
        guard let raw = context.value("rules"), let json = try? raw.jsonValue() else { return [] }
        if case .array = json { return parseRules(json) }
        return parseStructuredRules(json)
    }
    var options: [EvaluatedElement] {
        context.children("items").compactMap {
            if case .element(let item) = $0.value { return item }
            return nil
        }
    }
    var initialValue: Value {
        if let value = context.value("value"), context.binding("value") == nil, value != .null {
            return value
        }
        if ["Chips", "OptionCards"].contains(componentType) {
            let values = NativeChoiceSelection.values(context.value("defaultValue") ?? .undefined)
            return NativeChoiceSelection.stored(values, single: NativeChoiceSelection.isSingle(context))
        }
        if let defaults = context.value("defaultValue") { return defaults }
        if ["CheckBoxGroup", "SwitchGroup"].contains(context.element.typeName) {
            return .object(
                options.compactMap { item in
                    guard let key = PropValue.codeUnitString(item, "name") else { return nil }
                    return ObjectField(
                        key: key, value: PropValue.value(item, "defaultChecked") ?? .boolean(false))
                })
        }
        return .null
    }
    var value: Value {
        context.binding("value")?.wrappedValue ?? context.fieldValue(name, fallback: initialValue)
    }
    func write(_ value: Value) {
        guard context.canInteract else { return }
        if let binding = context.binding("value") {
            binding.wrappedValue = value
        } else {
            context.fieldBinding(name, componentType: componentType).wrappedValue = value
        }
        mirror()
    }
    func initialize() {
        guard context.canInteract else { return }
        if context.binding("value") == nil {
            context.initializeField(name, value: initialValue, componentType: componentType)
        }
        mirror()
    }
    func mirror() {
        guard context.canInteract, context.exactFormName != nil, context.binding("value") != nil else {
            return
        }
        if context.fieldValue(name) != value {
            context.fieldBinding(name, componentType: componentType).wrappedValue = value
        }
    }
    var validationValue: Value {
        if context.element.typeName == "Slider", case .array(let items) = value {
            return items.first ?? .null
        }
        return value
    }
    var text: Binding<String> {
        Binding(
            get: {
                if case .string(let value) = value { return value.displayString }
                return ""
            }, set: { write(.string($0)) })
    }
    var selected: Binding<OpenUIString> {
        Binding(
            get: {
                if case .string(let value) = value { return value }
                return ""
            }, set: { write(.string($0)) })
    }
    func toggle(_ key: OpenUIString) -> Binding<Bool> {
        Binding(
            get: {
                if case .object(let object) = value, case .boolean(let checked) = object[key] {
                    return checked
                }
                return false
            },
            set: { checked in
                var fields: [ObjectField] = []
                if case .object(let object) = value { fields = Array(object).filter { $0.key != key } }
                fields.append(ObjectField(key: key, value: .boolean(checked)))
                write(.object(fields))
            })
    }
}
