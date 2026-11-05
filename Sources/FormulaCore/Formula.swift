public protocol Formula {
    associatedtype Input
    associatedtype State
    associatedtype RenderModel: Equatable

    @MainActor
    func initialState(input: Input) -> State

    @MainActor
    func onInputChanged(old: Input, new: Input, state: inout State)

    @MainActor
    func render(input: Input, state: State, context: FormulaContext<Self>) -> RenderModel
}

public extension Formula {
    @MainActor
    func onInputChanged(old: Input, new: Input, state: inout State) {}
}

public protocol StatelessFormula: Formula where State == Void {
    @MainActor
    func render(input: Input, context: FormulaContext<Self>) -> RenderModel
}

public extension StatelessFormula {
    @MainActor
    func initialState(input: Input) {}

    @MainActor
    func render(input: Input, state: Void, context: FormulaContext<Self>) -> RenderModel {
        render(input: input, context: context)
    }
}
