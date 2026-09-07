# T13 · `Snapshot`, `Config`, and the disk cache

**Depends on:** T08–T12 · **Milestone:** M4

## Goal

One value type that holds everything the UI draws, assembled from the calculators, and a
cache so the numbers are on screen the instant the app launches.

## Read first

- [ARCHITECTURE.md § Data flow](../ARCHITECTURE.md#data-flow-one-refresh)
- [METRICS.md § Percent funded](../METRICS.md#percent-funded)

## Build

`Sources/MRRClockCore/Config.swift`

```swift
public struct Config: Equatable, Codable, Sendable {
    var currency: String            = "usd"
    var earningsStartDate: Date
    var monthlyGrowthRate: Decimal  = 0
    var includeTrials: Bool         = false
    var breakdownLimit: Int         = 3
    var refreshInterval: TimeInterval = 900     // 15 minutes
    var titleFormat: TitleFormat    = .daysAndMRR
    static let `default`: Config                 // earningsStartDate = 1 Jan of this year
}
```

`Sources/MRRClockCore/Snapshot.swift`

```swift
public struct Snapshot: Equatable, Codable, Sendable {
    public let syncedAt: Date
    public let revenue: RevenueSnapshot        // account-wide, one per refresh
    public let goals: [GoalProgress]           // one per goal, pinned first
    public let specVersion: Int                // MRRClockCore.metricsSpecVersion
}

public struct RevenueSnapshot: Equatable, Codable {
    let mrr: Money
    let earnedToDate: Money
    let breakdown: [ProductLine]
    let subscriptionCount: Int
    let churnRisk: Money
    let warnings: [String]                     // skipped items, other currencies
}

public struct GoalProgress: Equatable, Codable {
    let goalID: UUID
    let name: String
    let targetDate: Date
    let targetAmount: Money?
    let daysRemaining: Int
    let projected: Money
    let percentFunded: Decimal?                // nil when no targetAmount
    let percentOnTrack: Decimal?
    var isPinned: Bool
    var isOverdue: Bool { daysRemaining < 0 }
}
```

Plus `SnapshotBuilder`, which takes revenue + `[Goal]` + config + `now` and produces a
`Snapshot`. **No network, no I/O, no `Date()`** — pure assembly, so it is fully testable.

`Sources/MRRClockCore/SnapshotCache.swift` — same shape as `FileGoalStore`: atomic write to
`snapshot.json`, corrupt-file recovery, missing file → `nil`.

## Tests

`Tests/MRRClockCoreTests/SnapshotBuilderTests.swift`

1. **`builds one progress entry per goal`** — 3 goals → 3 entries.
2. **`puts the pinned goal first`** — pin the third goal → it is `goals[0]`,
   `isPinned == true`, and the rest keep their sort order.
3. **`carries the revenue figures through unchanged`** — MRR and earned equal the
   calculator outputs.
4. **`computes days remaining per goal`** — two goals with different dates get different,
   hand-checked day counts from the same `now`.
5. **`computes a projection per goal`** — the nearer goal projects less than the further
   one, and both match `Projection` called directly.
6. **`computes percent funded when the goal has a target amount`** — earned 25000,
   target 100000 → `0.25`.
7. **`leaves percent funded nil when the goal has no target amount`**.
8. **`computes percent on track from the projection`** — projected 120000,
   target 100000 → `1.2`, **not clamped**.
9. **`marks a past goal overdue`** — target yesterday → `daysRemaining == -1`,
   `isOverdue == true`.
10. **`builds an empty goals array when there are no goals`** — revenue still present.
11. **`collects warnings from skipped items and foreign currencies`** — one metered item
    and one gbp subscription → 2 warnings, each naming the cause.
12. **`stamps syncedAt from the injected clock`** — not from `Date()`.
13. **`stamps the current spec version`**.

`Tests/MRRClockCoreTests/SnapshotCacheTests.swift`

14. **`returns nil when nothing is cached`**.
15. **`round-trips a snapshot through disk`** — every field equal after reload, including
    `Decimal` percentages and `Money`.
16. **`overwrites the previous snapshot`** — write twice, read the second.
17. **`returns nil and quarantines a corrupt file`** — as T12's rule; renamed to
    `snapshot.corrupt.json`, no crash.
18. **`ignores a snapshot from an older spec version`** — a cached snapshot with
    `specVersion: 0` returns `nil`. When the MRR rules change, a stale number computed
    under the old rules must not be shown as if it were current.
19. **`reports staleness against the clock`** — `isStale(now:maxAge:)` is false at
    14 minutes and true at 16, for a 15-minute max age.

## Done when

All pass. `SnapshotBuilder` contains no `Date()`, no file access, and no `try await`.

## Out of scope

Fetching and orchestration (T14). Formatting for display (T15).
