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

### Command Line Tools workaround (verified during T01)

On the local Apple Swift 6.3.3 / Command Line Tools 26.6 installation, plain
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

Use normal `swift test` on toolchains where discovery works. No system files were
changed or additional tools installed for this workaround.

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
