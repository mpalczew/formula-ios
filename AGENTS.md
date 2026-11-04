# AGENTS.md

swift-formula is its own project with its own rules.

- It keeps its tests. `bin/check` runs `swift build` and `swift test` as the `swift` gate.
- All tests run on a Mac. Off macOS, `bin/check` ships the checked tree to `CHECK_MAC_HOST`
  (default `air`, Xcode, key login over ssh) and runs the gate there. It is never skipped, and
  an unreachable Mac fails the check.
- These tests are not gates for ironscale or any other consumer of this package.
