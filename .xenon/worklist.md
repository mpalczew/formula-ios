# Worklist

## Open

- Require `Formula.Input: Equatable` (Formula Android always compares inputs with `equals()`). `Void` cannot conform, so add an empty stand-in type that `child(_:)` and `FormulaStore(formula:)` default to. Name to pick: `NoInput` (recommended), `Unit`, or `EmptyInput`. Then drop the dynamic `any Equatable` check in `FormulaScope.swift`.
- Phase 2: declared actions replace `context.effect` / `cancelEffect`, as in Formula Android (`docs/actions.md`). Agreed shape: `context.action(key:) { try await … } onEvent: { state, result in … }` with `Result`, `context.stream { AsyncSequence } onEvent:`, `onInit`, `onTerminate`. Started when first declared, kept while declared, cancelled when not declared, restarted when the key changes. Reuse the scope's seen-during-render sweep.
- Phase 3: transitions can queue side effects (`effects.run { … }`) that run after the state change is committed, FIFO. Needed so a child can call a parent callback from its input without re-entering the runtime.
- Phase 4: errors. `render` stays non-throwing (decided). Action errors arrive as `Result`; add `FormulaStore(onError:)`; index and report duplicate callback/child keys instead of `precondition` crashes; add `context.key(_:) { }` scoping.
- Port the matching scenarios from Formula Android's `FormulaRuntimeTest.kt` with each phase.
- Reply to Laimonas on mpalczew/formula-ios#1 once phases 2–4 land, answering his six questions against the new API.
- ironscale Core modules cannot build on Linux (z2) because FormulaCore imports Combine. The Observation migration that fixed it was reverted on 2026-11-04; revisit after the redesign.

## Someday

- none
