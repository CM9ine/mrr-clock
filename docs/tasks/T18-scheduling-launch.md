# T18 · Auto-refresh scheduling and launch at login

**Depends on:** T17, T21 · **Milestone:** M5

## Goal

The app keeps itself up to date without being asked, and starts with the machine. This is
what turns it from a tool you open into a number you glance at.

## Read first

- [ARCHITECTURE.md § State machine](../ARCHITECTURE.md#state-machine)

## Build

`Sources/MRRClockCore/RefreshScheduler.swift` — the logic, in the package, testable:

```swift
public protocol SchedulerDriver: Sendable {           // wraps Timer
    func schedule(after: TimeInterval, _ work: @escaping @Sendable () async -> Void)
    func cancel()
}

public actor RefreshScheduler {
    init(coordinator: RefreshCoordinator, driver: SchedulerDriver,
         clock: Clock, config: Config)
    func start(); func stop()
    func intervalChanged(to: TimeInterval)
    func systemDidWake()
    func networkDidReturn()
}
```

Behaviour:

- Refresh every `config.refreshInterval` (default 15 min, floor 5 min)
- **Back off on failure**: 1× → 2× → 4×, capped at 1 hour; reset on success
- Honour `Retry-After` from a 429 when it is longer than the next scheduled interval
- Refresh on wake from sleep if the snapshot is older than the interval
  (`NSWorkspace.didWakeNotification`)
- Refresh when the network comes back (`NWPathMonitor`)
- Never run two refreshes at once — the coordinator already collapses them (T14 test 20)

App layer: `SMAppService.mainApp.register()` / `.unregister()` for launch at login, bound
to the Settings toggle, with the real system state read back on appear so the toggle
cannot lie.

## Tests

`Tests/MRRClockCoreTests/RefreshSchedulerTests.swift`, with a `FakeSchedulerDriver` that
records requested delays and fires on command. **No real timers, no sleeping.**

1. **`refreshes once on start`** — API call count 1.
2. **`schedules the next refresh at the configured interval`** — driver was asked for
   900 s.
3. **`refreshes again when the timer fires`** — fire the driver → call count 2.
4. **`enforces a five minute floor`** — interval 60 → driver asked for 300.
5. **`stops scheduling after stop`** — firing the driver afterwards does nothing.
6. **`reschedules when the interval changes`** — change to 1800 → next delay 1800, and
   the previous timer was cancelled.
7. **`backs off after a failure`** — fail → next delay 1800; fail again → 3600;
   fail again → 3600 (capped).
8. **`resets the backoff after a success`** — fail, fail, succeed → next delay 900.
9. **`honours a longer Retry-After`** — 429 with `Retry-After: 3600` → next delay 3600.
10. **`ignores a Retry-After shorter than the interval`** — 429 with `Retry-After: 5` →
    next delay 900.
11. **`refreshes on wake when the snapshot is stale`** — snapshot 20 minutes old,
    `systemDidWake()` → call count increments.
12. **`does not refresh on wake when the snapshot is fresh`** — 2 minutes old → no call.
13. **`refreshes when the network returns after a failure`** — phase `.stale`,
    `networkDidReturn()` → a refresh runs.
14. **`does not refresh when the network returns while already loaded and fresh`**.
15. **`does not refresh at all while in needsSetup`** — no key → the timer runs but makes
    zero API calls. Do not hammer Stripe with a key you do not have.

**Manual checklist** — in the commit body:

- [ ] Leave the app open 20 minutes; the sync time updates on its own
- [ ] Sleep the machine for 30 minutes, wake it — numbers refresh within a few seconds
- [ ] Turn Wi-Fi off, wait for a failure, turn it back on — it recovers without a click
- [ ] Toggle launch at login, log out and back in — the app starts
- [ ] Toggle it off, check System Settings › General › Login Items — it is gone

## Out of scope

Release packaging (T19).
