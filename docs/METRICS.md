# Metrics — exact definitions

This document is the specification the tests are written against. If an implementation
and this file disagree, **this file wins** — change the code, or change this file first
and then the code. Every rule here is chosen to be *decidable*: an agent must be able to
tell, for any input, exactly what the output should be.

## Money representation

- Integer **minor units** (cents) throughout. `Money { amount: Int, currency: String }`.
- Currency is a lowercase ISO-4217 code, matching Stripe's JSON (`"usd"`, `"gbp"`).
- Arithmetic between different currencies is a programmer error and must `throw` /
  `precondition`, never silently coerce.
- Intermediate division uses `Decimal`. Convert back to `Int` minor units with
  **round-half-up** at the last possible moment, once per subscription.
- `Double` is never used for money. Not for storage, not for maths, not for display.

## Goal

A goal is user data, not a constant. Every date- or target-dependent calculation in this
document takes a `Goal` as a parameter.

```
Goal {
    id:           UUID
    name:         String        // non-empty after trimming, max 60 chars
    targetDate:   Date          // stored as a calendar date, midnight in the local zone
    targetAmount: Money?        // optional
    createdAt:    Date
    sortIndex:    Int
}
```

Validation rules, all enforced in one place:

- `name` trimmed; empty → invalid. Duplicate names are allowed (they are labels, not keys).
- `targetDate` may be in the past — a missed deadline is information, not a validation
  error. The UI marks it overdue; nothing throws.
- `targetAmount`, when present, must be **> 0** and in the same currency as `config.currency`.
- Exactly one goal is *pinned*. Deleting the pinned goal pins the next one by `sortIndex`;
  deleting the last goal leaves none pinned, and the app returns to the empty state.

## Countdown

```
daysRemaining(now, goal.targetDate, calendar) =
    calendar.dateComponents([.day],
        from: calendar.startOfDay(for: now),
        to:   calendar.startOfDay(for: goal.targetDate)).day!
```

- **Calendar days, not 86,400-second chunks.** Across a DST boundary a day is 23 or 25
  hours; a naive division gets the answer wrong twice a year, which is exactly the kind of
  bug nobody notices until the number is off by one on the day that matters.
- Computed in the user's current calendar and time zone.
- Same day → `0`. Target in the past → negative. The UI shows "today" at `0` and
  "N days over" below it; the calculation itself never clamps.

## MRR

**Definition.** The sum, over all *active* subscriptions, of each subscription's
normalised monthly recurring amount, net of coupon discounts.

### Which subscriptions count

| `subscription.status` | Counted? |
| --- | --- |
| `active` | **yes** |
| `trialing` | only if `config.includeTrials` (default `false`) |
| `past_due`, `unpaid`, `paused` | no |
| `canceled`, `incomplete`, `incomplete_expired` | no |

`cancel_at_period_end == true` still counts while the status is `active` — the money is
still arriving this month. It is surfaced separately as `churnRisk`.

### Which line items count

A subscription item counts when its price is a plain recurring price:

- `price.recurring != nil`
- `price.recurring.usage_type == "licensed"` — metered prices are **excluded**
- `price.billing_scheme == "per_unit"` — tiered prices are **excluded**
- `price.unit_amount != nil`

Every excluded item is recorded in `MRRResult.skipped` with its price id and a reason,
so the number is never quietly wrong. The popover shows a warning when `skipped` is
non-empty.

### Normalising an interval to one month

```
MONTH_DAYS = 365 / 12 = 30.416666…   (Decimal, not Double)

monthly(item) = unit_amount × quantity × factor(interval, interval_count)

factor(month, n) = 1 / n
factor(year,  n) = 1 / (12 × n)
factor(week,  n) = MONTH_DAYS / (7 × n)
factor(day,   n) = MONTH_DAYS / n
```

Worked examples (all in cents, rounded half-up at the end):

| Price | Qty | Monthly |
| --- | --- | --- |
| $10.00 / month | 1 | `1000` |
| $10.00 / month | 3 | `3000` |
| $120.00 / year | 1 | `1000` |
| $99.00 / year | 1 | `825` (9900/12 = 825 exactly) |
| $100.00 / year | 1 | `833` (10000/12 = 833.33 → 833) |
| $30.00 / 3 months | 1 | `1000` |
| $7.00 / week | 1 | `3042` (700 × 30.41666/7 = 3041.66 → 3042) |
| $1.00 / day | 1 | `3042` (100 × 30.41666 = 3041.66 → 3042) |

### Discounts

Applied to the subscription total, after summing its items, before rounding:

```
if coupon.percent_off  → total × (1 − percent_off/100)
if coupon.amount_off   → total − normalise(amount_off, subscription interval)
```

- `amount_off` is per invoice, so it is normalised with the same factor as the
  subscription's own interval.
- A discount can never take a subscription below zero — clamp at `0`.
- `coupon.duration == "once"` and an already-expired `discount.end` → **not applied**.
  A one-off coupon is not recurring revenue.

### Currency

Subscriptions not in `config.currency` are excluded from the total and listed in
`MRRResult.otherCurrencies`. v1 does no FX conversion; it declines to guess.

### Breakdown by product (T09)

- Group item monthly amounts by `price.product` (the product id).
- Product display name comes from `/v1/products`; fall back to the product id.
- Sort descending by amount. Ties broken by product name ascending, so the order is
  deterministic and the tests can assert it.
- Keep the top `n` (default 3); sum the remainder into a single `"Other"` line.
- `"Other"` is omitted entirely when the remainder is zero.

## Earned to date

**Definition.** Net money Stripe has recognised for you, from `config.earningsStartDate`
to now.

```
earned = Σ balanceTransaction.net
         where created ≥ earningsStartDate
           and currency == config.currency
           and type ∉ { payout, payout_cancel, payout_failure, transfer, topup }
```

- `net` is `amount − fee`, so **Stripe fees are already deducted** and refunds appear as
  negative entries. Summing `net` gives the right answer without special-casing either.
- Payouts and transfers are money *moving*, not money *earned*. Including them
  double-counts and then cancels to roughly zero, which is a very confusing bug to find.
- The result can legitimately be negative (a month of refunds). Do not clamp.
- Income tax is not modelled. See [PLAN.md](PLAN.md#3-the-funding-math).

## Projection

**Definition.** Earned to date, plus the MRR that will arrive between now and the goal's
target date, compounded at an assumed monthly growth rate.

```
n = whole months from now to goal.targetDate                    (calendar months)
r = remaining days ÷ days in the month containing targetDate     (0 ≤ r < 1)
g = config.monthlyGrowthRate                                     (0.10 = +10 %/month)

projected = earned + MRR × Σ(i = 0 … n−1) (1+g)ⁱ  +  MRR × (1+g)ⁿ × r
```

With `g = 0` this collapses to `earned + MRR × (n + r)`, which is the default and the
easiest case to reason about.

Worked examples:

| earned | MRR | n | r | g | projected |
| --- | --- | --- | --- | --- | --- |
| $0 | $100 | 12 | 0 | 0 % | $1,200 |
| $500 | $100 | 12 | 0 | 0 % | $1,700 |
| $0 | $100 | 12 | 0.5 | 0 % | $1,250 |
| $0 | $100 | 2 | 0 | 10 % | $210 (100 + 110) |
| $0 | $100 | 3 | 0 | 10 % | $331 (100 + 110 + 121) |

- Target date in the past → `n = 0`, `r = 0`, projection equals earned to date.
- The projection is computed **per goal**, since each goal has its own target date. Earned
  to date and MRR are account-wide and shared across goals.
- `g` is an *assumption the user types*, not a measured trend. v1 does not infer growth
  from history — there is no history yet. Label it in the UI as an assumption.

## Percent funded

Only defined when the goal has a `targetAmount`.

```
percentFunded  = earnedToDate / goal.targetAmount        // where you are
percentOnTrack = projected    / goal.targetAmount        // where you are heading
```

- Both are `Decimal` ratios; the UI renders them as whole percents, rounded half-up.
- `targetAmount` is guaranteed `> 0`, so there is no divide-by-zero case — but the
  calculator asserts it anyway rather than trusting its caller.
- Values above 100 % are **not clamped** in the calculation. Exceeding a goal is worth
  seeing. The progress bar clamps its own width at 100 %; the label does not.
- A negative `earnedToDate` (a refund-heavy period) yields a negative percent. Show it.

## Rounding, once and only once

Round half-up to whole minor units at exactly these points, and nowhere else:

1. Per subscription, after summing its items and applying its discount.
2. Per product line in the breakdown.
3. At the end of the projection.

Rounding in more places accumulates error; rounding in fewer leaves fractional cents in a
value type that claims to be integer. The breakdown lines are rounded independently, so
they may sum to ±1 cent of the MRR total — **display the total from `MRRResult.total`,
never from summing the lines on screen.**
