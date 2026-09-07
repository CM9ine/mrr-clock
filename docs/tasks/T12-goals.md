# T12 · `Goal` and `GoalStore`

**Depends on:** T02, T03 · **Milestone:** M4

## Goal

Goals as user data: add, edit, delete, reorder, pin, persist. **This is the task that keeps
every date and target out of the source code.**

## Read first

- [METRICS.md § Goal](../METRICS.md#goal)
- [ARCHITECTURE.md § Storage](../ARCHITECTURE.md#storage)

## Build

`Sources/MRRClockCore/Goal.swift`

```swift
public struct Goal: Identifiable, Equatable, Codable, Sendable {
    public let id: UUID
    public var name: String
    public var targetDate: Date
    public var targetAmount: Money?
    public let createdAt: Date
    public var sortIndex: Int
}

public enum GoalValidation: Equatable {
    case valid
    case emptyName
    case nameTooLong          // > 60 characters after trimming
    case nonPositiveAmount
    case currencyMismatch(expected: String, got: String)
}

public static func validate(name:targetAmount:config:) -> GoalValidation
```

`Sources/MRRClockCore/GoalStore.swift`

```swift
public protocol GoalStorage: Sendable {
    func load() throws -> GoalFile
    func save(_ file: GoalFile) throws
}
public struct GoalFile: Codable { var goals: [Goal]; var pinnedGoalID: UUID? }

public final class GoalStore {
    init(storage: GoalStorage, clock: Clock)
    var goals: [Goal] { get }              // always sorted by sortIndex
    var pinned: Goal? { get }
    func add(name:targetDate:targetAmount:) throws -> Goal
    func update(_ goal: Goal) throws
    func delete(id: UUID) throws
    func move(from: IndexSet, to: Int) throws
    func pin(id: UUID) throws
}
```

Rules:

- `add` assigns `sortIndex = goals.count`, `createdAt = clock.now`, and **pins the goal if
  it is the first one**.
- `delete` on the pinned goal pins the next goal by `sortIndex`; deleting the last goal
  leaves `pinnedGoalID == nil`.
- `move` renumbers `sortIndex` contiguously from 0.
- Every mutation persists immediately. A crash must not lose a goal.
- A past `targetDate` is **valid** — see METRICS.md. Only names and amounts can be invalid.

`FileGoalStore` writes `goals.json` atomically (temp file + `replaceItem`), pretty-printed
so it can be read and edited by hand.

## Tests

`Tests/MRRClockCoreTests/GoalTests.swift` — **validation**

1. **`accepts a goal with a name and a date`** — `.valid`.
2. **`accepts a goal with no target amount`** — `nil` amount → `.valid`.
3. **`rejects an empty name`** — `""` and `"   "` → `.emptyName`.
4. **`trims whitespace from the name`** — `"  Buy a house  "` stores as `"Buy a house"`.
5. **`rejects a name over sixty characters`** — 61 chars → `.nameTooLong`; 60 → `.valid`.
6. **`rejects a zero or negative target amount`** — `Money(0,"usd")` and
   `Money(-100,"usd")` → `.nonPositiveAmount`.
7. **`rejects a target amount in the wrong currency`** — config `usd`, amount `gbp` →
   `.currencyMismatch(expected: "usd", got: "gbp")`.
8. **`accepts a target date in the past`** — `.valid`. A missed deadline is data, not an
   input error.
9. **`round-trips through Codable`** — a goal with an amount and one without both survive
   encode/decode unchanged.

`Tests/MRRClockCoreTests/GoalStoreTests.swift` — **behaviour**, against `InMemoryGoalStore`

10. **`starts with no goals and nothing pinned`** — `goals.isEmpty`, `pinned == nil`.
11. **`adds a goal`** — one goal, name and date as supplied.
12. **`pins the first goal automatically`** — `pinned?.id` equals the added goal's id.
13. **`does not re-pin when a second goal is added`** — pinned stays the first.
14. **`assigns increasing sort indices`** — three goals → `[0, 1, 2]`.
15. **`returns goals sorted by sort index`** — seed storage with indices `[2, 0, 1]`;
    `goals` comes back in `[0, 1, 2]` order.
16. **`updates a goal in place`** — change name and date; count stays 1, id unchanged.
17. **`rejects an update that fails validation`** — renaming to `""` throws and the stored
    goal is unchanged.
18. **`deletes a goal`** — 2 goals, delete 1 → 1 remains.
19. **`pins the next goal when the pinned one is deleted`** — goals A(pinned) and B;
    delete A → `pinned?.id == B.id`.
20. **`leaves nothing pinned when the last goal is deleted`** — `pinned == nil`.
21. **`deleting an unknown id does nothing`** — no throw, count unchanged.
22. **`pins an existing goal on request`** — pin B while A is pinned → `pinned == B`.
23. **`pinning an unknown id throws`**.
24. **`reorders goals and renumbers contiguously`** — `[A, B, C]`, move C to index 0 →
    order `[C, A, B]` with indices `[0, 1, 2]`.
25. **`persists every mutation immediately`** — after each of add / update / delete /
    move / pin, a **new** `GoalStore` over the same storage sees the change. Assert the
    storage's `saveCount` incremented on each.

`Tests/MRRClockCoreTests/FileGoalStoreTests.swift` — real files, in a temp directory
created per test and removed in teardown

26. **`creates the file on first save`**.
27. **`loads an empty file as no goals`** — missing file → empty, not an error.
28. **`round-trips goals through disk`** — save 3, load with a fresh store, get 3 equal.
29. **`recovers from a corrupt file`** — write `"{ not json"` → `load()` returns empty and
    moves the bad file aside as `goals.corrupt.json`. **Never crash on start-up because a
    file got mangled**, and never silently destroy the user's data either.
30. **`writes atomically`** — the file is valid JSON after every save; no zero-byte window.

## Done when

All pass, and `grep -rn "2027" Sources/` returns nothing.

## Out of scope

The goal UI (T17). Computing progress against a goal (T13).
