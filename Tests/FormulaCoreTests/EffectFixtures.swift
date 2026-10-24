import FormulaCore

@MainActor
final class ControlledValue<Value: Sendable> {
    private var continuation: CheckedContinuation<Value, Never>?
    private var started: CheckedContinuation<Void, Never>?
    private var returned: CheckedContinuation<Void, Never>?
    private var didReturn = false
    private(set) var wasCancelled = false

    func value() async -> Value {
        let value: Value = await withCheckedContinuation { continuation in
            self.continuation = continuation
            started?.resume()
            started = nil
        }
        wasCancelled = Task.isCancelled
        didReturn = true
        returned?.resume()
        returned = nil
        return value
    }

    func waitUntilStarted() async {
        if continuation != nil { return }
        await withCheckedContinuation { started = $0 }
    }

    func complete(_ value: Value) {
        precondition(continuation != nil)
        continuation?.resume(returning: value)
        continuation = nil
    }

    func waitUntilReturned() async {
        if didReturn { return }
        await withCheckedContinuation { returned = $0 }
    }
}

@MainActor
struct LoadingFormula: Formula {
    let requests: [ControlledValue<Int>]
    var replace = true
    struct State { var value = 0 }
    struct RenderModel: Equatable {
        let value: Int
        let load: Callback<Int>
        let cancel: Callback<Void>
    }

    func render(state: State, context: FormulaContext<State>) -> RenderModel {
        .init(value: state.value, load: context.callback { _, index in
            context.effect(key: replace ? "load" : nil) {
                let value = await requests[index].value()
                return { $0.value = value }
            }
        }, cancel: context.callback { _ in context.cancelEffect(key: "load") })
    }
}

@MainActor
struct LoadingParent: Formula {
    let first: ControlledValue<Int>
    let second: ControlledValue<Int>
    struct State {
        var first = LoadingFormula.State()
        var second = LoadingFormula.State()
        var showFirst = true
        var identity = 0
    }
    struct RenderModel: Equatable {
        let first: LoadingFormula.RenderModel?
        let second: LoadingFormula.RenderModel
    }
    func render(state: State, context: FormulaContext<State>) -> RenderModel {
        .init(
            first: state.showFirst
                ? context.child(LoadingFormula(requests: [first]), state: \.first, key: state.identity)
                : nil,
            second: context.child(LoadingFormula(requests: [second]), state: \.second)
        )
    }
}

@MainActor
final class WeakReference<Value: AnyObject> {
    weak var value: Value?
    init(_ value: Value?) { self.value = value }
}
