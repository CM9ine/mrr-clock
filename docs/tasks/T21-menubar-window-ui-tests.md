# T21 · Menu-bar setup window UI regression tests

**Depends on:** T17 · **Milestone:** M5 regression gate

## Goal

Prove the real macOS setup flow is visible and usable when launched from Xcode. T17's
package tests and app build both passed while Goals opened behind Xcode, making **Add your
first goal** appear to do nothing. This task closes that testing gap before T18 adds more
window-triggered behavior.

## Read first

- [T17](T17-goals-settings-ui.md) — the UI and manual checklist being protected
- [TDD.md](../TDD.md) — deterministic test rules
- [ARCHITECTURE.md](../ARCHITECTURE.md) — app/core boundary

## Build

Add a macOS XCUITest target to `MRRClock.xcodeproj` and a launch configuration that starts
the app in deterministic UI-test states without Stripe, Keychain, or existing user data.
The launch configuration must be app-only dependency injection; production behavior stays
on the existing live seams.

The UI test state must support at least:

- a stored-key/no-goals state for the first-goal prompt;
- a loaded snapshot state for the Goals and Settings toolbar buttons.

Use accessibility identifiers for controls and windows rather than display text where
practical. Do not use fixed sleeps. Wait for explicit existence, visibility, focus, and
hittability conditions with a bounded timeout.

## Tests

`MRRClockUITests/SetupWindowTests.swift`, run in order:

1. **`add first goal opens a visible Goals window`** — launch in stored-key/no-goals
   state, open the menu-bar extra, click **Add your first goal**, then assert that a Goals
   window exists, is frontmost, and remains visible after the menu-bar popover dismisses.
2. **`plus opens a focused goal editor`** — from the Goals window, click **+**; the goal
   editor exists, its name field has keyboard focus, and Save is disabled.
3. **`Goals button raises an existing Goals window`** — launch loaded, open Goals, place
   another app/window in front, invoke Goals again, and assert the existing Goals window
   becomes frontmost rather than creating a duplicate.
4. **`Settings button opens a usable Settings window`** — launch loaded, click the gear;
   Settings remains visible after the popover dismisses and its non-secret controls are
   hittable.
5. **`reopening Settings raises one window`** — invoke Settings twice; exactly one Settings
   window exists and is frontmost.

## Verification

- Run the UI-test target from Xcode on **My Mac** and with `xcodebuild test`; all five tests
  must pass from a clean launch.
- Run `swift test`; the entire core suite must remain green.
- Run the app from Xcode and repeat tests 1, 2, and 4 with computer control. Record the
  observed window names and focused control in the issue report.

## Manual checklist — in the commit body

- [ ] With Xcode frontmost, Add your first goal brings Goals in front of Xcode
- [ ] The menu-bar popover disappearing does not close the Goals or Settings window
- [ ] Clicking + immediately shows the editor with the name field focused
- [ ] Goals and Settings each reuse one window when invoked repeatedly

## Done when

- All five UI tests pass without sleeps, network, Keychain, or user-data dependencies.
- The full core suite passes.
- The computer-control verification is recorded on issue #21.
- Tick T21 in `docs/TASKS.md`, commit with subject `T21: ...`, push, and close issue #21.

## Out of scope

Refresh scheduling and launch at login (T18); release packaging (T19); redesigning the
popover or goal editor; testing Stripe over the network.
