public protocol Formula {
    associatedtype State
    associatedtype RenderModel: Equatable

    @MainActor
    func render(state: State, context: FormulaContext<State>) -> RenderModel
}
