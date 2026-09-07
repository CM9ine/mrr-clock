# T14 · `RefreshCoordinator` — the state machine

**Depends on:** T05, T07, T12, T13 · **Milestone:** M4

## Goal

The one object the app talks to. Fetch, calculate, cache, publish state — and never lose
good numbers because a network call failed.

## Read first

- [ARCHITECTURE.md § State machine](../ARCHITECTURE.md#state-machine)

## Build

`Sources/MRRClockCore/RefreshCoordinator.swift`

```swift
public enum AppPhase: Equatable {
    case idle
    case needsSetup                          // no key, or the key was rejected
    case noGoals                             // key is fine, nothing to count down to
    case loading(previous: Snapshot?)
    case loaded(Snapshot)
    case stale(Snapshot?, StripeError)
}

public actor RefreshCoordinator {
    init(api: @Sendable (String) -> StripeAPI,
         keyStore: KeyStore, goalStore: GoalStore,
         cache: SnapshotStorage, clock: Clock, config: Config)

    var phase: AppPhase { get }
    func start() async            // load cache, publish, then refresh
    func refresh() async          // full network refresh
    func recomputeGoals() async   // re-run goal maths on cached revenue, no network
}
```

Sequence per [ARCHITECTURE.md](../ARCHITECTURE.md#data-flow-one-refresh). Three rules that
the tests exist to pin down:

- **A failed refresh never clears the cache.** `.stale` carries the last good snapshot.
- **A 401 means the key is wrong** → `.needsSetup`, and the key is *not* deleted (the user
  may want to see and correct it).
- **Goal edits do not hit the network.** `recomputeGoals()` reuses the cached
  `RevenueSnapshot`.

## Tests

`Tests/MRRClockCoreTests/RefreshCoordinatorTests.swift`, wired with `FakeStripeClient`,
`InMemoryKeyStore`, `InMemoryGoalStore`, `InMemorySnapshotCache`, `FixedClock`.

**Start-up**

1. **`starts in needsSetup when there is no key`** — and makes **zero** API calls.
2. **`starts in noGoals when there is a key but no goals`** — zero API calls.
3. **`publishes the cached snapshot before the network returns`** — with a cached
   snapshot present, the first phase after `start()` is `.loading(previous: cached)`,
   carrying the old numbers, not `nil`.
4. **`ends in loaded after a successful start`**.

**Refresh**

5. **`fetches subscriptions, transactions and products once each`** — call counts all 1.
6. **`produces a snapshot with one entry per goal`** — 2 goals → 2 entries.
7. **`writes the snapshot to the cache`** — cache write count 1, contents equal.
8. **`stamps syncedAt from the clock`**.
9. **`a second refresh replaces the snapshot`** — MRR changes between fetches; phase
   carries the new value.

**Failure**

10. **`keeps the previous snapshot on a network error`** — refresh once successfully,
    then force `.network` → phase is `.stale(previous, .network)` with the **old numbers
    intact**, and the cache still holds the old snapshot.
11. **`goes to needsSetup on 401`** — and the key is still readable from the key store.
12. **`stays stale on 429 and does not clear the cache`**.
13. **`shows a first-run failure with no snapshot`** — no cache, network error →
    `.stale(nil, error)`. The UI can still draw countdowns from local goals.
14. **`recovers to loaded when a later refresh succeeds`** — fail, then succeed.
15. **`carries on when only the products call fails`** — products throws, subscriptions
    and transactions succeed → phase `.loaded`, breakdown lines fall back to product ids.
    Names are cosmetic; the money is not.

**Goal recomputation**

16. **`recomputes goals without any network call`** — refresh, record call counts, add a
    goal, `recomputeGoals()` → call counts unchanged, snapshot has one more entry.
17. **`recomputing keeps the original syncedAt`** — the revenue figures are as old as
    they were; the timestamp must not lie about that.
18. **`recomputing with no cached revenue triggers a refresh instead`**.
19. **`goes to noGoals when the last goal is deleted`**.

**Concurrency**

20. **`two overlapping refreshes result in one set of fetches`** — call `refresh()` twice
    without awaiting the first; the API is hit once and both callers see the same
    snapshot.

## Done when

All pass, deterministically, with no sleeps and no network.

## Out of scope

Timers and scheduling (T18). Any SwiftUI.
