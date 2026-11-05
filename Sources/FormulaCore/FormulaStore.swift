import Combine

@MainActor
public final class FormulaStore<F: Formula>: ObservableObject {
    @Published public private(set) var renderModel: F.RenderModel
    public var state: F.State { runtime.root.state }
    public var activeEffectCount: Int { runtime.effects.activeCount }
    private let runtime: FormulaRuntime<F>

    public init(formula: F, input: F.Input) {
        let runtime = FormulaRuntime(formula: formula, input: input)
        self.runtime = runtime
        self.renderModel = runtime.evaluate()
        runtime.onRender = { [weak self] model in
            guard let self, self.renderModel != model else { return }
            self.renderModel = model
        }
    }

    public func send(_ mutation: @escaping (inout F.State) -> Void) { runtime.send(mutation) }
    public func update(input: F.Input) { runtime.update(input: input) }
    public func cancelEffects() { runtime.root.cancelEffects() }

    /// Waits for all started effects, including canceled operations, to finish.
    /// Useful with controllable test clients; this does not advance time for them.
    public func waitForEffects() async { await runtime.effects.waitUntilIdle() }
}

public extension FormulaStore where F.Input == Void {
    convenience init(formula: F) { self.init(formula: formula, input: ()) }
}

@MainActor
private final class FormulaRuntime<F: Formula>: ScopeHost {
    let effects = FormulaEffects()
    let root: FormulaNode<F>
    var onRender: ((F.RenderModel) -> Void)?
    private var isEvaluating = false
    private let formula: F
    private var pending: [() -> Bool] = []
    private var processing = false

    init(formula: F, input: F.Input) {
        self.formula = formula
        self.root = FormulaNode(formula: formula, input: input, effects: effects, parent: nil, host: nil)
        root.attach(host: self)
    }

    func send(_ mutation: @escaping (inout F.State) -> Void) {
        enqueue { [root] in
            root.mutate(mutation)
            return true
        }
    }

    func update(input: F.Input) {
        enqueue { [root, formula] in root.updateInput(formula, input) }
    }

    func enqueue(_ action: @escaping () -> Bool) {
        precondition(!isEvaluating, "Render must not transition state")
        pending.append(action)
        guard !processing else { return }
        processing = true
        defer { processing = false }
        while !pending.isEmpty {
            let next = pending.removeFirst()
            if next() { onRender?(evaluate()) }
        }
    }

    func evaluate() -> F.RenderModel {
        isEvaluating = true
        defer { isEvaluating = false }
        return root.renderIfNeeded()
    }
}
