# T23 · Restore inspectable Application Support storage

**Depends on:** T12, T13, T21 · **Milestone:** M5

**Blocks:** T18

## Goal

Make the production app honour the storage contract in `ARCHITECTURE.md`: user-authored
goals and the last snapshot live at directly readable, backup-able paths under
`~/Library/Application Support/MRRClock`, not only inside the app sandbox container.

## Evidence

T17 manual acceptance on 10 September 2026 found no file at the documented location.
The running sandboxed app instead wrote:

```text
~/Library/Containers/com.mrrclock.app/Data/Library/Application Support/MRRClock/goals.json
~/Library/Containers/com.mrrclock.app/Data/Library/Application Support/MRRClock/snapshot.json
```

This contradicts `ARCHITECTURE.md` and prevents the T17 requirement that `goals.json` be
directly inspectable and hand-editable. Snapshot location must be corrected at the same
time because T18 uses its modification age for wake refreshes.

## Read first

- [T12](T12-goals.md) — atomic goal persistence
- [T13](T13-snapshot-cache.md) — snapshot persistence and corruption recovery
- [T17](T17-goals-settings-ui.md) — failed manual storage check
- [T18](T18-scheduling-launch.md) — snapshot-age consumer blocked by this task
- [TDD.md](../TDD.md) — test-first rules
- [ARCHITECTURE.md § Storage](../ARCHITECTURE.md#storage) — authoritative paths

## Build

Relevant files:

- `Sources/MRRClockCore/StorageLocations.swift` — one injected resolver for production and
  test storage roots
- `Sources/MRRClockCore/GoalStore.swift`
- `Sources/MRRClockCore/SnapshotCache.swift`
- `App/MRRClockApp.swift`
- `App/MRRClock.entitlements`
- `MRRClock.xcodeproj/project.pbxproj`
- `Tests/MRRClockCoreTests/StorageLocationsTests.swift`
- `Tests/MRRClockCoreTests/FileGoalStoreTests.swift`
- `Tests/MRRClockCoreTests/SnapshotCacheTests.swift`

Requirements:

- Production paths are exactly:
  - `~/Library/Application Support/MRRClock/goals.json`
  - `~/Library/Application Support/MRRClock/snapshot.json`
- Resolve the home/Application Support root once behind an injectable core seam. Both
  stores must use the same directory; do not embed path construction in two implementations.
- Preserve atomic writes and corrupt-file recovery from T12 and T13.
- Update the app sandbox/signing configuration deliberately so the production executable
  can honour the documented path. Do not add a broad temporary file exception or silently
  redefine the documented location as the container path.
- If files already exist in the legacy container location, migrate them without overwriting
  newer destination data. Migration must be idempotent and must not delete the only readable
  copy until the destination has been written successfully.
- Tests use temporary directories only. They must not read or modify the developer's real
  Application Support directory.

## Tests

`Tests/MRRClockCoreTests/StorageLocationsTests.swift`

1. **`production directory is MRRClock under user Application Support`** — injected home
   `/Users/example` resolves to `/Users/example/Library/Application Support/MRRClock`.
2. **`goal and snapshot URLs share the production directory`** — filenames are exactly
   `goals.json` and `snapshot.json` under that directory.

Existing file-store suites, extended test-first:

3. **`goal store uses the injected storage directory`** — save writes only
   `<temporary>/MRRClock/goals.json`.
4. **`snapshot cache uses the injected storage directory`** — save writes only
   `<temporary>/MRRClock/snapshot.json`.
5. **`migrates legacy goals when the destination is absent`** — the destination decodes to
   the exact legacy `GoalFile`.
6. **`migrates the legacy snapshot when the destination is absent`** — the destination
   decodes to the exact legacy `Snapshot`.
7. **`does not overwrite an existing destination during migration`** — destination bytes
   remain unchanged when both locations contain data.
8. **`migration is idempotent`** — running it twice produces the same destination and no
   duplicate or corrupt files.
9. **`failed migration preserves the legacy file`** — an injected destination write failure
   leaves the original bytes readable.
10. **`existing atomic-write and corruption-recovery tests remain green`** for both stores.

Run every new test red before implementation, followed by the complete `swift test` suite
and the `MRRClockUITests` scheme because entitlement changes affect app launch.

## Manual checklist

- [ ] Add a goal in a normal production-configured Debug build; quit the app and verify
      `~/Library/Application Support/MRRClock/goals.json` is readable JSON matching the UI.
- [ ] Relaunch and confirm the same goal appears.
- [ ] Complete one refresh and verify
      `~/Library/Application Support/MRRClock/snapshot.json` is readable JSON.
- [ ] Start with data only in the legacy container location; launch once and confirm both
      data sets migrate without loss.
- [ ] Confirm the built app still makes outbound Stripe requests and passes signing checks.

## Out of scope

Changing JSON schemas, changing Keychain storage, scheduling refreshes (T18), or release
packaging (T19).
