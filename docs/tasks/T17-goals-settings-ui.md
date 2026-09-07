# T17 · Goals UI and Settings

**Depends on:** T16 · **Milestone:** M5

## Goal

Where the user actually configures things: add and edit goals, paste the Stripe key, set
the growth assumption. **This is the task that makes the app general instead of personal.**

## Read first

- [T12](T12-goals.md) — the store this UI drives
- [STRIPE.md § Handling rules](../STRIPE.md#handling-rules)

## Build

`App/GoalListView.swift`

- List of goals: name, target date, days remaining, a pin marker
- **+** to add · swipe or ⌫ to delete (with a confirmation) · drag to reorder
- Click a row to edit

`App/GoalEditorView.swift`

- Name field, `DatePicker` (`.graphical`, day precision), optional amount field
- Amount input parsed into `Money` minor units — accepts `50,000`, `50000`, `$50,000`
- Live validation message from `Goal.validate`; **Save disabled while invalid**
- Live preview under the fields: "387 days · projected $34,200 · 62 % funded", recomputed
  as the date changes, using cached revenue and **no network**

`App/SettingsView.swift`

- **Stripe key**: secure field; shows `rk_live_••••2f9c` once saved, with *Replace* and
  *Remove*. On save, validate the format (T07) and then verify it with one live call —
  a green tick or the actual Stripe error, immediately, not at the next refresh.
- **Earnings start date**, **monthly growth rate** (percent stepper), **refresh interval**,
  **menu bar title format** (with a live preview of each), **include trials**,
  **launch at login** (T18)
- A "first goal" prompt on first run, prefilled with nothing — no default date, no default
  name. Every goal is typed in the same way; none is special-cased.

## Tests

Logic lives in the package and is tested there; the views are checked by hand.

`Tests/MRRClockCoreTests/AmountParsingTests.swift`

1. **`parses a plain number`** — `"50000"` → `Money(5000000,"usd")` ($50,000).
2. **`parses decimals`** — `"1234.56"` → `123456`.
3. **`ignores grouping separators`** — `"50,000"` and `"50 000"` → `5000000`.
4. **`ignores a leading currency symbol`** — `"$50,000"` → `5000000`.
5. **`rejects junk`** — `""`, `"abc"`, `"1.2.3"`, `"-"` → `nil`.
6. **`rounds beyond two decimal places half up`** — `"1.005"` → `101`.
7. **`parses in a comma-decimal locale`** — `"1.234,56"` in `de_DE` → `123456`.

`Tests/MRRClockCoreTests/GoalEditorModelTests.swift`

8. **`reports validation errors as the user types`** — empty name → a message; typing a
   name clears it.
9. **`disables save while invalid`** — `canSave == false` for an empty name and for a
   zero amount.
10. **`previews the countdown for the entered date`** — a date 10 days out → "10 days".
11. **`previews the projection for the entered date`** — matches `Projection` for the same
    inputs.
12. **`previews without a target amount`** — percent is `"—"`, not a crash.
13. **`editing an existing goal starts from its current values`**.
14. **`the preview never calls the API`** — call count stays 0 across 20 keystrokes.

`Tests/MRRClockCoreTests/KeyVerificationTests.swift`

15. **`accepts a working key`** — fake returns data → `.verified`.
16. **`reports a rejected key`** — 401 → `.rejected("…")`, and the key is **not** saved.
17. **`reports a key that is missing a permission`** — 403 → the message names the
    resource.
18. **`saves the key only after verification succeeds`** — key store write count is 0 on
    failure, 1 on success.
19. **`shows only the last four characters once saved`** — display string for
    `"rk_live_abcdef2f9c"` is `"rk_live_••••2f9c"`, and contains no other part of the key.

**Manual checklist** — in the commit body:

- [ ] Add a goal, quit, relaunch — it is still there
- [ ] Add a second goal, pin it, quit, relaunch — the pin survived
- [ ] Delete the pinned goal — the next one pins, no crash
- [ ] Reorder by dragging — the order survives a relaunch
- [ ] A goal with a past date shows as overdue, not as an error
- [ ] Paste a **secret** key (`sk_`) — it is refused with a clear reason
- [ ] Paste a wrong restricted key — the error appears immediately on Save
- [ ] `~/Library/Application Support/MRRClock/goals.json` is readable and matches the UI
- [ ] No date or amount is prefilled on first run

## Out of scope

Scheduling and launch at login (T18).
