# T09 · MRR breakdown by product

**Depends on:** T08 · **Milestone:** M3

## Goal

The three lines under the MRR figure: which products the money comes from, biggest first,
with the tail collapsed into "Other".

## Read first

- [METRICS.md § Breakdown by product](../METRICS.md#breakdown-by-product-t09)

## Build

Extend `MRRCalculator`:

```swift
public struct ProductLine: Equatable {
    public let productID: String
    public let name: String
    public let amount: Money
}

public func breakdown(
    subscriptions: [Subscription],
    productNames: [String: String],
    config: Config
) -> [ProductLine]
```

- Group item monthly amounts by `price.product`, rounding each product line once
- Sort by amount descending, then name ascending
- Keep `config.breakdownLimit` (default 3), collapse the rest into one line with
  `productID == "other"` and `name == "Other"`
- Omit the Other line when the remainder is zero
- Discounts are applied pro rata across a subscription's product lines by their share of
  the subscription total

## Tests

`Tests/MRRClockCoreTests/MRRBreakdownTests.swift`

1. **`an empty list produces no lines`** — `[]`.
2. **`one product produces one line`** — 1000/month on `prod_a` → one line,
   `amount == 1000`, `name == "Aurora"` from the name map.
3. **`falls back to the product id when the name is unknown`** — empty name map →
   `name == "prod_a"`.
4. **`sums several subscriptions of the same product into one line`** — two subs on
   `prod_a` at 1000 and 500 → one line of **1500**.
5. **`sorts lines by amount descending`** — a=820, b=310, c=60 →
   `["prod_a", "prod_b", "prod_c"]`.
6. **`breaks ties by name ascending`** — two products both at 500, named "Zebra" and
   "Alpha" → Alpha first. Determinism matters more than which order is "right".
7. **`collapses everything past the limit into Other`** — a=820, b=310, c=60, d=50 with
   limit 3 → four lines: `820, 310, 60, Other 50`.
8. **`sums several tail products into one Other line`** — a=820, b=310, c=60, d=50, e=40
   with limit 3 → Other == **90**.
9. **`omits Other when nothing is left over`** — exactly 3 products with limit 3 → 3 lines,
   no line named "Other".
10. **`respects a limit of one`** — a=820, b=310 with limit 1 → `820`, `Other 310`.
11. **`splits a discount across the products of one subscription`** — a subscription with
    a 1000 `prod_a` item and a 1000 `prod_b` item, `percentOff: 50` → two lines of
    **500** each, and their sum equals the T08 total for the same input.
12. **`excludes skipped items from the breakdown`** — 1000/month `prod_a` plus a metered
    `prod_b` item → one line only.
13. **`excludes foreign-currency subscriptions`** — matches the T08 rule.
14. **`line totals reconcile with the MRR total`** — for a fixture-sized mixed input,
    `abs(sum(lines) − mrr.total) <= lines.count` cents. Documents that per-line rounding
    can drift by a cent and that the UI must show `MRRResult.total`, not the sum.

## Done when

All pass, and the sort is stable enough that running the suite twice gives identical
output.

## Out of scope

Display formatting and truncation of long names (T15).
