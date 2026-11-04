import Combine

@MainActor
public final class FormulaStore<F: Formula>: ObservableObject {
    @Published public private(set) var renderModel: F.RenderModel
    public var state: F.State { runtime.state }
    public var activeEffectCount: Int { runtime.effects.activeCount }
    private let runtime: FormulaRuntime<F>

    public init(formula: F, initialState: F.State) {
        let runtime = FormulaRuntime(formula: formula, state: initialState)
        self.runtime = runtime
        self.renderModel = runtime.evaluate()
        runtime.onRender = { [weak self] model in
            guard let self, self.renderModel != model else { return }
            self.renderModel = model
        }
    }

    public func send(_ mutation: @escaping (inout F.State) -> Void) { runtime.send(mutation) }
    public func cancelEffects() { runtime.scope.cancelEffects() }

    /// Waits for all started effects, including canceled operations, to finish.
    /// Useful with controllable test clients; this does not advance time for them.
    public func waitForEffects() async { await runtime.effects.waitUntilIdle() }
}

@MainActor
private final class FormulaRuntime<F: Formula> {
    private(set) var state: F.State
    let effects = FormulaEffects()
    let scope: FormulaScope
    var onRender: ((F.RenderModel) -> Void)?
    private let formula: F
    private var pending: [(inout F.State) -> Void] = []
    private var processing = false
    private var evaluating = false

    init(formula: F, state: F.State) {
        self.formula = formula
        self.state = state
        self.scope = FormulaScope(effects: effects)
    }

    func send(_ mutation: @escaping (inout F.State) -> Void) {
        precondition(!evaluating, "Render must not transition state")
        pending.append(mutation)
        guard !processing else { return }
        processing = true
        defer { processing = false }
        while !pending.isEmpty {
            let next = pending.removeFirst()
            next(&state)
            onRender?(evaluate())
        }
    }

    func evaluate() -> F.RenderModel {
        evaluating = true
        scope.beginEvaluation()
        defer { scope.endEvaluation(); evaluating = false }
        let context = FormulaContext(state: state, scope: scope) { [weak self] mutation in
            self?.send(mutation)
        }
        return formula.render(state: state, context: context)
    }
}
