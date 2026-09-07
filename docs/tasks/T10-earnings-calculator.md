# T10 · `EarningsCalculator` — earned to date

**Depends on:** T04 · **Milestone:** M3

## Goal

Total net money Stripe has recognised since the configured start date. Net of fees and
refunds, with payouts excluded.

## Read first

- [METRICS.md § Earned to date](../METRICS.md#earned-to-date)

## Build

`Sources/MRRClockCore/Calculations/EarningsCalculator.swift`

```swift
public struct EarningsResult: Equatable {
    public let total: Money
    public let transactionCount: Int
    public let otherCurrencies: Set<String>
}

public struct EarningsCalculator {
    public func earned(transactions: [BalanceTransaction], config: Config) -> EarningsResult
}
```

Sum `net` where `created >= config.earningsStartDate`, `currency == config.currency`, and
`type` is not in `{payout, payout_cancel, payout_failure, transfer, topup}`.

## Tests

`Tests/MRRClockCoreTests/EarningsCalculatorTests.swift`.
Start date `2026-01-01T00:00:00Z`, currency `usd`.

1. **`an empty list is zero`** — `total == Money.zero("usd")`, `count == 0`.
2. **`sums charges`** — charges of 1000 and 2000 → **3000**, `count == 2`.
3. **`net is already after fees`** — a charge with `net: 971` (a $10 charge less 29c) →
   **971**. The calculator must not subtract fees again.
4. **`refunds reduce the total`** — charges 1000 + 2000, refund −500 → **2500**.
5. **`a refund-only period is negative`** — one refund of −500 → **−500**, not clamped.
6. **`excludes payouts`** — charge 1000, payout −1000 → **1000**, `count == 1`.
7. **`excludes transfers, topups and payout reversals`** — parameterised over
   `transfer`, `topup`, `payout_cancel`, `payout_failure`, each paired with a 1000 charge
   → **1000** every time.
8. **`includes adjustments and disputes`** — `adjustment` of −1500 alongside a 2000 charge
   → **500**. A chargeback is a real reduction in earnings.
9. **`excludes transactions before the start date`** — one at `2025-12-31T23:59:59Z`
   (1000) and one at `2026-01-01T00:00:01Z` (2000) → **2000**.
10. **`includes a transaction exactly on the start date`** — `created` equal to the start
    instant → included. The boundary is `>=`.
11. **`excludes other currencies and reports them`** — usd 1000 + gbp 5000 → **1000**,
    `otherCurrencies == ["gbp"]`.
12. **`counts only the transactions it included`** — mixed input, `transactionCount`
    equals the number summed, not the number supplied.
13. **`decodes and totals the committed fixture`** — run against
    `Fixtures/balance_transactions.json` and assert the exact total worked out by hand from
    that file. Write the arithmetic in a comment above the expectation.

## Done when

All pass, and test 13's expected value was computed by reading the fixture, not by running
the code.

## Out of scope

Currency conversion. Splitting earnings by product — Stripe balance transactions do not
carry that cleanly, and v1 does not pretend otherwise.
