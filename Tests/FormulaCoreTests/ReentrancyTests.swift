import XCTest
@testable import FormulaCore

final class ReentrancyTests: XCTestCase {
    @MainActor
    func testQueuedCallbackDoesNotAccessRemovedChildState() {
        let store = FormulaStore(formula: IndexedParent(), initialState: .init())
        let increment = store.renderModel[0]
        store.send { state in
            state.children.removeAll()
            increment()
        }
        XCTAssertTrue(store.state.children.isEmpty)
        XCTAssertTrue(store.renderModel.isEmpty)
    }

    @MainActor
    func testQueuedCallbackDoesNotMutateReplacementAtSameIndex() {
        let store = FormulaStore(formula: IndexedParent(), initialState: .init())
        let increment = store.renderModel[0]
        store.send { state in
            state.children = [.init(id: 2, count: 10)]
            increment()
        }
        XCTAssertEqual(store.state.children[0].count, 10)
        XCTAssertNotEqual(increment, store.renderModel[0])
        store.renderModel[0]()
        XCTAssertEqual(store.state.children[0].count, 11)
    }

    @MainActor
    func testNestedSendsPublishInOrder() {
        let store = FormulaStore(formula: Counter(), initialState: 0)
        var values: [Int] = [store.renderModel]
        store.observeRenderChanges { values.append($0) }
        store.send { state in
            state = 1
            store.send { $0 += 1 }
        }
        XCTAssertEqual(values, [0, 1, 2])
        XCTAssertEqual(store.state, 2)
    }

    @MainActor
    func testPublisherCallbackQueuesUntilPublicationFinishes() {
        let store = FormulaStore(formula: Counter(), initialState: 0)
        var values: [Int] = [store.renderModel]
        store.observeRenderChanges { value in
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
    }
}

private struct Counter: Formula {
    func render(state: Int, context: FormulaContext<Int>) -> Int { state }
}

private struct IndexedChild: Formula {
    struct State { let id: Int; var count = 0 }
    func render(state: State, context: FormulaContext<State>) -> Callback<Void> {
        context.callback { $0.count += 1 }
    }
}

private struct IndexedParent: Formula {
    struct State { var children = [IndexedChild.State(id: 1)] }
    func render(state: State, context: FormulaContext<State>) -> [Callback<Void>] {
        state.children.indices.map { index in
            context.child(IndexedChild(), state: \State.children[index], key: state.children[index].id)
        }
    }
}
