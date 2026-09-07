# T04 · Stripe DTOs, fixture decoding, stub factories

**Depends on:** T02 · **Milestone:** M2

## Goal

Swift types that decode real Stripe JSON, plus the `.stub()` factories that make every
later test short. **This task is load-bearing** — T08 through T11 are quick only if the
stubs here are good.

## Read first

- [STRIPE.md § Fixtures](../STRIPE.md#fixtures)
- [TDD.md § Test data](../TDD.md#test-data)

## Build

`Sources/MRRClockCore/Stripe/StripeDTOs.swift` — decode only the fields the app uses,
ignore the rest:

```swift
public struct StripeList<T: Decodable>: Decodable { let data: [T]; let hasMore: Bool }
public struct Subscription  { id, status, currency, cancelAtPeriodEnd, items, discount }
public struct SubscriptionItems { data: [SubscriptionItem], hasMore: Bool }
public struct SubscriptionItem  { id, quantity, price }
public struct Price   { id, product, currency, unitAmount, recurring, billingScheme }
public struct Recurring { interval: Interval, intervalCount: Int, usageType: String }
public enum   Interval: String { day, week, month, year }
public struct Discount { coupon, end: Date? }
public struct Coupon   { percentOff: Decimal?, amountOff: Int?, duration: String }
public struct BalanceTransaction { id, type, net: Int, currency, created: Date }
public struct Product { id, name }
```

- One `JSONDecoder` factory: `.convertFromSnakeCase`, `.secondsSince1970` for dates.
- `unit_amount` is `Int?` — nil for tiered prices, and that nil is meaningful.
- `percent_off` decodes to `Decimal`, never `Double`.
- Unknown `interval` or `status` values must not crash the whole decode. Decode `status`
  as `String`, and `Interval` with a `.unknown` fallback case.

Fixtures: capture and redact per STRIPE.md, at minimum `subscriptions_active.json`,
`subscriptions_edge.json`, `balance_transactions.json`, `products.json`.

`Tests/MRRClockCoreTests/Support/Stubs.swift` — factories with defaults for every field so
a test names only what it cares about:

```swift
Subscription.stub(status: "active", items: [.stub(unitAmount: 1000, interval: .month)])
Price.stub(unitAmount: 9900, interval: .year)
BalanceTransaction.stub(type: "charge", net: 1000)
```

## Tests

`Tests/MRRClockCoreTests/StripeDTOTests.swift`

1. **`decodes a monthly subscription from the fixture`** — from
   `subscriptions_active.json`: id, `status == "active"`, one item, `unitAmount == 1000`,
   `interval == .month`, `intervalCount == 1`.
2. **`decodes a yearly subscription`** — `interval == .year`, `unitAmount == 9900`.
3. **`decodes a subscription with several items`** — `items.data.count == 2`.
4. **`converts snake_case keys`** — `cancel_at_period_end` → `cancelAtPeriodEnd`,
   `unit_amount` → `unitAmount`.
5. **`decodes created as a date from a unix timestamp`** — a known epoch in
   `balance_transactions.json` equals the expected `Date`.
6. **`decodes a tiered price with a nil unit amount`** — from `subscriptions_edge.json`,
   `unitAmount == nil` and `billingScheme == "tiered"`.
7. **`decodes a percent-off discount as a Decimal`** — `percentOff == Decimal(20)`.
8. **`decodes an amount-off discount in minor units`** — `amountOff == 500`.
9. **`decodes an unknown interval as .unknown instead of throwing`** — feed inline JSON
   with `"interval": "fortnight"`; decoding succeeds.
10. **`ignores unknown top-level fields`** — inline JSON with an extra
    `"livemode": true, "some_new_field": {}` still decodes.
11. **`decodes the list envelope with has_more`** — `hasMore == true` and
    `data.count` matches.
12. **`decodes balance transactions of every type in the fixture`** — charge, refund and
    payout all present, `net` signs preserved (refund negative).
13. **`decodes products with names`** — `products.json` yields id → name pairs.
14. **`stub factories produce a decodable-equivalent value`** — `Subscription.stub()` has
    `status == "active"`, one item, a `.month` price of `1000`. Guards the defaults every
    later test leans on.

## Done when

All pass, and fixtures contain no real customer ids, emails, or keys.

## Out of scope

Any calculation. Any network call. This task only turns JSON into structs.
