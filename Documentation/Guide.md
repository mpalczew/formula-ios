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

    struct RenderModel: Equatable {
        let count: Int
        let increment: Callback<Void>
    }

    func initialState(input: Void) -> State { State() }

    @MainActor
    func render(
        input: Void,
        state: State,
        context: FormulaContext<Self>
    ) -> RenderModel {
        RenderModel(
            count: state.count,
            increment: context.callback { state in
                state.count += 1
            }
        )
    }
}

let store = FormulaStore(formula: Counter())
```

A formula declares an `Input`, a `State`, and an equatable `RenderModel`. The input
comes from the parent (or from `FormulaStore(formula:input:)` at the root) and is
passed to `initialState(input:)` and `render`. The formula does not expose a mutable
state object. The runtime applies the callback mutation, stores the new value, and
evaluates the formula again.

## Input

```swift
struct Greeting: Formula {
    struct State { var title: String }

    func initialState(input: String) -> State { State(title: input) }

    func onInputChanged(old: String, new: String, state: inout State) {
        state.title = new
    }

    func render(input: String, state: State, context: FormulaContext<Self>) -> String {
        state.title
    }
}

store.update(input: "Grace")
```

When the input changes, the runtime calls `onInputChanged` before rendering; the
default does nothing. Inputs are compared when they are `Equatable`; `Void` is always
equal; any other input counts as changed on every parent render. At the root,
`store.update(input:)` does nothing when the input is equal. Use `StatelessFormula`
for a formula with no state: implement `render(input:context:)` and declare `Input`
and `RenderModel`.

## Callbacks and equality

Every render model conforms to `Equatable`. Use `Callback<Void>` for taps and
`Callback<Value>` for inputs such as text or selection; invoke them like functions.

```swift
struct RenderModel: Equatable {
    let name: String
    let nameChanged: Callback<String>
}

// During render:
RenderModel(name: state.name, nameChanged: context.callback { state, name in
    state.name = name
})

// In the view:
TextField("Name", text: Binding(
    get: { model.name }, set: { model.nameChanged($0) }
))
Button("Increment") { model.increment() }
```

Identity combines the owning scope, source file, line, column, and optional key.
Each evaluation refreshes the implementation behind that identity. An old model
therefore invokes the latest callback, including current captured values, even
when the model compared equal and was not republished. This is endpoint identity,
not mathematical equality of closures. Callbacks are main-actor isolated.

Supply stable item keys when declaring callbacks repeatedly at the same location:

```swift
state.items.map { item in
    context.callback(key: item.id) { state in state.selectedID = item.id }
}
```

Reordering preserves identity; removing and reinserting creates a new identity.
Duplicate identities within an evaluation are a programming error. Reusable
callback factory functions must forward source-location arguments or accept keys.
Declare callbacks and children only during `render`. Declare effects inside
callbacks. `render` must not transition state or perform external work.

The store still evaluates a new render model after each transition. It publishes
`renderModel` (and `objectWillChange`) only when the model differs. `state` remains
readable but does not independently publish UI changes. Consumers should observe
`$renderModel`, not `$state`. No-op and invisible state changes do not redraw views.

`FormulaView` applies an equality boundary to its content. Use
`FormulaContent(model: model.child) { child in ChildView(model: child) }.equatable()`
or an equatable child view to skip unchanged child content when a sibling changes.
All values controlling that content must be in its model, not hidden closure
captures. SwiftUI environment changes and local view state retain normal behavior;
Formula does not promise to suppress those updates or skip formula evaluation.

## Composition

Keep a formula small by giving it child formulas. Each child owns its state:

```swift
struct Screen: Formula {
    struct State { var query = "" }

    struct RenderModel: Equatable {
        let header: Header.RenderModel
        let list: ProductList.RenderModel
    }

    func initialState(input: Void) -> State { State() }

    @MainActor
    func render(input: Void, state: State, context: FormulaContext<Self>) -> RenderModel {
        RenderModel(
            header: context.child(Header(), input: "Products"),
            list: context.child(ProductList(), input: state.query)
        )
    }
}
```

A child's identity is its formula type plus an optional `key:`. It starts from
`initialState(input:)` the first time a render declares it and keeps that state while
it stays declared. Omit a child from a render to end its lifetime: its state is
dropped, its callbacks become inert, and its effects are canceled. Declaring it again
starts fresh. Use `key:` to run several instances of one formula type. Declaring the
same type and key twice in one render is a programming error.

A child talks back to its parent through callbacks in its input. `Callback` is
equatable by identity, so such an input stays equal between renders.

When a parent re-renders, a child is not rendered again if its input is equal and
neither it nor any descendant had a transition since its last render. The parent
receives the child's previous render model. Its callbacks and descendants stay alive.
A transition in a child or grandchild re-renders its ancestors up to the root, but not
unchanged siblings. Because a skipped child does not run `render`, anything that
affects its model must be part of its input or state, not captured from the formula
value or the environment.

## Effects and networking

Keep URL construction, authentication, decoding, and transport errors in clients. `FormulaNetworking.HTTPClient` is the single transport boundary. It wraps URLSession in production and accepts a closure in tests. Feature clients build domain requests on top of it. A formula receives a feature client as a dependency and turns its result into a state mutation:

```swift
struct ProductClient {
    var fetch: () async throws -> [Product]
}

let http = HTTPClient.live

// Inside a callback:
context.effect(key: "load-products") { [client] in
    do {
        let products = try await client.fetch()
        return { state in state.products = .content(products) }
    } catch {
        return { state in state.products = .error(error) }
    }
}
```

Effects must complete by applying a state mutation. They must not update views,
reach into another formula, or bypass the runtime. Catch errors in the operation
and return an explicit error-state mutation.

An effect key replaces the previous effect with that key within the same child
scope. An effect mutates the state of the formula that declared it. Unkeyed effects run independently. `context.cancelEffect(key:)` cancels a
specific request; `context.cancelEffects()` includes descendants.
`store.cancelEffects()` cancels the entire tree. Cancellation is cooperative for
the operation itself, but the runtime rejects its result even if it ignores
cancellation. Removed or replaced child lifetimes cannot receive late results.
Completed task handles are removed, and releasing the store cancels outstanding
tasks. Cancellation cannot undo external work already performed by a client.

Inject clocks, delays, IDs, storage, analytics, and network behavior through feature
clients or closures. Formula has no implicit timer; advancing a fake clock belongs
to the injected client, not to the state runtime.

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
    let store = FormulaStore(formula: Counter())
    store.renderModel.increment()
    XCTAssertEqual(store.state.count, 1)
}
```

For async tests, use a controllable client that signals when a request starts and
suspends until the test supplies a result. Call `await store.waitForEffects()` after
releasing it to await applied results and cleanup. This also waits for canceled
operations to return, so release deliberately uncooperative test fakes too. Do not
call it from one of the store's own effects, which would wait for itself.
`activeEffectCount` excludes canceled work even when that work has not yet returned.
See `Tests/FormulaCoreTests/EffectFixtures.swift` and `EffectTests.swift` for complete
examples without sleeps or scheduler guesses.

Observe child state through render models; the store only exposes the root state. Test child callbacks through the parent store to prove scope ownership. Test clients
separately with deterministic fakes. Assert hidden-state changes do not publish,
old callbacks use fresh captures, sibling identities stay distinct, obsolete results
are rejected, and child removal invalidates old callbacks.

## Migrating existing formulas

- Replace closure fields with `Callback<Void>` or `Callback<Input>`.
- Add `Equatable` to render models and their nested display values.
- Use `Button("Title") { model.callback() }` instead of passing the callback as a closure.
- Move observation from `$state` to `$renderModel`.
- Give repeated callback declarations stable keys and requests replacement keys.
- Derive equatable display values from non-equatable domain state. For example,
  `UCT` carries `Void` and `any Error`; the sample maps it to a display enum.
  Do not claim arbitrary errors are equal merely to enable synthesis.
- Parent-owned child state (`state: \.child` key paths) is gone. Move the child's state
  into the child, pass what it needs as `input:`, and pass callbacks for events.
- Formula contexts are supplied by the runtime; test through `FormulaStore` rather
  than constructing an unscoped context.

## Rules

- State is the only source of truth.
- Render models contain data and callbacks, never hidden business logic.
- Every input enters through a callback.
- Only FormulaContext may transition state.
- Effects communicate through state mutations.
- Network code lives in clients, not views or renderers.
- Split a formula when it has an independent state machine, effect set, or reusable UI.
- Compose children instead of growing parent action enums.
- Pass data down as input and events up as callbacks in the input.
