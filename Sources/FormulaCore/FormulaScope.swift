struct ChildKey: Hashable {
    let type: ObjectIdentifier
    let path: AnyKeyPath
    let key: AnyHashable?
}

@MainActor
final class FormulaScope {
    let effects: FormulaEffects
    private(set) var isActive = true
    private var evaluating = false
    private var callbacks: [CallbackKey: any StoredCallback] = [:]
    private var children: [ChildKey: FormulaScope] = [:]
    private var seenCallbacks: Set<CallbackKey> = []
    private var seenChildren: Set<ChildKey> = []

    init(effects: FormulaEffects) { self.effects = effects }

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

    func callback<Input>(_ key: CallbackKey, invoke: @escaping (Input) -> Void) -> Callback<Input> {
        precondition(evaluating, "Declare callbacks during render")
        precondition(seenCallbacks.insert(key).inserted, "Repeated callbacks need distinct keys")
        let storage: CallbackStorage<Input>
        if let existing = callbacks[key] {
            guard let typed = existing as? CallbackStorage<Input> else {
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

    func child(_ key: ChildKey) -> FormulaScope {
        precondition(evaluating, "Declare children during render")
        precondition(seenChildren.insert(key).inserted, "Repeated children need distinct keys")
        if let child = children[key] { return child }
        let child = FormulaScope(effects: effects)
        children[key] = child
        return child
    }

    func cancelEffects() {
        effects.cancel(in: self)
        children.values.forEach { $0.cancelEffects() }
    }

    private func invalidate() {
        isActive = false
        effects.cancel(in: self)
        callbacks.values.forEach { $0.invalidate() }
        children.values.forEach { $0.invalidate() }
        callbacks.removeAll()
        children.removeAll()
    }
}
