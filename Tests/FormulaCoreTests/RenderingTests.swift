import Combine
import XCTest
@testable import FormulaCore

final class RenderingTests: XCTestCase {
    @MainActor
    func testInitialModelIsEvaluatedOnceAndNoopDoesNotPublish() {
        let probe = EvaluationProbe()
        let store = FormulaStore(formula: CountingFormula(probe: probe))
        XCTAssertEqual(probe.count, 1)
        var values: [Int] = []
        let subscription = store.$renderModel.sink { values.append($0) }
        store.send { _ in }
        store.send { $0 = 1 }
        store.send { $0 = 1 }
        XCTAssertEqual(values, [0, 1])
        withExtendedLifetime(subscription) {}
    }

    @MainActor
    func testHiddenStateChangeDoesNotPublishAViewUpdate() {
        let store = FormulaStore(formula: HiddenStateFormula())
        var updates = 0
        let subscription = store.objectWillChange.sink { updates += 1 }

        store.send { $0.hidden += 1 }

        XCTAssertEqual(store.state.hidden, 1)
        XCTAssertEqual(updates, 0)
        withExtendedLifetime(subscription) {}
    }
}

@MainActor
private final class EvaluationProbe { var count = 0 }

private struct CountingFormula: Formula {
    let probe: EvaluationProbe
    func initialState(input: Void) -> Int { 0 }
    func render(input: Void, state: Int, context: FormulaContext<Self>) -> Int {
        probe.count += 1
        return state
    }
}

private struct HiddenStateFormula: Formula {
    struct State { var hidden = 0 }
    struct RenderModel: Equatable { let title: String }

    func initialState(input: Void) -> State { State() }
    func render(input: Void, state: State, context: FormulaContext<Self>) -> RenderModel {
        .init(title: "Unchanged")
    }
}
