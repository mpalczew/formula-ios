# Building

z2 (Linux) has no Swift, and `@MainActor` XCTest methods abort on Linux, so build and test on the Mac `air`:

```
rsync -a --delete --exclude .build --exclude .git ./ air:Library/Caches/swift-formula-dev/
ssh air 'export PATH=/opt/homebrew/bin:$PATH LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8; cd Library/Caches/swift-formula-dev && swift build && swift test'
```

Don't use `air:~/src/swift-formula`; it has no push key. The pre-commit hook (`bin/check --staged`) runs `swift build` locally, so on z2 it fails for any change under `Package.swift`, `Sources` or `Tests`.
