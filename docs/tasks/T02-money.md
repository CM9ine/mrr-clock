# T02 · `Money` — integer minor units

**Depends on:** T01 · **Milestone:** M1

## Goal

One value type for every amount in the app. Integer cents, explicit currency, no `Double`
anywhere near it.

## Read first

- [METRICS.md § Money representation](../METRICS.md#money-representation)

## Build

`Sources/MRRClockCore/Money.swift`

```swift
public struct Money: Equatable, Hashable, Codable, Sendable {
    public let amount: Int        // minor units — cents
    public let currency: String   // lowercase ISO-4217, e.g. "usd"
}
```

- `init(_ amount: Int, _ currency: String)` — lowercases the currency
- `+`, `-`, unary `-`; `precondition` on mismatched currency
- `*(Int)` for quantity
- `static func from(_ decimal: Decimal, _ currency: String) -> Money` — round half-up
- `var isZero`, `static func zero(_ currency: String)`
- `func formatted(locale:) -> String` — `$1,240.00` style, via `NumberFormatter` `.currency`

## Tests

`Tests/MRRClockCoreTests/MoneyTests.swift`

1. **`init lowercases the currency code`** — `Money(100, "USD").currency == "usd"`.
2. **`adding two amounts in the same currency sums the minor units`** —
   `Money(1000,"usd") + Money(250,"usd") == Money(1250,"usd")`.
3. **`subtracting can produce a negative amount`** —
   `Money(100,"usd") - Money(250,"usd") == Money(-150,"usd")`.
4. **`multiplying by a quantity scales the amount`** —
   `Money(1000,"usd") * 3 == Money(3000,"usd")`.
5. **`from(decimal:) rounds half up`** — parameterised over
   `(0.5 → 1)`, `(1.5 → 2)`, `(2.4 → 2)`, `(2.6 → 3)`, `(-0.5 → -1)`, `(833.33 → 833)`,
   `(3041.66 → 3042)`. Values are `Decimal` minor units.
6. **`from(decimal:) is exact for values that need no rounding`** —
   `Decimal(1000) → 1000`.
7. **`zero is zero in the given currency`** — `Money.zero("gbp") == Money(0,"gbp")`
   and `.isZero` is true.
8. **`round-trips through Codable`** — encode then decode yields an equal value.
9. **`formats US dollars with a symbol and thousands separator`** —
   `Money(124000,"usd").formatted(locale: Locale(identifier: "en_US")) == "$1,240.00"`.
10. **`formats a negative amount`** — `Money(-500,"usd")` in `en_US` → `"-$5.00"`.

Also verify the currency guard, in whichever form the implementation takes:

11. **`adding different currencies traps`** — if `+` uses `precondition`, cover it with a
    documented comment and skip the test (Swift Testing cannot catch a trap); if it is
    implemented as `throws`, assert the error is thrown. **Pick `throws` if in doubt** —
    a testable failure beats an untestable one.

## Done when

All tests pass, `swift test` green, and no `Double` appears in `Money.swift`.

## Out of scope

Currency conversion. Formatting for currencies other than the user's own.
