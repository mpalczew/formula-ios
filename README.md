# Swift Formula

Swift Formula is a composable, callback-driven state runtime for SwiftUI. It is inspired by Instacart's Formula for Android and Laimonas Turauskas's LCE types.

The core loop is:

```text
input callback → state transition → render model → SwiftUI
```

State is the source of truth. Render models are derived from state. Effects are started by a formula context and complete by applying another state transition. Each formula takes an input from its parent and owns its own state, so child callbacks do not require parent action enums or callback forwarding. Callbacks keep a stable, equatable identity while their implementation is refreshed. The store publishes only changed render models; Combine remains the observation layer.

## Example

```swift
struct Counter: Formula {
    struct State { var count = 0 }
    struct RenderModel: Equatable {
        let count: Int
        let increment: Callback<Void>
    }

    func initialState(input: Void) -> State { State() }

    func render(input: Void, state: State, context: FormulaContext<Self>) -> RenderModel {
        RenderModel(
            count: state.count,
            increment: context.callback { $0.count += 1 }
        )
    }
}
```

Use `FormulaContext.child(_:input:key:)` to compose formulas. A child keeps its state while it stays declared; one omitted from an evaluation loses its state, callbacks, and effects. Children whose input and state are unchanged are not rendered again. Use keyed effects to replace obsolete requests and `FormulaContent` for child view equality boundaries. Use `LCE`, `UCE`, `UCT`, `CE`, `CT`, `LC`, or `UC` for loading/content/error values. Keep network clients outside formulas and inject them through the formula's dependencies.

The full usage guide is in [Documentation/Guide.md](Documentation/Guide.md). The sample iOS app has Home and Settings screens, a shared header component used by both, nested child state, callbacks, and an LCE-driven content section.

`FormulaNetworking` provides the single mockable URLSession boundary for request execution and decoding.

## Build and test

```sh
swift test
swift run FormulaSample
```

The sample contains multiple composed screens and a reusable component shared by the screens.
