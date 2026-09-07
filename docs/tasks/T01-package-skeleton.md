# T01 · Package skeleton and a green `swift test`

**Depends on:** nothing · **Milestone:** M1

## Goal

A Swift package that builds and runs tests, so every later task has somewhere to put a
failing test. Nothing else.

## Read first

- [TDD.md](../TDD.md)

## Build

`Package.swift` at the repo root:

- swift-tools-version 6.0, platform `.macOS(.v14)`
- Library target `MRRClockCore` — no dependencies
- Test target `MRRClockCoreTests` depending on `MRRClockCore`
- Empty directories: `Sources/MRRClockCore/`, `Tests/MRRClockCoreTests/Support/`,
  `Tests/MRRClockCoreTests/Fixtures/`

Swift Testing ships with the toolchain — no package dependency, just `import Testing`.

Add `.gitignore`: `.build/`, `.swiftpm/`, `*.xcuserdatadata`, `DerivedData/`, `.DS_Store`.

## Tests

The thing being verified here is the wiring — that the toolchain, the test target, and the
`@testable` import actually work before fourteen tasks are stacked on top.

1. **`the test target can import the core module`** — a test file containing
   `@testable import MRRClockCore` compiles and runs. Assert on a public
   `MRRClockCore.metricsSpecVersion = 1` constant added for the purpose (it earns its keep
   later: bump it when METRICS.md changes in a way that invalidates a cached snapshot).

## Done when

- `swift build` succeeds with no warnings
- `swift test` runs and reports 1 test passed
- The command output is pasted into the commit body

## Out of scope

Xcode project, app target, any domain type. Resist writing `Money` here.
