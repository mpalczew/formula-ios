@MainActor
public struct FormulaContext<State> {
    private let state: State
    private weak var scope: FormulaScope?
    private let applyMutation: (@escaping (inout State) -> Void) -> Void

    init(state: State, scope: FormulaScope,
         applyMutation: @escaping (@escaping (inout State) -> Void) -> Void) {
        self.state = state
        self.scope = scope
        self.applyMutation = applyMutation
    }

    public func transition(_ mutation: @escaping (inout State) -> Void) {
        guard let scope, scope.isActive else { return }
        applyMutation { [weak scope] state in
            guard scope?.isActive == true else { return }
            mutation(&state)
        }
    }

    public func callback(
        key: AnyHashable? = nil,
        file: StaticString = #fileID, line: UInt = #line, column: UInt = #column,
        _ mutation: @escaping (inout State) -> Void
    ) -> Callback<Void> {
        callback(key: key, file: file, line: line, column: column) { (state: inout State, _: Void) in
            mutation(&state)
        }
    }

    public func callback<Input>(
        key: AnyHashable? = nil,
        file: StaticString = #fileID, line: UInt = #line, column: UInt = #column,
        _ mutation: @escaping (inout State, Input) -> Void
    ) -> Callback<Input> {
        guard let scope else { preconditionFailure("Callbacks require a live evaluation") }
        let identity = CallbackKey(file: String(describing: file), line: line, column: column, key: key)
        return scope.callback(identity) { input in
            self.transition { mutation(&$0, input) }
        }
    }

    /// A key replaces the previous effect with that key in this scope.
    /// Omitting the key allows independent concurrent effects.
    public func effect(
        key: AnyHashable? = nil,
        _ operation: @escaping @MainActor () async -> ((inout State) -> Void)
    ) {
        guard let scope, scope.isActive else { return }
        scope.effects.launch(in: scope, key: key) {
            let mutation = await operation()
            return { self.transition(mutation) }
        }
    }

    public func cancelEffect(key: AnyHashable) {
        guard let scope else { return }
        scope.effects.cancel(in: scope, key: key)
    }

    /// Cancels effects owned by this scope and all its children.
    public func cancelEffects() { scope?.cancelEffects() }

    public func child<Child: Formula>(
        _ formula: Child,
        state keyPath: WritableKeyPath<State, Child.State>,
        key: AnyHashable? = nil
    ) -> Child.RenderModel {
        guard let scope else { preconditionFailure("Children require a live evaluation") }
        let identity = ChildKey(type: ObjectIdentifier(Child.self), path: keyPath, key: key)
        let childScope = scope.child(identity)
        childScope.beginEvaluation()
        defer { childScope.endEvaluation() }
        let context = FormulaContext<Child.State>(
            state: state[keyPath: keyPath], scope: childScope,
            applyMutation: { mutation in
                self.transition { mutation(&$0[keyPath: keyPath]) }
            }
        )
        return formula.render(state: state[keyPath: keyPath], context: context)
    }
}
