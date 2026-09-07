# T15 · `MenuBarFormatter` — display strings

**Depends on:** T13 · **Milestone:** M4

## Goal

Every string the UI shows, produced by tested pure functions. SwiftUI views should
interpolate nothing and format nothing.

## Read first

- [ARCHITECTURE.md](../ARCHITECTURE.md) — why the views stay dumb

## Build

`Sources/MRRClockCore/MenuBarFormatter.swift`

```swift
public enum TitleFormat: String, Codable, CaseIterable {
    case daysOnly, mrrOnly, daysAndMRR, percentAndDays
}

public struct MenuBarFormatter {
    init(locale: Locale = .current)
    func title(for snapshot: Snapshot?, phase: AppPhase, format: TitleFormat) -> String
    func compactMoney(_ money: Money) -> String     // $1.2k
    func daysLabel(_ days: Int) -> String           // "387 days" / "today" / "3 days over"
    func longDaysLabel(_ days: Int) -> String       // "1 year, 22 days"
    func relativeSync(_ syncedAt: Date, now: Date) -> String
    func percentLabel(_ ratio: Decimal?) -> String  // "25%" / "—"
}
```

The title is driven by the **pinned goal**; with no goals it says so rather than showing a
misleading zero.

## Tests

`Tests/MRRClockCoreTests/MenuBarFormatterTests.swift`. Pin `Locale(identifier: "en_US")`
in every test — the suite must pass on a machine set to any locale.

**Compact money**

1. **`abbreviates thousands`** — parameterised: `0 → "$0"`, `99900 → "$999"`,
   `100000 → "$1k"`, `124000 → "$1.2k"`, `999900 → "$10k"`, `1000000 → "$10k"`,
   `123456700 → "$1.2M"`. (Inputs are cents.)
2. **`drops a trailing .0`** — `200000` ($2,000) → `"$2k"`, not `"$2.0k"`.
3. **`abbreviates a negative amount`** — `-124000` → `"-$1.2k"`.
4. **`uses the currency symbol for the money's currency`** — `Money(124000,"gbp")` →
   `"£1.2k"`.

**Day labels**

5. **`labels a normal count`** — `387` → `"387 days"`.
6. **`uses the singular for one day`** — `1` → `"1 day"`.
7. **`says today for zero`** — `0` → `"today"`.
8. **`labels an overdue goal`** — `-3` → `"3 days over"`; `-1` → `"1 day over"`.
9. **`spells out long spans`** — `longDaysLabel(387)` → `"1 year, 22 days"`;
   `365` → `"1 year"`; `45` → `"1 month, 15 days"`; `20` → `"20 days"`.

**Titles**

10. **`daysOnly shows the pinned goal's countdown`** — `"387d"`.
11. **`mrrOnly shows compact MRR`** — `"$1.2k"`.
12. **`daysAndMRR joins them`** — `"387d · $1.2k"` (middle dot, spaces either side).
13. **`percentAndDays shows funding progress`** — 25 % funded → `"25% · 387d"`.
14. **`percentAndDays falls back to daysAndMRR when the goal has no target amount`**.
15. **`shows a setup prompt when there is no key`** — phase `.needsSetup` →
    `"Set up"`.
16. **`shows an add-goal prompt when there are no goals`** — phase `.noGoals` →
    `"Add a goal"`.
17. **`marks a stale title`** — phase `.stale` with a snapshot → the numbers are still
    shown, with a trailing `"⚠"`. The user must be able to tell fresh from stale at a
    glance.
18. **`shows the countdown but not the money when stale with no snapshot`** — dashes for
    MRR: `"387d · —"`.
19. **`shows an overdue title`** — pinned goal 3 days past → `"3d over · $1.2k"`.
20. **`title stays under sixteen characters`** — across every format and a
    $1,234,567 MRR. A long menu bar title is silently truncated by macOS, which is worse
    than abbreviating it deliberately.

**Sync and percent labels**

21. **`describes a recent sync`** — parameterised on seconds since sync:
    `5 → "just now"`, `90 → "1m ago"`, `600 → "10m ago"`, `7200 → "2h ago"`,
    `172800 → "2d ago"`.
22. **`formats a percent`** — `0.25 → "25%"`, `1.2 → "120%"`, `0.005 → "1%"`
    (rounds half up), `nil → "—"`, `-0.1 → "-10%"`.

## Done when

All pass on a machine with a non-US locale set (verify once by hand:
`defaults write -g AppleLocale de_DE` is not required — just confirm the tests pin locale
explicitly rather than relying on `.current`).

## Out of scope

SwiftUI views (T16).
