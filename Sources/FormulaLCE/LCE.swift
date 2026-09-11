public enum LCE<Loading, Content, Failure> {
    case loading(Loading)
    case content(Content)
    case error(Failure)

    public func mapContent<NewContent>(_ transform: (Content) -> NewContent) -> LCE<Loading, NewContent, Failure> {
        switch self {
        case .loading(let value): return .loading(value)
        case .content(let value): return .content(transform(value))
        case .error(let value): return .error(value)
        }
    }

    public func mapError<NewFailure>(_ transform: (Failure) -> NewFailure) -> LCE<Loading, Content, NewFailure> {
        switch self {
        case .loading(let value): return .loading(value)
        case .content(let value): return .content(value)
        case .error(let value): return .error(transform(value))
        }
    }
}

extension LCE: Equatable where Loading: Equatable, Content: Equatable, Failure: Equatable {}

public typealias UCE<Content, Failure> = LCE<Void, Content, Failure>
public typealias UCT<Content> = LCE<Void, Content, any Error>
public typealias CE<Content, Failure> = LCE<Never, Content, Failure>
public typealias CT<Content> = LCE<Never, Content, any Error>
public typealias LC<Loading, Content> = LCE<Loading, Content, Never>
public typealias UC<Content> = LCE<Void, Content, Never>

public extension LCE where Loading == Void {
    static func loading() -> Self { .loading(()) }
}
