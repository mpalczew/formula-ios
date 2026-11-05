import XCTest
@testable import FormulaCore

final class FormulaTests: XCTestCase {
    @MainActor
    func testCallbackTransitionsStateAndRendersAgain() {
        let store = FormulaStore(formula: CounterFormula())
        XCTAssertEqual(store.renderModel.count, 0)
        store.renderModel.increment()
        XCTAssertEqual(store.renderModel.count, 1)
        XCTAssertEqual(store.state.count, 1)
    }

    @MainActor
    func testChildCallbackMutatesOnlyChildState() {
        let store = FormulaStore(formula: ParentFormula())
        store.renderModel.child.increment()
        XCTAssertEqual(store.renderModel.child.count, 1)
        XCTAssertEqual(store.state.parentCount, 0)
    }

    @MainActor
    func testStatelessFormulaRendersFromInput() {
        let store = FormulaStore(formula: Greeting(), input: "Ada")
        XCTAssertEqual(store.renderModel, "Hello Ada")
        store.update(input: "Grace")
        XCTAssertEqual(store.renderModel, "Hello Grace")
    }
}

private struct CounterFormula: Formula {
    struct State { var count = 0 }
    struct RenderModel: Equatable { let count: Int; let increment: Callback<Void> }
    func initialState(input: Void) -> State { State() }
    func render(input: Void, state: State, context: FormulaContext<Self>) -> RenderModel {
        .init(count: state.count, increment: context.callback { $0.count += 1 })
    }
}

private struct ParentFormula: Formula {
    struct State { var parentCount = 0 }
    struct RenderModel: Equatable { let child: ChildFormula.RenderModel }
    func initialState(input: Void) -> State { State() }
    func render(input: Void, state: State, context: FormulaContext<Self>) -> RenderModel {
        .init(child: context.child(ChildFormula()))
    }
}

private struct ChildFormula: Formula {
    struct State { var count = 0 }
    struct RenderModel: Equatable { let count: Int; let increment: Callback<Void> }
    func initialState(input: Void) -> State { State() }
    func render(input: Void, state: State, context: FormulaContext<Self>) -> RenderModel {
        .init(count: state.count, increment: context.callback { $0.count += 1 })
    }
}

private struct Greeting: StatelessFormula {
    typealias Input = String
    typealias RenderModel = String
    func render(input: String, context: FormulaContext<Self>) -> String { "Hello \(input)" }
}
