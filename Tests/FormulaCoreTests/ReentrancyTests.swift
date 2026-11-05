import Combine
import XCTest
@testable import FormulaCore

final class ReentrancyTests: XCTestCase {
    @MainActor
    func testQueuedCallbackDoesNotAccessRemovedChildState() {
        let store = FormulaStore(formula: IndexedParent())
        let increment = store.renderModel[0].increment
        store.send { state in
            state.ids.removeAll()
            increment()
        }
        XCTAssertTrue(store.state.ids.isEmpty)
        XCTAssertTrue(store.renderModel.isEmpty)
    }

    @MainActor
    func testQueuedCallbackDoesNotMutateReplacementAtSameIndex() {
        let store = FormulaStore(formula: IndexedParent())
        let increment = store.renderModel[0].increment
        store.send { state in
            state.ids = [2]
            increment()
        }
        XCTAssertEqual(store.renderModel[0].count, 0)
        XCTAssertNotEqual(increment, store.renderModel[0].increment)
        store.renderModel[0].increment()
        XCTAssertEqual(store.renderModel[0].count, 1)
    }

    @MainActor
    func testNestedSendsPublishInOrder() {
        let store = FormulaStore(formula: Counter())
        var values: [Int] = []
        let subscription = store.$renderModel.sink { values.append($0) }
        store.send { state in
            state = 1
            store.send { $0 += 1 }
        }
        XCTAssertEqual(values, [0, 1, 2])
        XCTAssertEqual(store.state, 2)
        withExtendedLifetime(subscription) {}
    }

    @MainActor
    func testPublisherCallbackQueuesUntilPublicationFinishes() {
        let store = FormulaStore(formula: Counter())
        var values: [Int] = []
        let subscription = store.$renderModel.sink { value in
            values.append(value)
            if value == 1 {
                store.send { $0 += 1 }
                XCTAssertEqual(store.state, 1)
                XCTAssertEqual(values, [0, 1])
            }
        }
        store.send { $0 = 1 }
        XCTAssertEqual(values, [0, 1, 2])
        XCTAssertEqual(store.state, 2)
        XCTAssertEqual(store.renderModel, 2)
        withExtendedLifetime(subscription) {}
    }
}

private struct Counter: Formula {
    func initialState(input: Void) -> Int { 0 }
    func render(input: Void, state: Int, context: FormulaContext<Self>) -> Int { state }
}

private struct IndexedChild: Formula {
    struct State { var count = 0 }
    struct RenderModel: Equatable { let count: Int; let increment: Callback<Void> }
    func initialState(input: Int) -> State { State() }
    func render(input: Int, state: State, context: FormulaContext<Self>) -> RenderModel {
        .init(count: state.count, increment: context.callback { $0.count += 1 })
    }
}

private struct IndexedParent: Formula {
    struct State { var ids = [1] }
    func initialState(input: Void) -> State { State() }
    func render(input: Void, state: State, context: FormulaContext<Self>) -> [IndexedChild.RenderModel] {
        state.ids.map { context.child(IndexedChild(), input: $0, key: $0) }
    }
}
