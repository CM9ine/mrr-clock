# T03 · `Countdown` — calendar-day maths

**Depends on:** T01 · **Milestone:** M1

## Goal

Days remaining to **a target date supplied by the caller**, correct across DST and time
zones. This is the number on screen most of the time; being off by one is not acceptable.

The target is always a parameter. `Countdown` knows nothing about goals, houses, or 2027 —
those live in user data (T12) and arrive here as a `Date`.

## Read first

- [METRICS.md § Countdown](../METRICS.md#countdown)

## Build

`Sources/MRRClockCore/Countdown.swift`

```swift
public struct Countdown: Sendable {
    public static func daysRemaining(
        now: Date, target: Date, calendar: Calendar = .current
    ) -> Int
}
```

Also a `Clock` protocol here — `SystemClock` (live) and `FixedClock(at:)` (tests) — since
this is the first task that needs the current time.

Implementation: difference in `.day` between `calendar.startOfDay(for: now)` and
`calendar.startOfDay(for: target)`. **Do not divide a `timeIntervalSince` by 86400.**

## Tests

`Tests/MRRClockCoreTests/CountdownTests.swift`

Pin a calendar with an explicit time zone in every test. Add a small
`Date(iso: String)` helper in `Support/`.

1. **`counts the days between two dates`** — now `2026-09-07T09:00:00Z`,
   target `2027-09-29T00:00:00Z`, UTC → **387**. (The worked example from
   [PLAN.md §2](../PLAN.md#2-the-worked-example), used here as test data only.)
2. **`the same calendar day is zero days`** — now `2027-09-29T00:01:00Z`,
   target `2027-09-29T23:59:00Z` → **0**.
3. **`time of day does not matter`** — now at `23:59` and now at `00:01` on the same day
   give the same result for the same target.
4. **`a past target is negative`** — now `2027-10-01`, target `2027-09-29` → **-2**.
5. **`tomorrow is one day`** → **1**.
6. **`spring forward is still one calendar day`** — America/New_York, now
   `2027-03-13T12:00` local, target `2027-03-14T12:00` local (a 23-hour day) → **1**.
   A seconds-based implementation returns 0 here; this test is the reason the task exists.
7. **`autumn back is still one calendar day`** — America/New_York, now
   `2027-11-06T12:00` local, target `2027-11-07T12:00` local (a 25-hour day) → **1**.
8. **`counts in the supplied time zone, not UTC`** — now `2026-09-07T23:00:00-07:00`
   (still the 7th in Los Angeles, already the 8th in UTC), target `2026-09-10`,
   calendar in America/Los_Angeles → **3**.
9. **`crosses a leap day correctly`** — now `2028-02-28`, target `2028-03-01` → **2**
   (2028 is a leap year).
10. **`FixedClock returns the instant it was given`**. `SystemClock` is the sole
    production adapter allowed to call `Date()`; no live-clock comparison belongs in tests.

## Done when

All ten pass; `86400` does not appear in the source, and neither does any literal date.

## Out of scope

Formatting ("387 days", "1 year 22 days") — that is T15.
