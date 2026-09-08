import Foundation
import Testing
@testable import MRRClockCore

struct GoalStoreTests {
    private let now = Date(iso: "2026-09-07T09:00:00Z")
    private let target = Date(iso: "2027-09-07T00:00:00Z")

    private func makeStore(storage: InMemoryGoalStore = InMemoryGoalStore()) -> GoalStore {
        GoalStore(storage: storage, clock: FixedClock(at: now))
    }

    @Test("starts with no goals and nothing pinned")
    func startsEmpty() { let store = makeStore(); #expect(store.goals.isEmpty); #expect(store.pinned == nil) }

    @Test("adds a goal")
    func addsGoal() throws { let store = makeStore(); _ = try store.add(name: "A", targetDate: target, targetAmount: nil); #expect(store.goals.count == 1); #expect(store.goals[0].name == "A"); #expect(store.goals[0].targetDate == target) }

    @Test("pins the first goal automatically")
    func pinsFirst() throws { let store = makeStore(); let goal = try store.add(name: "A", targetDate: target, targetAmount: nil); #expect(store.pinned?.id == goal.id) }

    @Test("does not re-pin when a second goal is added")
    func keepsFirstPinned() throws { let store = makeStore(); let first = try store.add(name: "A", targetDate: target, targetAmount: nil); _ = try store.add(name: "B", targetDate: target, targetAmount: nil); #expect(store.pinned?.id == first.id) }

    @Test("assigns increasing sort indices")
    func increasingIndices() throws { let store = makeStore(); for name in ["A", "B", "C"] { _ = try store.add(name: name, targetDate: target, targetAmount: nil) }; #expect(store.goals.map(\.sortIndex) == [0, 1, 2]) }

    @Test("returns goals sorted by sort index")
    func sortsLoadedGoals() {
        let goals = [2, 0, 1].map { Goal(name: "\($0)", targetDate: target, createdAt: now, sortIndex: $0) }
        let store = makeStore(storage: InMemoryGoalStore(file: GoalFile(goals: goals, pinnedGoalID: nil)))
        #expect(store.goals.map(\.sortIndex) == [0, 1, 2])
    }

    @Test("updates a goal in place")
    func updatesGoal() throws { let store = makeStore(); var goal = try store.add(name: "A", targetDate: target, targetAmount: nil); let id = goal.id; goal.name = "B"; goal.targetDate = now; try store.update(goal); #expect(store.goals.count == 1); #expect(store.goals[0].id == id); #expect(store.goals[0].name == "B"); #expect(store.goals[0].targetDate == now) }

    @Test("rejects an update that fails validation")
    func rejectsInvalidUpdate() throws { let store = makeStore(); var goal = try store.add(name: "A", targetDate: target, targetAmount: nil); goal.name = ""; #expect(throws: GoalStoreError.self) { try store.update(goal) }; #expect(store.goals[0].name == "A") }

    @Test("deletes a goal")
    func deletesGoal() throws { let store = makeStore(); let first = try store.add(name: "A", targetDate: target, targetAmount: nil); _ = try store.add(name: "B", targetDate: target, targetAmount: nil); try store.delete(id: first.id); #expect(store.goals.count == 1); #expect(store.goals[0].name == "B") }

    @Test("pins the next goal when the pinned one is deleted")
    func pinsNextOnDelete() throws { let store = makeStore(); let first = try store.add(name: "A", targetDate: target, targetAmount: nil); let second = try store.add(name: "B", targetDate: target, targetAmount: nil); try store.delete(id: first.id); #expect(store.pinned?.id == second.id) }

    @Test("leaves nothing pinned when the last goal is deleted")
    func clearsPin() throws { let store = makeStore(); let goal = try store.add(name: "A", targetDate: target, targetAmount: nil); try store.delete(id: goal.id); #expect(store.pinned == nil) }

    @Test("deleting an unknown id does nothing")
    func unknownDelete() throws { let store = makeStore(); _ = try store.add(name: "A", targetDate: target, targetAmount: nil); try store.delete(id: UUID()); #expect(store.goals.count == 1) }

    @Test("pins an existing goal on request")
    func pinsRequestedGoal() throws { let store = makeStore(); _ = try store.add(name: "A", targetDate: target, targetAmount: nil); let second = try store.add(name: "B", targetDate: target, targetAmount: nil); try store.pin(id: second.id); #expect(store.pinned?.id == second.id) }

    @Test("pinning an unknown id throws")
    func rejectsUnknownPin() { let store = makeStore(); #expect(throws: GoalStoreError.self) { try store.pin(id: UUID()) } }

    @Test("reorders goals and renumbers contiguously")
    func reorders() throws { let store = makeStore(); for name in ["A", "B", "C"] { _ = try store.add(name: name, targetDate: target, targetAmount: nil) }; try store.move(from: IndexSet(integer: 2), to: 0); #expect(store.goals.map(\.name) == ["C", "A", "B"]); #expect(store.goals.map(\.sortIndex) == [0, 1, 2]) }

    @Test("persists every mutation immediately")
    func persistsMutations() throws {
        let storage = InMemoryGoalStore(); var store = makeStore(storage: storage)
        var a = try store.add(name: "A", targetDate: target, targetAmount: nil); #expect(storage.saveCount == 1); #expect(makeStore(storage: storage).goals.count == 1)
        a.name = "Updated"; try store.update(a); #expect(storage.saveCount == 2); #expect(makeStore(storage: storage).goals[0].name == "Updated")
        let b = try store.add(name: "B", targetDate: target, targetAmount: nil); try store.pin(id: b.id); #expect(storage.saveCount == 4); #expect(makeStore(storage: storage).pinned?.id == b.id)
        try store.move(from: IndexSet(integer: 1), to: 0); #expect(storage.saveCount == 5); #expect(makeStore(storage: storage).goals[0].id == b.id)
        try store.delete(id: a.id); #expect(storage.saveCount == 6); store = makeStore(storage: storage); #expect(store.goals.map(\.id) == [b.id])
    }
}
