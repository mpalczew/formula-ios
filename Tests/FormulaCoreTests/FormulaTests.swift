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

    @MainActor
    func testEffectAppliesMutationAfterAsyncWork() async throws {
        let store = FormulaStore(formula: EffectFormula(), initialState: .init())

        store.renderModel.load()
        try await Task.sleep(for: .milliseconds(40))

        XCTAssertEqual(store.state.value, 1)
    }

    @MainActor
    func testChildEffectMutatesOnlyChildState() async throws {
        let store = FormulaStore(formula: EffectParentFormula(), initialState: .init())

        store.renderModel.child.load()
        try await Task.sleep(for: .milliseconds(40))

        XCTAssertEqual(store.state.child.value, 1)
        XCTAssertEqual(store.state.parentValue, 0)
    }

    @MainActor
    func testCancelledEffectCannotApplyLateMutation() async throws {
        let store = FormulaStore(formula: EffectFormula(), initialState: .init())

        store.renderModel.load()
        store.cancelEffects()
        try await Task.sleep(for: .milliseconds(40))

        XCTAssertEqual(store.state.value, 0)
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

private struct EffectFormula: Formula {
    struct State { var value = 0 }
    struct RenderModel { let value: Int; let load: () -> Void }

    @MainActor
    func render(state: State, context: FormulaContext<State>) -> RenderModel {
        .init(value: state.value, load: context.callback { _ in
            context.effect {
                try? await Task.sleep(for: .milliseconds(20))
                return { $0.value += 1 }
            }
        })
    }
}

private struct EffectParentFormula: Formula {
    struct State { var parentValue = 0; var child = EffectChildFormula.State() }
    struct RenderModel { let child: EffectChildFormula.RenderModel }

    @MainActor
    func render(state: State, context: FormulaContext<State>) -> RenderModel {
        .init(child: context.child(EffectChildFormula(), state: \.child))
    }
}

private struct EffectChildFormula: Formula {
    struct State { var value = 0 }
    struct RenderModel { let load: () -> Void }

    @MainActor
    func render(state: State, context: FormulaContext<State>) -> RenderModel {
        .init(load: context.callback { _ in
            context.effect {
                try? await Task.sleep(for: .milliseconds(20))
                return { $0.value += 1 }
            }
        })
    }
}
