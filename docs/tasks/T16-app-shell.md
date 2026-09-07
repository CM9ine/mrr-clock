# T16 · Xcode shell, `MenuBarExtra`, popover

**Depends on:** T14, T15 · **Milestone:** M5

## Goal

The app appears in the menu bar and shows real numbers. The first task with a UI, and
deliberately the thinnest.

## Read first

- [ARCHITECTURE.md § Layout](../ARCHITECTURE.md#layout)

## Build

An Xcode app target in `App/`, with the local `MRRClockCore` package as a dependency:

- `Info.plist`: `LSUIElement = true` — menu bar only, no Dock icon, no main window
- Deployment target macOS 14
- App Sandbox on, with the **outgoing network** entitlement and Keychain access

```swift
@main struct MRRClockApp: App {
    @StateObject private var state = AppState()
    var body: some Scene {
        MenuBarExtra(state.title) { PopoverView().environmentObject(state) }
            .menuBarExtraStyle(.window)
    }
}
```

`AppState` is an `@MainActor ObservableObject` that owns the `RefreshCoordinator` and
republishes its phase. It **contains no logic** — every string comes from
`MenuBarFormatter`, every number from `Snapshot`.

`PopoverView` renders the pinned goal:

```
Buy a house                              ▾   ← goal switcher
29 Sep 2027 · 387 days                       ← Countdown
──────────────────────────────────────
MRR              $1,240 /mo
Earned to date  $18,430
Projected       $34,200
────────────────────────  62% ───────        ← only when targetAmount is set
Aurora  $820   Beacon  $310   Other  $110
──────────────────────────────────────
⚠ 1 metered price not counted                ← only when warnings exist
Synced 2m ago            ↻   Goals   ⚙︎
```

The `▾` switcher lists goals and pins the one chosen.

Each phase gets its own view: `.needsSetup` → "Add your Stripe key"; `.noGoals` →
"Add your first goal"; `.stale` → the numbers, dimmed, with the error and a Retry.

## Tests

UI is verified by hand — but everything it *displays* was already tested in T15, and
everything it *does* in T14. Two things here still get unit tests:

`Tests/MRRClockCoreTests/AppStateTests.swift` (if `AppState` lives in the package; move it
there if that is what it takes to test it)

1. **`publishes the title for the current phase`** — set each phase, assert `title`
   matches `MenuBarFormatter` for that phase.
2. **`publishes a view model per goal, pinned first`**.
3. **`exposes warnings only when the snapshot has them`**.
4. **`switching the pinned goal updates the title without a network call`** — API call
   count unchanged.

**Manual checklist** — tick each, in the commit body:

- [ ] Icon appears in the menu bar on launch; no Dock icon, no window
- [ ] Numbers appear from cache within ~100 ms of launch, before the network returns
- [ ] Popover opens on click and closes on click-outside and on Escape
- [ ] Layout is correct in light and dark mode
- [ ] Layout is correct with the largest accessibility text size
- [ ] The goal switcher lists every goal and changes the pinned one
- [ ] Turning off Wi-Fi and clicking ↻ shows stale numbers plus an error, **not** zeroes
- [ ] Title is legible next to a full menu bar on a 13" screen

## Out of scope

Settings and goal editing (T17). Timers (T18).
