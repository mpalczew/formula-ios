import Foundation
import Combine

public protocol Formula {
    associatedtype State
    associatedtype RenderModel

    @MainActor
    func render(state: State, context: FormulaContext<State>) -> RenderModel
}

@MainActor
public struct FormulaContext<State> {
    private let applyMutation: (@escaping (inout State) -> Void) -> Void
    private let launchEffect: (@escaping () async -> ((inout State) -> Void)) -> Void
    private let readState: () -> State

    public init(
        applyMutation: @escaping (@escaping (inout State) -> Void) -> Void,
        launchEffect: @escaping (@escaping () async -> ((inout State) -> Void)) -> Void = { _ in },
        readState: @escaping () -> State
    ) {
        self.applyMutation = applyMutation
        self.launchEffect = launchEffect
        self.readState = readState
    }

    public func transition(_ mutation: @escaping (inout State) -> Void) {
        applyMutation(mutation)
    }

    public func callback(_ mutation: @escaping (inout State) -> Void) -> () -> Void {
        { @MainActor in self.transition(mutation) }
    }

    public func effect(_ operation: @escaping () async -> ((inout State) -> Void)) {
        launchEffect(operation)
    }

    public func child<Child: Formula>(
        _ formula: Child,
        state keyPath: WritableKeyPath<State, Child.State>
    ) -> Child.RenderModel {
        let childContext = FormulaContext<Child.State>(
            applyMutation: { mutation in
                self.transition { parent in
                    mutation(&parent[keyPath: keyPath])
                }
            },
            launchEffect: { operation in
                self.effect {
                    let childMutation = await operation()
                    return { parent in
                        childMutation(&parent[keyPath: keyPath])
                    }
                }
            },
            readState: { self.readState()[keyPath: keyPath] }
        )
        return formula.render(state: childContext.readState(), context: childContext)
    }
}

@MainActor
public final class FormulaStore<F: Formula>: ObservableObject {
    @Published public private(set) var state: F.State
    @Published public private(set) var renderModel: F.RenderModel

    private let formula: F
    private var tasks: [Task<Void, Never>] = []

    public init(formula: F, initialState: F.State) {
        self.formula = formula
        self.state = initialState
        self.renderModel = formula.render(
            state: initialState,
            context: FormulaContext(applyMutation: { _ in }, readState: { initialState })
        )
        self.renderModel = makeRenderModel()
    }

    public func send(_ mutation: @escaping (inout F.State) -> Void) {
        mutation(&state)
        renderModel = makeRenderModel()
    }

    public func cancelEffects() {
        tasks.forEach { $0.cancel() }
        tasks.removeAll()
    }

    private func makeRenderModel() -> F.RenderModel {
        let context = FormulaContext<F.State>(
            applyMutation: { [weak self] mutation in self?.send(mutation) },
            launchEffect: { [weak self] operation in
                guard let self else { return }
                let task = Task { @MainActor [weak self] in
                    let mutation = await operation()
                    guard !Task.isCancelled else { return }
                    self?.send(mutation)
                }
                self.tasks.append(task)
            },
            readState: { self.state }
        )
        return formula.render(state: state, context: context)
    }
}
