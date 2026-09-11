import XCTest
@testable import FormulaCore

final class FormulaTests: XCTestCase {
    @MainActor
    func testCallbackTransitionsStateAndRendersAgain() {
        let store = FormulaStore(formula: CounterFormula(), initialState: .init())
        XCTAssertEqual(store.renderModel.count, 0)
        store.renderModel.increment()
        XCTAssertEqual(store.renderModel.count, 1)
        XCTAssertEqual(store.state.count, 1)
    }

    @MainActor
    func testChildCallbackMutatesOnlyChildState() {
        let store = FormulaStore(formula: ParentFormula(), initialState: .init())
        store.renderModel.child.increment()
        XCTAssertEqual(store.state.child.count, 1)
        XCTAssertEqual(store.state.parentCount, 0)
    }
}

private struct CounterFormula: Formula {
    struct State { var count = 0 }
    struct RenderModel { let count: Int; let increment: () -> Void }
    func render(state: State, context: FormulaContext<State>) -> RenderModel {
        .init(count: state.count, increment: context.callback { $0.count += 1 })
    }
}

private struct ParentFormula: Formula {
    struct State { var parentCount = 0; var child = ChildFormula.State() }
    struct RenderModel { let child: ChildFormula.RenderModel }
    func render(state: State, context: FormulaContext<State>) -> RenderModel {
        .init(child: context.child(ChildFormula(), state: \.child))
    }
}

private struct ChildFormula: Formula {
    struct State { var count = 0 }
    struct RenderModel { let increment: () -> Void }
    func render(state: State, context: FormulaContext<State>) -> RenderModel {
        .init(increment: context.callback { $0.count += 1 })
    }
}
