# MRRClock — Plan

## 1. What it is

A macOS menu bar app that tracks **goals you configure** against **live revenue from
Stripe**. A goal is a name, a target date, and optionally a target amount. The app shows
how long is left, what you are earning, and where the current rate lands you by the date.

**Nothing about a goal is hardcoded.** Dates, amounts and names are entered in the app,
stored on disk, and editable at any time. You can keep several goals and pin one to the
menu bar.

## 2. The worked example

The docs and tests need one concrete goal to reason about. Throughout, that is:

| Field | Value |
| --- | --- |
| Name | Buy a house |
| Target date | 2027-09-29 |
| Target amount | *(set by the user)* |

From a "today" of **7 September 2026** that is **387 days**, ≈ **12.7 months**,
≈ **55 weeks** — the number that appears in the T03 and T11 test expectations.

It is an example, not a setting. A goal is *data*: entered in the app, stored in
`goals.json`, edited whenever. "$2k MRR by June" or "conference ticket by March" sits
alongside it, and every calculation takes the goal as a parameter.

> Your own targets — the amounts, the dates that actually matter to you — belong in
> `MY-GOALS.local.md`, which is gitignored. Keep them out of this file; this one is public.

## 3. Why an app at all

A deadline you have to go and look up is a deadline you forget. A number in the menu bar
is a number you see two hundred times a day. The app exists to make one trade visible in
the moment you are making it: *this hour, spent this way, moves or does not move the
number.*

Four numbers, always on for the pinned goal:

- **Countdown** — days left. Non-negotiable once the date is set.
- **MRR** — the rate. The only lever you control day to day.
- **Projected by the target date** — where the current rate lands you. The feedback loop.
- **% funded** — projection against the goal's target amount, when one is set.

## 4. Sizing a goal

A goal's `targetAmount` is optional. With one set, the app shows **% funded** and a
progress bar; without one, it shows the countdown, MRR, earned and projection only. Either
is a valid goal — a date with no number is still a deadline.

Sizing one is arithmetic you do once, outside the app, and then type in: for a house
deposit, that is *(price × deposit %) − already saved − other income*; for a revenue
target it is simply the number. Whatever the sum, the result is a single figure the app
treats as opaque.

### What ~12.7 months of compounding actually produces

Cumulative net revenue over the example window, starting at MRR `M₀` and growing `g` per
month, using n = 12 whole months and a final partial month of 22/30
(formula in [METRICS.md](METRICS.md#projection)):

| Starting MRR | Growth | Cumulative | MRR at the end |
| --- | --- | --- | --- |
| $200 | 10 %/mo | $4,737 | $628 |
| $500 | 10 %/mo | $11,843 | $1,569 |
| $500 | 15 %/mo | $16,463 | $2,675 |
| $1,000 | 10 %/mo | $23,686 | $3,138 |
| $1,000 | 15 %/mo | $32,925 | $5,350 |
| $2,000 | 10 %/mo | $47,372 | $6,277 |

Illustrative figures, not anyone's forecast. Read the table as a starting-line problem
rather than a growth-rate problem: doubling `M₀` doubles the cumulative total, while
adding five points of monthly growth adds ~40 %. **Getting to a paying baseline early
beats optimising the curve later** — every month spent at $0 MRR is a month permanently
removed from the top of that sum.

These figures are gross of income tax and net of Stripe fees. The app reports Stripe *net*
(after processing fees) and does not model tax.

## 5. Scope

### In scope (v1)

- **Goals** — add, edit, delete, reorder; name + target date + optional target amount
- **Pin one goal** to the menu bar; switch between goals in the popover
- Menu bar item with a configurable compact title
- Popover: countdown, MRR, earned to date, projection, % funded, per-product breakdown
- Stripe read-only sync via a restricted key in the macOS Keychain
- Local JSON cache so the numbers survive restart and offline
- Settings: key, earnings start date, growth assumption, refresh interval, title format
- Auto-refresh on a timer, manual refresh, launch at login

### Out of scope (v1)

Multiple Stripe accounts · multi-currency conversion · charts and history · notifications ·
App Store distribution · iOS/watch companion · non-Stripe revenue sources · tax modelling ·
per-goal revenue attribution (all goals read the same account-wide MRR) · goal templates ·
sync between machines

Out-of-scope items are *deliberately deferred*, not rejected. Nothing in the
architecture blocks them; see [ARCHITECTURE.md](ARCHITECTURE.md#extension-points).

## 6. Milestones

| # | Milestone | Tasks | Done when |
| --- | --- | --- | --- |
| M1 | Foundation | T01–T03 | `swift test` runs green; Money and Countdown are correct |
| M2 | Stripe layer | T04–T07 | Live and fake clients both fetch, paginate, and fail cleanly |
| M3 | The numbers | T08–T11 | MRR, breakdown, earned, projection all computed from fixtures |
| M4 | Goals & state | T12–T15 | Goals persist; a `Snapshot` is produced, cached, formatted |
| M5 | The app | T16–T18 | It sits in the menu bar with real numbers and refreshes itself |
| M6 | Ship | T19 | Signed release build launching at login on your own machine |

**M1–M4 are pure Swift with no UI and no network.** That is roughly 70 % of the work and
100 % of the risk of being subtly wrong about money or dates, and it is all unit-testable.
The UI on top is thin by design.

## 7. Working agreement

- **TDD, strictly.** Red, green, refactor. Rules in [TDD.md](TDD.md).
- **One task per session.** Each task file is a complete brief; the agent needs no
  other context beyond the docs it names.
- **No task is done until its tests pass and `swift test` is green overall.**
- Money is integer minor units end to end. Never `Double` for money.
- Every calculation takes its inputs explicitly — clock, goal, config, data. No hidden
  globals, no `Date()` inside a calculator. This is what makes the tests deterministic.
- **No goal data in the source.** No hardcoded 2027-09-29, no hardcoded amount, anywhere
  outside a test fixture or the seed value offered on first launch. A grep for `2027`
  in `Sources/` should return nothing.

## 8. The first thing to do after this plan

Not T01. **Size your first goal** in `MY-GOALS.local.md` — the real number, worked out
once — so that the goal you type in on launch day has a target amount in it. A countdown
to a target you have not sized is a screensaver.
