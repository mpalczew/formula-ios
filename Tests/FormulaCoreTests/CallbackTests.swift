import Combine
import XCTest
@testable import FormulaCore

final class CallbackTests: XCTestCase {
    @MainActor
    func testEqualCallbackUsesLatestCapturesWithoutPublishing() {
        let store = FormulaStore(formula: CaptureFormula())
        let old = store.renderModel
        var updates = 0
        let subscription = store.objectWillChange.sink { updates += 1 }
        store.send { $0.amount = 9 }
        XCTAssertEqual(old, store.renderModel)
        XCTAssertEqual(updates, 0)
        old.add()
        XCTAssertEqual(store.state.total, 9)
        XCTAssertEqual(updates, 1)
        withExtendedLifetime(subscription) {}
    }

    @MainActor
    func testCallbackIdentityIsDistinctAcrossStores() {
        let first = FormulaStore(formula: CaptureFormula())
        let second = FormulaStore(formula: CaptureFormula())
        XCTAssertNotEqual(first.renderModel.add, second.renderModel.add)
    }

    @MainActor
    func testKeyedCallbacksSurviveReorderingAndInvalidateRemovedItems() {
        let store = FormulaStore(formula: RowsFormula())
        let original = store.renderModel
        store.send { $0.ids.reverse() }
        XCTAssertEqual(original[0], store.renderModel[1])
        XCTAssertEqual(original[1], store.renderModel[0])
        store.send { $0.ids.removeAll { $0 == 1 } }
        original[0]("gone")
        XCTAssertNil(store.state.selection)
        original[1]("current")
        XCTAssertEqual(store.state.selection, "2:current")
        store.send { $0.ids.append(1) }
        XCTAssertNotEqual(original[0], store.renderModel[1])
    }

    @MainActor
    func testCallbackDoesNotRetainStore() {
        var store: FormulaStore<CaptureFormula>? = .init(formula: CaptureFormula())
        let reference = WeakReference(store)
        let callback = store!.renderModel.add
        store = nil
        XCTAssertNil(reference.value)
        callback()
    }
}

private struct CaptureFormula: Formula {
    struct State { var amount = 1; var total = 0 }
    struct RenderModel: Equatable { let total: Int; let add: Callback<Void> }
    func initialState(input: Void) -> State { State() }
    func render(input: Void, state: State, context: FormulaContext<Self>) -> RenderModel {
        .init(total: state.total, add: context.callback { $0.total += state.amount })
    }
}

private struct RowsFormula: Formula {
    struct State { var ids = [1, 2]; var selection: String? }
    func initialState(input: Void) -> State { State() }
    func render(input: Void, state: State, context: FormulaContext<Self>) -> [Callback<String>] {
        state.ids.map { id in
            context.callback(key: id) { state, value in state.selection = "\(id):\(value)" }
        }
    }
}
