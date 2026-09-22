/// A stable event endpoint. Equality compares its scoped identity, not its captures.
public struct Callback<Input>: Equatable {
    private let storage: CallbackStorage<Input>

    init(storage: CallbackStorage<Input>) { self.storage = storage }

    @MainActor
    public func callAsFunction(_ input: Input) { storage.invoke?(input) }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.storage === rhs.storage
    }
}

public extension Callback where Input == Void {
    @MainActor
    func callAsFunction() { self(()) }
}

@MainActor
protocol StoredCallback: AnyObject {
    func invalidate()
}

@MainActor
final class CallbackStorage<Input>: StoredCallback {
    var invoke: ((Input) -> Void)?
    func invalidate() { invoke = nil }
}

struct CallbackKey: Hashable {
    let file: String
    let line: UInt
    let column: UInt
    let key: AnyHashable?
}
