# Task list

19 tasks. Each is one focused session: read the task file, read the docs it names, write
the tests, make them pass. Rules in [TDD.md](TDD.md). Numbers in [METRICS.md](METRICS.md).

Work them in order — each depends only on tasks above it.

## M1 · Foundation

| # | Task | Depends | File |
| --- | --- | --- | --- |
| T01 | Package skeleton and a green `swift test` | — | [T01](tasks/T01-package-skeleton.md) |
| T02 | `Money` — integer minor units | T01 | [T02](tasks/T02-money.md) |
| T03 | `Countdown` — calendar-day maths | T01 | [T03](tasks/T03-countdown.md) |

## M2 · Stripe layer

| # | Task | Depends | File |
| --- | --- | --- | --- |
| T04 | Stripe DTOs, fixture decoding, stub factories | T02 | [T04](tasks/T04-stripe-dtos.md) |
| T05 | `StripeAPI` protocol, pagination, `FakeStripeClient` | T04 | [T05](tasks/T05-stripe-api-pagination.md) |
| T06 | `LiveStripeClient` — requests, auth, typed errors | T05 | [T06](tasks/T06-live-stripe-client.md) |
| T07 | `KeyStore` — Keychain and in-memory | T01 | [T07](tasks/T07-keystore.md) |

## M3 · The numbers

| # | Task | Depends | File |
| --- | --- | --- | --- |
| T08 | `MRRCalculator` — normalise, filter, discount | T04 | [T08](tasks/T08-mrr-calculator.md) |
| T09 | MRR breakdown by product, top N + Other | T08 | [T09](tasks/T09-mrr-breakdown.md) |
| T10 | `EarningsCalculator` — earned to date | T04 | [T10](tasks/T10-earnings-calculator.md) |
| T11 | `Projection` — growth-compounded forecast | T02, T03 | [T11](tasks/T11-projection.md) |

## M4 · Goals and state

| # | Task | Depends | File |
| --- | --- | --- | --- |
| T12 | **`Goal` and `GoalStore`** — configurable goals | T02, T03 | [T12](tasks/T12-goals.md) |
| T13 | `Snapshot`, `Config`, and the disk cache | T08–T12 | [T13](tasks/T13-snapshot-cache.md) |
| T14 | `RefreshCoordinator` — the state machine | T05, T07, T12, T13 | [T14](tasks/T14-refresh-coordinator.md) |
| T15 | `MenuBarFormatter` — display strings | T13 | [T15](tasks/T15-menubar-formatter.md) |

## M5 · The app

| # | Task | Depends | File |
| --- | --- | --- | --- |
| T16 | Xcode shell, `MenuBarExtra`, popover | T14, T15 | [T16](tasks/T16-app-shell.md) |
| T17 | Goals UI and Settings | T16 | [T17](tasks/T17-goals-settings-ui.md) |
| T18 | Auto-refresh scheduling and launch at login | T17 | [T18](tasks/T18-scheduling-launch.md) |

## M6 · Ship

| # | Task | Depends | File |
| --- | --- | --- | --- |
| T19 | Release build, signing, install, live key | T18 | [T19](tasks/T19-release.md) |

---

## Progress

- [ ] T01 · [ ] T02 · [ ] T03
- [ ] T04 · [ ] T05 · [ ] T06 · [ ] T07
- [ ] T08 · [ ] T09 · [ ] T10 · [ ] T11
- [ ] T12 · [ ] T13 · [ ] T14 · [ ] T15
- [ ] T16 · [ ] T17 · [ ] T18
- [ ] T19

## Notes on sequencing

**T01–T15 need no Xcode project, no signing, no Stripe account, and no UI.** They are plain
`swift test` in a terminal. If momentum is a problem, this is the whole point of the
ordering — fifteen tasks of visible progress before anything can go wrong with
provisioning profiles.

**T04 is load-bearing.** The stub factories it produces are what make T08–T11 quick. Do not
skim it.

**T12 is the one that keeps the app general.** Goals are user data: a name, a date, an
optional amount, stored in a JSON file and editable in the app. No date or target is
compiled in. Whatever you type on launch day is just the first row, and the app should be
just as happy with "$2k MRR by June" next to it. `grep -rn "2027" Sources/` returning
nothing is a real acceptance criterion, checked again in T19.

**T16–T18 are the least testable and should be the thinnest.** If a UI task starts wanting
logic, that logic belongs in the core package with tests — stop and add it there.
