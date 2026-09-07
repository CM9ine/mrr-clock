# Task list

19 tasks. Each is one focused session: read the task file, read the docs it names, write
the tests, make them pass. Rules in [TDD.md](TDD.md). Numbers in [METRICS.md](METRICS.md).

Work them in order — each depends only on tasks above it. To hand one to an agent, use
the prompt in [AGENT-PROMPT.md](AGENT-PROMPT.md) — it finds the next open task itself.

## M1 · Foundation

| # | Task | Depends | Brief | Issue |
| --- | --- | --- | --- | --- |
| T01 | Package skeleton and a green `swift test` | — | [T01](tasks/T01-package-skeleton.md) | [#1](https://github.com/CM9ine/mrr-clock/issues/1) |
| T02 | `Money` — integer minor units | T01 | [T02](tasks/T02-money.md) | [#2](https://github.com/CM9ine/mrr-clock/issues/2) |
| T03 | `Countdown` — calendar-day maths | T01 | [T03](tasks/T03-countdown.md) | [#3](https://github.com/CM9ine/mrr-clock/issues/3) |

## M2 · Stripe layer

| # | Task | Depends | Brief | Issue |
| --- | --- | --- | --- | --- |
| T04 | Stripe DTOs, fixture decoding, stub factories | T02 | [T04](tasks/T04-stripe-dtos.md) | [#4](https://github.com/CM9ine/mrr-clock/issues/4) |
| T05 | `StripeAPI` protocol, pagination, `FakeStripeClient` | T04 | [T05](tasks/T05-stripe-api-pagination.md) | [#5](https://github.com/CM9ine/mrr-clock/issues/5) |
| T06 | `LiveStripeClient` — requests, auth, typed errors | T05 | [T06](tasks/T06-live-stripe-client.md) | [#6](https://github.com/CM9ine/mrr-clock/issues/6) |
| T07 | `KeyStore` — Keychain and in-memory | T01 | [T07](tasks/T07-keystore.md) | [#7](https://github.com/CM9ine/mrr-clock/issues/7) |

## M3 · The numbers

| # | Task | Depends | Brief | Issue |
| --- | --- | --- | --- | --- |
| T08 | `MRRCalculator` — normalise, filter, discount | T04 | [T08](tasks/T08-mrr-calculator.md) | [#8](https://github.com/CM9ine/mrr-clock/issues/8) |
| T09 | MRR breakdown by product, top N + Other | T08 | [T09](tasks/T09-mrr-breakdown.md) | [#9](https://github.com/CM9ine/mrr-clock/issues/9) |
| T10 | `EarningsCalculator` — earned to date | T04 | [T10](tasks/T10-earnings-calculator.md) | [#10](https://github.com/CM9ine/mrr-clock/issues/10) |
| T11 | `Projection` — growth-compounded forecast | T02, T03 | [T11](tasks/T11-projection.md) | [#11](https://github.com/CM9ine/mrr-clock/issues/11) |

## M4 · Goals and state

| # | Task | Depends | Brief | Issue |
| --- | --- | --- | --- | --- |
| T12 | **`Goal` and `GoalStore`** — configurable goals | T02, T03 | [T12](tasks/T12-goals.md) | [#12](https://github.com/CM9ine/mrr-clock/issues/12) |
| T13 | `Snapshot`, `Config`, and the disk cache | T08–T12 | [T13](tasks/T13-snapshot-cache.md) | [#13](https://github.com/CM9ine/mrr-clock/issues/13) |
| T14 | `RefreshCoordinator` — the state machine | T05, T07, T12, T13 | [T14](tasks/T14-refresh-coordinator.md) | [#14](https://github.com/CM9ine/mrr-clock/issues/14) |
| T15 | `MenuBarFormatter` — display strings | T13 | [T15](tasks/T15-menubar-formatter.md) | [#15](https://github.com/CM9ine/mrr-clock/issues/15) |

## M5 · The app

| # | Task | Depends | Brief | Issue |
| --- | --- | --- | --- | --- |
| T16 | Xcode shell, `MenuBarExtra`, popover | T14, T15 | [T16](tasks/T16-app-shell.md) | [#16](https://github.com/CM9ine/mrr-clock/issues/16) |
| T17 | Goals UI and Settings | T16 | [T17](tasks/T17-goals-settings-ui.md) | [#17](https://github.com/CM9ine/mrr-clock/issues/17) |
| T18 | Auto-refresh scheduling and launch at login | T17 | [T18](tasks/T18-scheduling-launch.md) | [#18](https://github.com/CM9ine/mrr-clock/issues/18) |

## M6 · Ship

| # | Task | Depends | Brief | Issue |
| --- | --- | --- | --- | --- |
| T19 | Release build, signing, install, live key | T18 | [T19](tasks/T19-release.md) | [#19](https://github.com/CM9ine/mrr-clock/issues/19) |

---

## Progress
Tracked as issues [#1–#19](https://github.com/CM9ine/mrr-clock/issues), grouped into six milestones.
Tick here as you close them:
- [x] [T01](https://github.com/CM9ine/mrr-clock/issues/1) · [x] [T02](https://github.com/CM9ine/mrr-clock/issues/2) · [ ] [T03](https://github.com/CM9ine/mrr-clock/issues/3)
- [ ] [T04](https://github.com/CM9ine/mrr-clock/issues/4) · [ ] [T05](https://github.com/CM9ine/mrr-clock/issues/5) · [ ] [T06](https://github.com/CM9ine/mrr-clock/issues/6) · [ ] [T07](https://github.com/CM9ine/mrr-clock/issues/7)
- [ ] [T08](https://github.com/CM9ine/mrr-clock/issues/8) · [ ] [T09](https://github.com/CM9ine/mrr-clock/issues/9) · [ ] [T10](https://github.com/CM9ine/mrr-clock/issues/10) · [ ] [T11](https://github.com/CM9ine/mrr-clock/issues/11)
- [ ] [T12](https://github.com/CM9ine/mrr-clock/issues/12) · [ ] [T13](https://github.com/CM9ine/mrr-clock/issues/13) · [ ] [T14](https://github.com/CM9ine/mrr-clock/issues/14) · [ ] [T15](https://github.com/CM9ine/mrr-clock/issues/15)
- [ ] [T16](https://github.com/CM9ine/mrr-clock/issues/16) · [ ] [T17](https://github.com/CM9ine/mrr-clock/issues/17) · [ ] [T18](https://github.com/CM9ine/mrr-clock/issues/18)
- [ ] [T19](https://github.com/CM9ine/mrr-clock/issues/19)

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
