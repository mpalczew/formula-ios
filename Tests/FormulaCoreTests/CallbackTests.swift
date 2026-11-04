import XCTest
@testable import FormulaCore

final class CallbackTests: XCTestCase {
    @MainActor
    func testEqualCallbackUsesLatestCapturesWithoutPublishing() {
        let store = FormulaStore(formula: CaptureFormula(), initialState: .init())
        let old = store.renderModel
        var updates = 0
        store.observeRenderChanges { _ in updates += 1 }
        store.send { $0.amount = 9 }
        XCTAssertEqual(old, store.renderModel)
        XCTAssertEqual(updates, 0)
        old.add()
        XCTAssertEqual(store.state.total, 9)
        XCTAssertEqual(updates, 1)
    }

    @MainActor
    func testCallbackIdentityIsDistinctAcrossStores() {
        let first = FormulaStore(formula: CaptureFormula(), initialState: .init())
        let second = FormulaStore(formula: CaptureFormula(), initialState: .init())
        XCTAssertNotEqual(first.renderModel.add, second.renderModel.add)
    }

    @MainActor
    func testKeyedCallbacksSurviveReorderingAndInvalidateRemovedItems() {
        let store = FormulaStore(formula: RowsFormula(), initialState: .init())
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
        var store: FormulaStore<CaptureFormula>? = .init(formula: CaptureFormula(), initialState: .init())
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
    func render(state: State, context: FormulaContext<State>) -> RenderModel {
        .init(total: state.total, add: context.callback { $0.total += state.amount })
    }
}

private struct RowsFormula: Formula {
    struct State { var ids = [1, 2]; var selection: String? }
    func render(state: State, context: FormulaContext<State>) -> [Callback<String>] {
        state.ids.map { id in
            context.callback(key: id) { state, value in state.selection = "\(id):\(value)" }
        }
    }
}
