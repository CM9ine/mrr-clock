# How we work — TDD rules

These rules apply to every task. A task file lists *what* to build and *which tests must
exist*; this file is *how*.

## The loop

1. **Red.** Write one test from the task's test list. Run it. **Watch it fail.**
   A test that has never failed has proven nothing.
2. **Green.** Write the least code that makes it pass. Hardcoding is allowed here.
3. **Refactor.** Clean up with the test still green.
4. Repeat for the next test in the list.
5. When the list is exhausted, run the **whole** suite. Then the task is done.

Never write the implementation first and the tests after. If you find yourself doing it,
delete the implementation and start again — it is faster than debugging code whose tests
were written to agree with it.

## Framework

Swift Testing, not XCTest:

```swift
import Testing
@testable import MRRClockCore

@Test("monthly price of $10 is 1000 cents")
func monthlyPrice() throws {
    let sub = Subscription.stub(items: [.stub(unitAmount: 1000, interval: .month)])
    let result = try MRRCalculator().mrr(subscriptions: [sub], config: .test)
    #expect(result.total == Money(1000, "usd"))
}
```

- `@Test("…")` names read as sentences describing behaviour, not method names.
- `#expect` for assertions that should continue; `#require` when the rest of the test is
  meaningless without it.
- Parameterised cases for tables of inputs — the interval-normalisation table in
  [METRICS.md](METRICS.md#normalising-an-interval-to-one-month) is one `@Test(arguments:)`.

Commands:

```bash
swift test                                  # everything
swift test --filter MRRCalculatorTests      # one suite
swift test --filter "monthly price"         # one test
```

### Supported macOS development setup (T20)

Use the official **Swift.org Swift 6.3.3** toolchain, selected by Swiftly 1.1.2 and
this repository's `.swift-version`. This is distinct from **Apple Swift 6.3.3**
shipped in Command Line Tools 26.6. Keep Command Line Tools installed for the macOS
SDK; no package dependencies or framework flags are needed.

Following the [official Swiftly installation guide](https://www.swift.org/install/macos/swiftly/),
run once:

```bash
xcode-select --install # only if Command Line Tools are not already installed
curl -fL https://download.swift.org/swiftly/darwin/swiftly-1.1.2.pkg -o /tmp/swiftly-1.1.2.pkg
pkgutil --check-signature /tmp/swiftly-1.1.2.pkg
installer -pkg /tmp/swiftly-1.1.2.pkg -target CurrentUserHomeDirectory
~/.swiftly/bin/swiftly init --skip-install --assume-yes
. ~/.swiftly/env.sh
# From the repository root:
swiftly install "$(cat .swift-version)" --assume-yes
swiftly link --assume-yes
hash -r
swift --version # Apple Swift version 6.3.3 (swift-6.3.3-RELEASE)
swift package clean
swift build
swift test
```

Swiftly adds its environment to the shell profile. Open a new login shell and run
`swift test` again. `command -v swift` should resolve to `~/.swiftly/bin/swift`.
For an already-open shell or a non-login automation shell, source
`~/.swiftly/env.sh` once before using Swift. This selects a toolchain; it is not a
shell alias or a test wrapper. `xcrun --find swift` can still point at the Apple
Command Line Tools compiler because xcrun and Swiftly use different selectors.

Verified locally on macOS 26 with Command Line Tools 26.6 / macOS SDK 26.5:
clean build exited 0 without warnings; plain tests and a fresh `/bin/zsh -lc
'swift test'` both passed the full suite (23 tests in 2 suites, including the
existing disabled Money precondition test; 22 enabled test declarations, with
seven cases in the rounding test). No tests or expectations were changed.

The [macOS CI workflow](../.github/workflows/swift.yml) uses `macos-26`, explicitly
selects Command Line Tools for the SDK, installs the same pinned Swift.org release,
and runs plain `swift build` and `swift test` on pushes and pull requests. It logs
the actual compiler version and SDK path so toolchain selection is visible.

[Verified CI run](https://github.com/CM9ine/mrr-clock/actions/runs/34170974375):
`macos-26-arm64`, Swift `6.3.3 (swift-6.3.3-RELEASE)`, clean build exit 0,
`✔ Test run with 23 tests in 2 suites passed after 0.007 seconds.`
The single existing Money skip was preserved.

### Historical Command Line Tools workaround (T01–T03)

T20 reproduced the original failure before changing setup. With developer directory
`/Library/Developer/CommandLineTools`, executable
`/Library/Developer/CommandLineTools/usr/bin/swift`, SDK
`/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk`, and Apple Swift
`6.3.3 (swiftlang-6.3.3.1.3 clang-2100.1.1.101)`, plain `swift test` exited 1:

```text
CountdownTests.swift:2:8: error: no such module 'Testing'
error: fatalError
```

The framework exists. The verbose compiler invocation passes its containing
`Frameworks` directory with `-I` and `-L`, but no `-F`. The corresponding
[SwiftPM 6.3.3 source](https://github.com/swiftlang/swift-package-manager/blob/swift-6.3.3-RELEASE/Sources/PackageModel/UserToolchain.swift)
returns that directory from `deriveSwiftTestingPath`, then checks for a
`.framework` extension when choosing `-F`. The directory has no such extension,
so it takes the module/library branch instead. The Swift.org toolchain uses its
own Testing module/library layout and passes without this workaround.

Sandbox compiler-cache permission failures are separate: the initial sandboxed
command could not write `~/.cache/clang/ModuleCache` and also emitted a secondary
SDK/compiler mismatch diagnostic. With normal cache access, compilation reached
the missing Testing module error above. Allow compiler-cache access when running
in a restricted agent environment; do not change domain tests to address it.


Fallback only for the affected Apple Swift 6.3.3 / Command Line Tools 26.6 installation: plain
`swift test` fails to discover the installed Testing framework. The user approved
the following equivalent full-suite command for T01; it adds compile/link/runtime
search paths and does not skip tests or add package dependencies:

```bash
swift test \
  -Xswiftc -F/Library/Developer/CommandLineTools/Library/Developer/Frameworks \
  -Xlinker -F/Library/Developer/CommandLineTools/Library/Developer/Frameworks \
  -Xlinker -rpath \
  -Xlinker /Library/Developer/CommandLineTools/Library/Developer/Frameworks \
  -Xlinker -rpath \
  -Xlinker /Library/Developer/CommandLineTools/Library/Developer/usr/lib
```

This fallback does not satisfy T20’s plain-command requirement. Prefer the supported
setup above. No system files were changed for this historical workaround.

## Non-negotiables

**No network in tests.** Ever. Not even "just this one integration test". `LiveStripeClient`
is tested through an injected `URLProtocol` stub or a `HTTPTransport` protocol, never
against `api.stripe.com`. A suite that needs the internet is a suite that fails on a plane.

**No `Date()` in tests or application logic.** The sole exception is `SystemClock`,
the production adapter that reads real time. Time arrives as a parameter or through
an injected `Clock`. Test `FixedClock` with an explicit instant; do not compare live time
against a wall-clock deadline. Every date-dependent test pins an explicit instant:

```swift
let now = Date(iso: "2026-09-07T09:00:00Z")
```

**No sleeping.** Nothing in the suite waits on a wall clock. Timers are tested by
advancing a fake clock, not by waiting 15 minutes.

**No secrets.** No real key in a test, a fixture, or a commit — not even a revoked one.
Fixtures are redacted by hand (see [STRIPE.md](STRIPE.md#fixtures)).

**Determinism.** Same input, same output, every run, in any order, on any machine, in any
time zone. If a test is flaky it is broken; fix it or delete it, never retry it.

## What a good test looks like here

- **One behaviour per test.** If the name needs "and", it is two tests.
- **Exact expected values, written by hand.** `#expect(mrr == Money(3042, "usd"))`, never
  `#expect(mrr == calculator.compute(...))`. A test that recomputes the implementation
  proves only that the code equals itself.
- **The numbers come from [METRICS.md](METRICS.md).** When a task's test list gives an
  expected value, it was derived from the spec by hand. Do not "fix" a failing test by
  changing the expectation to whatever the code printed — that is how a money bug ships.
- **Test the edges the task names**: zero, empty, negative, wrong currency, missing field,
  past date, huge number, one-off coupon.

## Test data

Every DTO gets a `.stub(...)` factory in the test target with sensible defaults, so a test
mentions only the fields it cares about:

```swift
extension Subscription {
    static func stub(
        id: String = "sub_1",
        status: String = "active",
        items: [SubscriptionItem] = [.stub()],
        discount: Discount? = nil
    ) -> Subscription { … }
}
```

This is the single highest-leverage thing to build early — it is why T04 exists before any
calculator. A test that needs 30 lines of JSON to say "a $10 monthly subscription" will not
get written.

Stubs live in `Tests/MRRClockCoreTests/Support/Stubs.swift`. Fixtures (real captured JSON)
are for decoding tests only; calculators are tested with stubs.

## Definition of done, every task

- [ ] Every test in the task file exists, with that behaviour, and passes
- [ ] Each one was seen failing first
- [ ] `swift test` is green across the whole suite
- [ ] No network, no `Date()`, no sleep, no secrets
- [ ] Public API has a doc comment saying what it does and citing the METRICS.md rule
- [ ] No task-out-of-scope work snuck in

## Commits

One commit per task, message `T07: Keychain-backed key store`. Body lists the tests added.
Do not commit a red suite.
