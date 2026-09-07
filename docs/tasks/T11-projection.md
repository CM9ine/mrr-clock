# T11 · `Projection` — growth-compounded forecast

**Depends on:** T02, T03 · **Milestone:** M3

## Goal

"If things carry on like this, you will have $X by the target date." The number that turns
a countdown into feedback.

The target date is a parameter, taken from whichever goal is being projected (T12). This
type contains no dates of its own.

## Read first

- [METRICS.md § Projection](../METRICS.md#projection)

## Build

`Sources/MRRClockCore/Calculations/Projection.swift`

```swift
public struct ProjectionInput {
    let earnedToDate: Money
    let mrr: Money
    let now: Date
    let targetDate: Date             // from Goal.targetDate — never a literal
    let monthlyGrowthRate: Decimal   // 0.10 = +10 %/month
    let calendar: Calendar
}

public struct ProjectionResult: Equatable {
    public let projected: Money
    public let wholeMonths: Int
    public let partialMonth: Decimal
    public let mrrAtTarget: Money
}

public struct Projection {
    public func project(_ input: ProjectionInput) -> ProjectionResult
}
```

```
projected = earned + MRR × Σ(i = 0 … n−1)(1+g)ⁱ + MRR × (1+g)ⁿ × r
```

All in `Decimal`; round half-up once at the end.

## Tests

`Tests/MRRClockCoreTests/ProjectionTests.swift`

**Month splitting** (dates → `n` and `r`, before any money is involved)

1. **`splits the real deadline into whole and partial months`** — now
   `2026-09-07T09:00:00Z`, target `2027-09-29T00:00:00Z`, UTC →
   `wholeMonths == 12`, `partialMonth == 22/30`. Derivation: 2026-09-07 + 12 months =
   2027-09-07, which leaves 22 days; the target sits in September, a 30-day month.
2. **`a target exactly n months out has no partial month`** — 2026-09-07 → 2027-09-07:
   `n == 12`, `r == 0`.
3. **`a target inside the same month is all partial`** — 2026-09-07 → 2026-09-22:
   `n == 0`, `r == 15/30`.
4. **`a past target is zero months`** — target before now → `n == 0`, `r == 0`.
5. **`today is zero months`** — target == now → `n == 0`, `r == 0`.

**Flat projection (g = 0)**

6. **`projects MRR across whole months`** — earned 0, MRR 10000, n 12, r 0 →
   **120000** ($1,200).
7. **`adds earnings already banked`** — earned 50000, MRR 10000, n 12, r 0 →
   **170000**.
8. **`counts a partial month pro rata`** — earned 0, MRR 10000, n 12, r 0.5 →
   **125000**.
9. **`zero MRR projects exactly what is already earned`** — earned 50000, MRR 0 →
   **50000**.
10. **`a past target projects exactly what is already earned`** — earned 50000,
    MRR 10000, target yesterday → **50000**.

**Compounded projection**

11. **`compounds two months at ten percent`** — earned 0, MRR 10000, n 2, r 0, g 0.10 →
    `10000 + 11000` = **21000**.
12. **`compounds three months at ten percent`** → `10000 + 11000 + 12100` = **33100**.
13. **`compounds the partial month at the final rate`** — MRR 10000, n 2, r 0.5, g 0.10 →
    `10000 + 11000 + 12100 × 0.5` = **27050**.
14. **`reports MRR at the target date`** — MRR 10000, n 12, g 0.10 →
    `mrrAtTarget == 31384` (10000 × 1.1¹² = 31384.28 → 31384).
15. **`a negative growth rate shrinks the projection`** — MRR 10000, n 2, g −0.10 →
    `10000 + 9000` = **19000**.

**End to end**

16. **`projects for any target date, not just one`** — the same inputs with target
    2027-01-31 and 2028-06-15 give different, hand-checked results. Guards against a
    date sneaking into the implementation.
17. **`reproduces a row from the plan`** — earned 0, MRR 50000 ($500), now 2026-09-07,
    target 2027-09-29, g 0.10 → **1184290** ($11,842.90, shown as $11,843), matching
    [PLAN.md § compounding](../PLAN.md#what-127-months-of-compounding-actually-produces)
    to the dollar. If this test and the plan disagree, one of them is wrong — find out
    which before moving on.
18. **`currency is preserved`** — inputs in `gbp` → result in `gbp`.
19. **`mismatched currencies between earned and MRR are rejected`** — throws, or is
    unrepresentable by construction.

## Done when

All pass, including the plan-reconciliation test.

## Out of scope

Inferring the growth rate from history. There is no history yet; `g` is a user assumption.
