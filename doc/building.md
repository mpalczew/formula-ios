# Building

z2 (Linux) has no Swift, and `@MainActor` XCTest methods abort on Linux, so Swift builds and tests run on the Mac `air`. `bin/air-test` copies the tree to `air:Library/Caches/swift-formula-dev` and runs `swift build` and `swift test` there; extra arguments go to `swift test`. Off macOS, `bin/check`'s swift gate (and so the pre-commit hook) runs `bin/air-test` on the staged snapshot. An unreachable air fails the gate.

Don't use `air:~/src/swift-formula`; it has no push key.
