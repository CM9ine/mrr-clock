# T22 · Goal drag reordering regression

**Depends on:** T17, T21 · **Milestone:** M5

**Blocks:** T18

## Goal

Restore the T17 acceptance contract that goals can be reordered by dragging on macOS and
that the new order survives an app relaunch. The core `GoalStore.move` behaviour already
exists; this task owns only the SwiftUI-to-store interaction and its UI regression coverage.

## Evidence

T17 manual acceptance on 10 September 2026 created two real goals and attempted to drag
the second above the first multiple times. The visible order never changed. Both goals
otherwise persisted across a stop and relaunch.

## Read first

- [T12](T12-goals.md) — `GoalStore.move` and persistence semantics
- [T17](T17-goals-settings-ui.md) — the original UI and manual acceptance contract
- [T21](T21-menubar-window-ui-tests.md) — the macOS UI-test seam and launch states
- [TDD.md](../TDD.md) — test-first rules
- [ARCHITECTURE.md](../ARCHITECTURE.md) — app/core ownership boundary

## Build

Relevant files:

- `App/GoalListView.swift`
- `App/MRRClockApp.swift` — only the deterministic UI-test dependency seam, if required
- `MRRClockUITests/GoalReorderingUITests.swift`
- `MRRClock.xcodeproj/project.pbxproj` and the shared UI-test scheme — only if the new test
  file is not already discovered automatically

Requirements:

- A user can drag any goal row to a new position in the normal macOS Goals window.
- The UI calls `GoalStore.move(from:to:)`; do not duplicate ordering logic in the app layer.
- The visible list updates immediately after the drop.
- The resulting contiguous `sortIndex` values are persisted, and a fresh app process shows
  the same order.
- Add stable accessibility identifiers or actions needed to drive the rows without relying
  on goal names or screen coordinates.
- UI-test data must be deterministic, isolated from the user's real goals, and use no
  network, secrets, sleeps, or wall-clock `Date()` calls.

## Tests

`MRRClockUITests/GoalReorderingUITests.swift`

1. **`dragging the last goal to the first position updates the visible order`** — seed
   `[Alpha, Beta, Gamma]`, drag Gamma before Alpha, then assert the rows read
   `[Gamma, Alpha, Beta]`.
2. **`dragging persists contiguous sort indices`** — after the same move, inspect the
   isolated persisted `goals.json`; names are `[Gamma, Alpha, Beta]` and `sortIndex` values
   are exactly `[0, 1, 2]`.
3. **`dragged order survives relaunch`** — terminate the app, relaunch against the same
   isolated test store, and assert the visible rows remain `[Gamma, Alpha, Beta]`.
4. **`pin identity survives a reorder`** — seed Alpha as pinned, move Gamma before Alpha,
   and assert Alpha remains pinned.

Run each new UI test red before changing the implementation. Then run the whole package
suite and the complete `MRRClockUITests` scheme.

## Manual checklist

- [ ] In a normal Xcode-launched Debug build, create three goals and drag the last above
      the first; the row moves immediately.
- [ ] Quit and relaunch; the new order remains.
- [ ] The pinned marker stays on the same goal after the reorder and relaunch.

## Out of scope

Changing core ordering semantics, redesigning goal rows, keyboard-only reordering, or
changing storage locations (T23).
