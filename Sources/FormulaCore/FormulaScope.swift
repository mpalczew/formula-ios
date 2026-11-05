struct ChildKey: Hashable {
    let type: ObjectIdentifier
    let key: AnyHashable?
}

@MainActor
protocol ScopeHost: AnyObject {
    func enqueue(_ action: @escaping () -> Bool)
}

@MainActor
class FormulaScope {
    let effects: FormulaEffects
    private(set) weak var parent: FormulaScope?
    private(set) weak var host: ScopeHost?
    private(set) var isActive = true
    var isDirty = true
    private var evaluating = false
    private var callbacks: [CallbackKey: any StoredCallback] = [:]
    private var children: [ChildKey: FormulaScope] = [:]
    private var seenCallbacks: Set<CallbackKey> = []
    private var seenChildren: Set<ChildKey> = []

    init(effects: FormulaEffects, parent: FormulaScope?, host: ScopeHost?) {
        self.effects = effects
        self.parent = parent
        self.host = host
    }

    func attach(host: ScopeHost) { self.host = host }

    func beginEvaluation() {
        precondition(isActive && !evaluating, "Invalid scope evaluation")
        evaluating = true
        seenCallbacks.removeAll(keepingCapacity: true)
        seenChildren.removeAll(keepingCapacity: true)
    }

    func endEvaluation() {
        for key in Array(callbacks.keys) where !seenCallbacks.contains(key) {
            callbacks.removeValue(forKey: key)?.invalidate()
        }
        for key in Array(children.keys) where !seenChildren.contains(key) {
            children.removeValue(forKey: key)?.invalidate()
        }
        evaluating = false
    }

    func callback<Value>(_ key: CallbackKey, invoke: @escaping (Value) -> Void) -> Callback<Value> {
        precondition(evaluating, "Declare callbacks during render")
        precondition(seenCallbacks.insert(key).inserted, "Repeated callbacks need distinct keys")
        let storage: CallbackStorage<Value>
        if let existing = callbacks[key] {
            guard let typed = existing as? CallbackStorage<Value> else {
                preconditionFailure("A callback key cannot change input type")
            }
            storage = typed
        } else {
            storage = CallbackStorage()
            callbacks[key] = storage
        }
        storage.invoke = invoke
        return Callback(storage: storage)
    }

    func child<Child: Formula>(_ formula: Child, input: Child.Input, key: AnyHashable?) -> Child.RenderModel {
        precondition(evaluating, "Declare children during render")
        let identity = ChildKey(type: ObjectIdentifier(Child.self), key: key)
        precondition(seenChildren.insert(identity).inserted, "Repeated children need distinct keys")
        let node: FormulaNode<Child>
        if let existing = children[identity] as? FormulaNode<Child> {
            node = existing
            node.updateInput(formula, input)
        } else {
            node = FormulaNode(formula: formula, input: input, effects: effects, parent: self, host: host)
            children[identity] = node
        }
        return node.renderIfNeeded()
    }

    func markDirty() {
        var scope: FormulaScope? = self
        while let current = scope {
            current.isDirty = true
            scope = current.parent
        }
    }

    func cancelEffects() {
        effects.cancel(in: self)
        children.values.forEach { $0.cancelEffects() }
    }

    func invalidate() {
        isActive = false
        effects.cancel(in: self)
        callbacks.values.forEach { $0.invalidate() }
        children.values.forEach { $0.invalidate() }
        callbacks.removeAll()
        children.removeAll()
    }
}

@MainActor
final class FormulaNode<F: Formula>: FormulaScope {
    private var formula: F
    private(set) var state: F.State
    private var input: F.Input
    private var model: F.RenderModel?

    init(formula: F, input: F.Input, effects: FormulaEffects, parent: FormulaScope?, host: ScopeHost?) {
        self.formula = formula
        self.input = input
        self.state = formula.initialState(input: input)
        super.init(effects: effects, parent: parent, host: host)
    }

    @discardableResult
    func updateInput(_ formula: F, _ input: F.Input) -> Bool {
        self.formula = formula
        guard !inputsEqual(self.input, input) else { return false }
        formula.onInputChanged(old: self.input, new: input, state: &state)
        self.input = input
        markDirty()
        return true
    }

    func renderIfNeeded() -> F.RenderModel {
        if let model, !isDirty { return model }
        isDirty = false
        beginEvaluation()
        defer { endEvaluation() }
        let rendered = formula.render(input: input, state: state, context: FormulaContext(scope: self))
        model = rendered
        return rendered
    }

    func mutate(_ mutation: (inout F.State) -> Void) {
        guard isActive else { return }
        mutation(&state)
        markDirty()
    }

    func transition(_ mutation: @escaping (inout F.State) -> Void) {
        guard isActive, let host else { return }
        host.enqueue { [weak self] in
            guard let self, self.isActive else { return false }
            self.mutate(mutation)
            return true
        }
    }
}

private func inputsEqual<T>(_ old: T, _ new: T) -> Bool {
    if T.self == Void.self { return true }
    guard let old = old as? any Equatable else { return false }
    return areEqual(old, new)
}

private func areEqual<E: Equatable>(_ lhs: E, _ rhs: Any) -> Bool {
    guard let rhs = rhs as? E else { return false }
    return lhs == rhs
}
