import XCTest
@testable import FormulaCore

final class EffectTests: XCTestCase {
    @MainActor
    func testCancellationBeforeStartDoesNotInvokeOperation() async {
        let probe = OperationProbe()
        let store = FormulaStore(formula: ImmediateFormula(probe: probe), initialState: 0)
        store.renderModel()
        store.cancelEffects()
        await store.waitForEffects()
        XCTAssertEqual(probe.calls, 0)
        XCTAssertEqual(store.state, 0)
    }

    @MainActor
    func testSuccessfulEffectPublishesAndCleansUp() async {
        let request = ControlledValue<Int>()
        let store = FormulaStore(formula: LoadingFormula(requests: [request]), initialState: .init())
        store.renderModel.load(0)
        await request.waitUntilStarted()
        XCTAssertEqual(store.activeEffectCount, 1)
        request.complete(7)
        await store.waitForEffects()
        XCTAssertEqual(store.state.value, 7)
        XCTAssertEqual(store.renderModel.value, 7)
        XCTAssertEqual(store.activeEffectCount, 0)
    }

    @MainActor
    func testReplacementRejectsOldResultEvenWhenOperationIgnoresCancellation() async {
        let old = ControlledValue<Int>()
        let new = ControlledValue<Int>()
        let store = FormulaStore(formula: LoadingFormula(requests: [old, new]), initialState: .init())
        store.renderModel.load(0)
        await old.waitUntilStarted()
        store.renderModel.load(1)
        await new.waitUntilStarted()
        XCTAssertEqual(store.activeEffectCount, 1)
        new.complete(20)
        old.complete(10)
        await store.waitForEffects()
        XCTAssertEqual(store.state.value, 20)
        XCTAssertEqual(store.activeEffectCount, 0)
    }

    @MainActor
    func testUnkeyedEffectsCanRunConcurrently() async {
        let first = ControlledValue<Int>()
        let second = ControlledValue<Int>()
        let formula = LoadingFormula(requests: [first, second], replace: false)
        let store = FormulaStore(formula: formula, initialState: .init())
        store.renderModel.load(0)
        store.renderModel.load(1)
        await first.waitUntilStarted()
        await second.waitUntilStarted()
        XCTAssertEqual(store.activeEffectCount, 2)
        store.cancelEffects()
        XCTAssertEqual(store.activeEffectCount, 0)
        first.complete(1)
        second.complete(2)
        await store.waitForEffects()
        XCTAssertEqual(store.state.value, 0)
    }

    @MainActor
    func testCancelingOneChildDoesNotCancelItsSibling() async {
        let first = ControlledValue<Int>()
        let second = ControlledValue<Int>()
        let store = FormulaStore(formula: LoadingParent(first: first, second: second), initialState: .init())
        store.renderModel.first!.load(0)
        store.renderModel.second.load(0)
        await first.waitUntilStarted()
        await second.waitUntilStarted()
        store.renderModel.first!.cancel()
        first.complete(10)
        second.complete(20)
        await store.waitForEffects()
        XCTAssertEqual(store.state.first.value, 0)
        XCTAssertEqual(store.state.second.value, 20)
    }

    @MainActor
    func testRemovedChildRejectsOldCallbacksAndEffectsAfterReappearing() async {
        let first = ControlledValue<Int>()
        let second = ControlledValue<Int>()
        let store = FormulaStore(formula: LoadingParent(first: first, second: second), initialState: .init())
        let old = store.renderModel.first!
        old.load(0)
        await first.waitUntilStarted()
        store.send { $0.showFirst = false }
        store.send { $0.showFirst = true }
        XCTAssertNotEqual(old.load, store.renderModel.first!.load)
        old.load(0)
        XCTAssertEqual(store.activeEffectCount, 0)
        first.complete(99)
        await store.waitForEffects()
        XCTAssertEqual(store.state.first.value, 0)
    }

    @MainActor
    func testChangingChildKeyInvalidatesOldLifetime() async {
        let first = ControlledValue<Int>()
        let second = ControlledValue<Int>()
        let store = FormulaStore(formula: LoadingParent(first: first, second: second), initialState: .init())
        let old = store.renderModel.first!
        old.load(0)
        await first.waitUntilStarted()
        store.send { $0.identity += 1 }
        XCTAssertNotEqual(old.load, store.renderModel.first!.load)
        first.complete(99)
        await store.waitForEffects()
        XCTAssertEqual(store.state.first.value, 0)
    }

    @MainActor
    func testRunningEffectDoesNotRetainStore() async {
        let request = ControlledValue<Int>()
        var store: FormulaStore<LoadingFormula>? = .init(
            formula: LoadingFormula(requests: [request]), initialState: .init())
        let reference = WeakReference(store)
        store!.renderModel.load(0)
        await request.waitUntilStarted()
        store = nil
        XCTAssertNil(reference.value)
        request.complete(1)
        await request.waitUntilReturned()
        XCTAssertTrue(request.wasCancelled)
    }

    @MainActor
    func testRootCancellationReachesAllChildren() async {
        let first = ControlledValue<Int>()
        let second = ControlledValue<Int>()
        let store = FormulaStore(formula: LoadingParent(first: first, second: second), initialState: .init())
        store.renderModel.first!.load(0)
        store.renderModel.second.load(0)
        await first.waitUntilStarted()
        await second.waitUntilStarted()
        store.cancelEffects()
        store.cancelEffects()
        first.complete(10)
        second.complete(20)
        await store.waitForEffects()
        XCTAssertEqual(store.state.first.value, 0)
        XCTAssertEqual(store.state.second.value, 0)
        XCTAssertTrue(first.wasCancelled)
        XCTAssertTrue(second.wasCancelled)
    }

    @MainActor
    func testFailureBecomesVisibleStateAndCleansUp() async {
        let response = ControlledValue<Result<Int, RequestFailure>>()
        let store = FormulaStore(formula: FailureFormula(response: response), initialState: "idle")
        store.renderModel.load()
        await response.waitUntilStarted()
        response.complete(.failure(.offline))
        await store.waitForEffects()
        XCTAssertEqual(store.renderModel.message, "offline")
        XCTAssertEqual(store.activeEffectCount, 0)
    }
}

private enum RequestFailure: Error { case offline }

@MainActor
private final class OperationProbe { var calls = 0 }

private struct ImmediateFormula: Formula {
    let probe: OperationProbe
    func render(state: Int, context: FormulaContext<Int>) -> Callback<Void> {
        context.callback { _ in
            context.effect {
                probe.calls += 1
                return { $0 += 1 }
            }
        }
    }
}

@MainActor
private struct FailureFormula: Formula {
    let response: ControlledValue<Result<Int, RequestFailure>>
    struct RenderModel: Equatable { let message: String; let load: Callback<Void> }
    func render(state: String, context: FormulaContext<String>) -> RenderModel {
        .init(message: state, load: context.callback { _ in
            context.effect {
                do {
                    let value = try await response.value().get()
                    return { $0 = "\(value)" }
                } catch {
                    return { $0 = "offline" }
                }
            }
        })
    }
}
