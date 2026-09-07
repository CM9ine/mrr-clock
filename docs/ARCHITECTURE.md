# Architecture

## Shape

One rule drives the whole design: **everything that can be wrong about money lives in a
pure Swift package with no UI and no network.** The app target is a thin shell that
renders a value type.

```
                    ┌─────────────────────────────────────┐
                    │  MRRClock (Xcode app target)         │
                    │  MenuBarExtra · PopoverView          │
                    │  SettingsView · AppState             │
                    └──────────────┬──────────────────────┘
                                   │ reads one Snapshot
                    ┌──────────────▼──────────────────────┐
                    │  MRRClockCore (SwiftPM, pure)        │
                    │                                      │
                    │  RefreshCoordinator                  │
                    │    ├─ GoalStore  ◄── user's goals    │
                    │    ├─ StripeAPI (protocol)           │
                    │    ├─ MRRCalculator                  │
                    │    ├─ EarningsCalculator             │
                    │    ├─ Projection      (per goal)     │
                    │    ├─ Countdown       (per goal)     │
                    │    ├─ SnapshotCache                  │
                    │    └─ MenuBarFormatter               │
                    └──────┬───────────────────┬───────────┘
                           │                   │
              ┌────────────▼──────┐   ┌────────▼──────────┐
              │ LiveStripeClient  │   │ FakeStripeClient  │
              │ URLSession →      │   │ fixtures →        │
              │ api.stripe.com    │   │ tests             │
              └───────────────────┘   └───────────────────┘
```

## Layout

```
mrr-clock/
├── Package.swift                       # MRRClockCore + tests
├── Sources/MRRClockCore/
│   ├── Money.swift                     # T02  integer minor units + currency
│   ├── Countdown.swift                 # T03  calendar-day math
│   ├── Stripe/
│   │   ├── StripeDTOs.swift            # T04  Codable mirrors of Stripe JSON
│   │   ├── StripeAPI.swift             # T05  protocol + pagination
│   │   ├── FakeStripeClient.swift      # T05  test double
│   │   ├── LiveStripeClient.swift      # T06  URLSession implementation
│   │   └── StripeError.swift           # T06  typed errors
│   ├── KeyStore.swift                  # T07  Keychain protocol + impls
│   ├── Calculations/
│   │   ├── MRRCalculator.swift         # T08, T09
│   │   ├── EarningsCalculator.swift    # T10
│   │   └── Projection.swift            # T11
│   ├── Goal.swift                      # T12  goal value type + validation
│   ├── GoalStore.swift                 # T12  CRUD, ordering, pinning, persistence
│   ├── Snapshot.swift                  # T13  the one value type the UI renders
│   ├── SnapshotCache.swift             # T13  disk persistence
│   ├── Config.swift                    # T13  user settings value type
│   ├── RefreshCoordinator.swift        # T14  orchestration + state machine
│   └── MenuBarFormatter.swift          # T15  Snapshot → display strings
├── Tests/MRRClockCoreTests/
│   ├── …one test file per source file…
│   └── Fixtures/*.json                 # captured Stripe responses
├── App/                                # Xcode project, T16–T19
│   ├── MRRClockApp.swift               # MenuBarExtra entry point
│   ├── AppState.swift                  # ObservableObject wrapping the coordinator
│   ├── PopoverView.swift               # pinned goal + goal switcher
│   ├── GoalListView.swift              # add / edit / delete / reorder goals
│   ├── GoalEditorView.swift            # name, date picker, optional amount
│   └── SettingsView.swift              # key, growth, interval, title format
└── docs/
```

## Data flow, one refresh

```
timer fires (or user clicks ↻)
   │
   ├─ KeyStore.read()     ──► nil? ──► state = .needsSetup, stop
   ├─ GoalStore.goals()   ──► empty? ──► state = .noGoals, stop
   │
   ├─ StripeAPI.activeSubscriptions()    ─┐  concurrently
   ├─ StripeAPI.balanceTransactions()    ─┤  (async let)
   ├─ StripeAPI.products()               ─┘
   │
   ├─ MRRCalculator.mrr(subscriptions)          ──► Money + [ProductLine] + [Skipped]
   ├─ EarningsCalculator.earned(transactions)   ──► Money        ┐ account-wide,
   │                                                              ┘ computed once
   └─ for each goal:                                              ┐ per goal,
        ├─ Countdown.daysRemaining(now, goal.targetDate)  ──► Int │ cheap, no I/O
        ├─ Projection.project(earned, mrr, goal, growth)  ──► Money
        └─ percentFunded(earned, projected, goal)         ──► Decimal?
   │
   ├─ build Snapshot { revenue, [GoalProgress], syncedAt: now }
   ├─ SnapshotCache.write(snapshot)
   └─ state = .loaded(snapshot)  ──► AppState publishes ──► SwiftUI redraws

Goal edits do **not** trigger a network refresh. Adding or editing a goal recomputes the
per-goal block from the cached revenue figures — instant, offline, and free. Only the timer
and the manual refresh button talk to Stripe.
```

On failure the previous cached snapshot stays on screen, marked stale, with the error
available in the popover. **The app never shows a blank or a zero because the network
was down** — a zero MRR and an unreachable Stripe must look different.

## The seams

Four protocols, and they are the only places the outside world gets in. Each has a live
implementation and a test double, injected through initialisers.

| Protocol | Live | Test double |
| --- | --- | --- |
| `StripeAPI` | `LiveStripeClient` (URLSession) | `FakeStripeClient` (fixtures) |
| `KeyStore` | `KeychainKeyStore` | `InMemoryKeyStore` |
| `Clock` | `SystemClock` | `FixedClock(at:)` |
| `SnapshotStorage` | `FileSnapshotCache` | `InMemorySnapshotCache` |
| `GoalStorage` | `FileGoalStore` | `InMemoryGoalStore` |

`Clock` is the important one. **No calculator or coordinator may call `Date()`.** Every
date comes in as a parameter or from an injected `Clock`, which is what lets a test assert
"387 days remaining" as a fixed fact instead of a moving target.

## State machine

```
        ┌──────────────┐  no key
        │ .needsSetup  │◄──────────────┐
        └──────┬───────┘               │
               │ key saved             │ key cleared / 401
               ▼                       │
        ┌──────────────┐  no goals     │
        │  .noGoals    │               │
        └──────┬───────┘               │
               │ first goal added      │
               ▼                       │
        ┌──────────────┐               │
   ┌───►│  .loading    │───────────────┤
   │    └──────┬───────┘               │
   │           │ success               │ error
   │           ▼                       ▼
   │    ┌──────────────┐        ┌──────────────┐
   └────┤  .loaded     │        │ .stale(snap, │
 refresh└──────────────┘        │        error)│
                                └──────┬───────┘
                                       │ retry succeeds
                                       └──────────► .loaded
```

`.stale` always carries the last good snapshot. If there has never been one, the popover
shows the countdown — which is pure date maths on local goal data and needs no network —
and dashes for the money.

`.noGoals` is a real state, not an error: a fresh install has a key but nothing to count
down to. The popover shows a single "Add your first goal" button.

## Storage

| What | Where | Why |
| --- | --- | --- |
| Stripe restricted key | Keychain, service `com.mrrclock.app`, account `stripe.restricted_key` | Secret. Never in a plist, never in a log, never in an error message. |
| Goals | `~/Library/Application Support/MRRClock/goals.json` | User-authored data. A file is inspectable, backup-able, and hand-editable; `UserDefaults` is none of those. |
| Config (growth, interval, title format) | `UserDefaults` | Not secret, trivially small |
| Last snapshot | `~/Library/Application Support/MRRClock/snapshot.json` | Survives restart, offline, and Stripe outages |

## Extension points

The deferred features from [PLAN.md](PLAN.md#out-of-scope-v1) each land at one seam:

- **Multiple Stripe accounts** — `StripeAPI` becomes an array; calculators already take
  a flat list of subscriptions and do not care where they came from.
- **History and charts** — `SnapshotCache` appends instead of overwriting. The `Snapshot`
  type is already a complete point-in-time record.
- **Per-goal revenue attribution** — `GoalProgress` gains a product filter; the calculators
  already take an arbitrary subscription list.
- **Non-Stripe revenue** — a second source feeding the same calculator inputs.
- **Notifications** — the coordinator already knows when a snapshot changes.

None of these require touching the money math. That is the point of putting it in a pure
package first.
