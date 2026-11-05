@MainActor
public struct FormulaContext<F: Formula> {
    private weak var scope: FormulaNode<F>?

    init(scope: FormulaNode<F>) { self.scope = scope }

    public func transition(_ mutation: @escaping (inout F.State) -> Void) {
        scope?.transition(mutation)
    }

    public func callback(
        key: AnyHashable? = nil,
        file: StaticString = #fileID, line: UInt = #line, column: UInt = #column,
        _ mutation: @escaping (inout F.State) -> Void
    ) -> Callback<Void> {
        callback(key: key, file: file, line: line, column: column) { (state: inout F.State, _: Void) in
            mutation(&state)
        }
    }

    public func callback<Value>(
        key: AnyHashable? = nil,
        file: StaticString = #fileID, line: UInt = #line, column: UInt = #column,
        _ mutation: @escaping (inout F.State, Value) -> Void
    ) -> Callback<Value> {
        guard let scope else { preconditionFailure("Callbacks require a live evaluation") }
        let identity = CallbackKey(file: String(describing: file), line: line, column: column, key: key)
        return scope.callback(identity) { value in
            self.transition { mutation(&$0, value) }
        }
    }

    /// A key replaces the previous effect with that key in this scope.
    /// Omitting the key allows independent concurrent effects.
    public func effect(
        key: AnyHashable? = nil,
        _ operation: @escaping @MainActor () async -> ((inout F.State) -> Void)
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
        input: Child.Input,
        key: AnyHashable? = nil
    ) -> Child.RenderModel {
        guard let scope else { preconditionFailure("Children require a live evaluation") }
        return scope.child(formula, input: input, key: key)
    }

    public func child<Child: Formula>(
        _ formula: Child,
        key: AnyHashable? = nil
    ) -> Child.RenderModel where Child.Input == Void {
        child(formula, input: (), key: key)
    }
}
