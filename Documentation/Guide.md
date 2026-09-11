# Swift Formula guide

Swift Formula is a small state runtime for SwiftUI. It takes the useful ideas from Instacart's Formula—immutable state, render models, callbacks, effects, and child formulas—and expresses them with Swift value types, actors, and structured concurrency.

## The mental model

```text
callback → state transition → render model → SwiftUI
                         ↘ effect → state transition
```

The Formula owns the state. The render model is derived from the current state. Views render the model and invoke its callbacks. A callback never mutates a view directly.

## A formula

```swift
struct Counter: Formula {
    struct State { var count = 0 }

    struct RenderModel {
        let count: Int
        let increment: () -> Void
    }

    @MainActor
    func render(
        state: State,
        context: FormulaContext<State>
    ) -> RenderModel {
        RenderModel(
            count: state.count,
            increment: context.callback { state in
                state.count += 1
            }
        )
    }
}
```

The formula does not expose a mutable state object. The runtime applies the callback mutation, stores the new value, and evaluates the formula again.

## Callbacks

Use `context.callback` for every UI input: taps, text changes, toggles, selection, and dismissal. This replaces a screen-wide action enum and avoids forwarding every child event through the parent.

```swift
TextField(
    "Name",
    text: Binding(
        get: { model.name },
        set: { model.nameChanged($0) }
    )
)
```

Callbacks are main-actor isolated. A callback created by a child remains scoped to that child state.

## Composition

Keep a formula small by giving it child formulas:

```swift
struct Screen: Formula {
    struct State {
        var header = Header.State(title: "Products")
        var list = ProductList.State()
    }

    struct RenderModel {
        let header: Header.RenderModel
        let list: ProductList.RenderModel
    }

    @MainActor
    func render(state: State, context: FormulaContext<State>) -> RenderModel {
        RenderModel(
            header: context.child(Header(), state: \.header),
            list: context.child(ProductList(), state: \.list)
        )
    }
}
```

`context.child` scopes the child formula to a writable key path. The child owns its callbacks and effects. The parent only owns the composition and any genuinely cross-child coordination.

## Effects and networking

Keep URL construction, authentication, decoding, and transport errors in clients. `FormulaNetworking.HTTPClient` is the single transport boundary. It wraps URLSession in production and accepts a closure in tests. Feature clients build domain requests on top of it. A formula receives a feature client as a dependency and turns its result into a state mutation:

```swift
struct ProductClient {
    var fetch: () async throws -> [Product]
}

let http = HTTPClient.live

// Inside a callback:
context.effect { [client] in
    do {
        let products = try await client.fetch()
        return { state in state.products = .content(products) }
    } catch {
        return { state in state.products = .error(error) }
    }
}
```

Effects must complete by applying a state mutation. They must not update views, reach into another formula, or bypass the runtime.

## LCE

`FormulaLCE` contains the full family of Laimonas Turauskas's loading/content/error types:

```swift
LCE<Loading, Content, Failure>
UCE<Content, Failure>
UCT<Content>
CE<Content, Failure>
CT<Content>
LC<Loading, Content>
UC<Content>
```

Use `UCT<Value>` for the common network case. Use the loading associated value when the UI needs progress information. For refresh, make stale content explicit in the content value instead of adding a second boolean to the screen state.

Formula intentionally does not add an `idle` case to LCE. A request that has not started can be represented by an optional LCE in the feature state.

## Testing

Test formulas without rendering SwiftUI:

```swift
@MainActor
func testIncrement() {
    let store = FormulaStore(formula: Counter(), initialState: .init())
    store.renderModel.increment()
    XCTAssertEqual(store.state.count, 1)
}
```

Test child callbacks through the parent store to prove that composition preserves state ownership. Test clients separately with deterministic fakes.

## Rules

- State is the only source of truth.
- Render models contain data and callbacks, never hidden business logic.
- Every input enters through a callback.
- Only FormulaContext may transition state.
- Effects communicate through state mutations.
- Network code lives in clients, not views or renderers.
- Split a formula when it has an independent state machine, effect set, or reusable UI.
- Compose children instead of growing parent action enums.
