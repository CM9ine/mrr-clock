# T08 · `MRRCalculator` — normalise, filter, discount

**Depends on:** T04 · **Milestone:** M3

## Goal

Turn a list of subscriptions into one MRR figure. This is the number the whole app exists
to show; every rule below comes from METRICS.md and every expected value was worked out by
hand from it.

## Read first

- [METRICS.md § MRR](../METRICS.md#mrr) — all of it, including the worked table
- [TDD.md § What a good test looks like](../TDD.md#what-a-good-test-looks-like-here)

## Build

`Sources/MRRClockCore/Calculations/MRRCalculator.swift`

```swift
public struct MRRResult: Equatable {
    public let total: Money
    public let subscriptionCount: Int
    public let skipped: [SkippedItem]          // priceID + reason
    public let otherCurrencies: Set<String>
    public let churnRisk: Money                // active but cancelAtPeriodEnd
}

public enum SkipReason { case metered, tiered, noUnitAmount, notRecurring }

public struct MRRCalculator {
    public func mrr(subscriptions: [Subscription], config: Config) -> MRRResult
}
```

Order of operations, per subscription: sum items in `Decimal` → apply discount →
clamp at zero → **round half-up once** → add to total.

## Tests

`Tests/MRRClockCoreTests/MRRCalculatorTests.swift`. All amounts in cents, currency `usd`.

**Interval normalisation** — one parameterised test, `@Test(arguments:)`, over the exact
table in METRICS.md:

1. **`normalises a billing interval to a monthly amount`**

   | unitAmount | interval | count | qty | expected |
   | --- | --- | --- | --- | --- |
   | 1000 | month | 1 | 1 | **1000** |
   | 1000 | month | 1 | 3 | **3000** |
   | 3000 | month | 3 | 1 | **1000** |
   | 12000 | year | 1 | 1 | **1000** |
   | 9900 | year | 1 | 1 | **825** |
   | 10000 | year | 1 | 1 | **833** |
   | 24000 | year | 2 | 1 | **1000** |
   | 700 | week | 1 | 1 | **3042** |
   | 1000 | week | 2 | 1 | **2173** |
   | 100 | day | 1 | 1 | **3042** |

   Derivations for the non-obvious ones: `10000/12 = 833.33 → 833`;
   `700 × 30.416666/7 = 3041.67 → 3042`; `1000 × 30.416666/14 = 2172.62 → 2173`.

**Aggregation**

2. **`an empty list is zero MRR`** — `total == Money.zero("usd")`, `count == 0`.
3. **`sums several subscriptions`** — $10/mo + $99/yr → **1825**, `count == 2`.
4. **`sums several items within one subscription`** — one sub with a 1000/month item and a
   9900/year item → **825 + 1000 = 1825**, `count == 1`.

**Status filter**

5. **`counts active subscriptions`** — status `active` → included.
6. **`ignores past_due, unpaid, paused, canceled, incomplete`** — parameterised over the
   five statuses, each with a 1000/month item → total **0** every time.
7. **`ignores trialing by default`** — one active 1000 + one trialing 5000 → **1000**.
8. **`includes trialing when the config says so`** — same input, `includeTrials: true`
   → **6000**.
9. **`counts a subscription that is set to cancel at period end`** — `active` +
   `cancelAtPeriodEnd: true`, 1000/month → total **1000**, and `churnRisk == 1000`.

**Item exclusions** — each excluded item must also appear in `skipped`:

10. **`skips a metered price`** — `usageType == "metered"` → total **0**, one `skipped`
    with reason `.metered`.
11. **`skips a tiered price`** — `billingScheme == "tiered"` → reason `.tiered`.
12. **`skips a price with no unit amount`** — reason `.noUnitAmount`.
13. **`skips a one-off price with no recurring block`** — reason `.notRecurring`.
14. **`still counts the good items on a subscription with one bad item`** — a sub with a
    1000/month item and a metered item → total **1000**, `skipped.count == 1`.

**Discounts**

15. **`applies a percent-off coupon`** — 1000/month, `percentOff: 20` → **800**.
16. **`rounds a percent-off result half up`** — 1000/month, `percentOff: 33.33` →
    `1000 × 0.6667 = 666.7` → **667**.
17. **`applies an amount-off coupon at the subscription interval`** — 1000/month,
    `amountOff: 500` → **500**.
18. **`normalises an amount-off coupon on a yearly subscription`** — 9900/year,
    `amountOff: 500` → `825 − 500/12 = 783.33` → **783**.
19. **`never lets a discount go below zero`** — 1000/month, `amountOff: 5000` → **0**.
20. **`ignores a once-only coupon that has already ended`** — `duration: "once"`,
    `discount.end` before `now` → total **1000**, undiscounted.
21. **`applies a repeating coupon that has not ended`** — `duration: "repeating"`,
    `end` after `now`, `percentOff: 50` → **500**.

**Currency**

22. **`excludes a subscription in another currency`** — config `usd`, one usd 1000 and one
    gbp 5000 → total **1000**, `otherCurrencies == ["gbp"]`.
23. **`an all-foreign-currency account reports zero and lists the currencies`** —
    total **0**, `otherCurrencies == ["gbp"]`.

## Done when

All pass. `Double` appears nowhere in the file. Every expected number above matches the
spec, not the implementation.

## Out of scope

Per-product grouping (T09). Fetching (T05/T06).
