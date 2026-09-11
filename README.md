# Swift Formula

Swift Formula is a composable, callback-driven state runtime for SwiftUI. It is inspired by Instacart's Formula for Android and Laimonas Turauskas's LCE types.

The core loop is:

```text
input callback → state transition → render model → SwiftUI
```

State is the source of truth. Render models are derived from state. Effects are started by a formula context and complete by applying another state transition. Child formulas are scoped to a writable slice of parent state, so their callbacks do not require parent action enums or callback forwarding.

## Example

```swift
struct Counter: Formula {
    struct State { var count = 0 }
    struct RenderModel {
        let count: Int
        let increment: () -> Void
    }

    func render(state: State, context: FormulaContext<State>) -> RenderModel {
        RenderModel(
            count: state.count,
            increment: context.callback { $0.count += 1 }
        )
    }
}
```

Use `FormulaContext.child(_:state:)` to compose formulas. Use `LCE`, `UCE`, `UCT`, `CE`, `CT`, `LC`, or `UC` for loading/content/error values. Keep network clients outside formulas and inject them through the formula's dependencies.

The full usage guide is in [Documentation/Guide.md](Documentation/Guide.md). The sample iOS app has Home and Settings screens, a shared header component used by both, nested child state, callbacks, and an LCE-driven content section.

`FormulaNetworking` provides the single mockable URLSession boundary for request execution and decoding.

## Build and test

```sh
swift test
swift run FormulaSample
```

The sample contains multiple composed screens and a reusable component shared by the screens.
