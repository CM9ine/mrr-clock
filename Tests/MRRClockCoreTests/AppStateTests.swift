import Foundation
import Testing
@testable import MRRClockCore

@MainActor
@Test("publishes the title for the current phase")
func publishesTitleForCurrentPhase() {
    let formatter = MenuBarFormatter(locale: Locale(identifier: "en_US"))
    let snapshot = appStateSnapshot()
    let state = AppState(formatter: formatter, titleFormat: .daysAndMRR)
    let phases: [(AppPhase, String)] = [
        (.idle, "—"),
        (.needsSetup, "Set up"),
        (.noGoals, "Add a goal"),
        (.loading(previous: snapshot), "387d · $1.2k"),
        (.loaded(snapshot), "387d · $1.2k"),
        (.stale(snapshot, .notFound), "387d · $1.2k ⚠"),
    ]

    for (phase, expected) in phases {
        state.publish(phase)
        #expect(state.title == expected)
    }
}

@MainActor
@Test("publishes a view model per goal, pinned first")
func publishesGoalViewModelsPinnedFirst() {
    let pinnedID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    let snapshot = appStateSnapshot(goalIDs: [
        UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        pinnedID,
    ], pinnedGoalID: pinnedID)
    let state = AppState()

    state.publish(.loaded(snapshot))

    #expect(state.goalViewModels.map(\.goalID) == [pinnedID, snapshot.goals[0].goalID])
}

@MainActor
@Test("exposes warnings only when the snapshot has them")
func exposesSnapshotWarnings() {
    let state = AppState()
    let warning = "Skipped price price_metered: metered"

    state.publish(.loaded(appStateSnapshot()))
    #expect(state.warnings.isEmpty)

    state.publish(.loaded(appStateSnapshot(warnings: [warning])))
    #expect(state.warnings == [warning])

    state.publish(.needsSetup)
    #expect(state.warnings.isEmpty)
}

@MainActor
@Test("switching the pinned goal updates the title without a network call")
func switchingPinnedGoalUpdatesTitleOffline() async throws {
    let now = Date(timeIntervalSince1970: 1_788_771_600)
    let firstID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    let secondID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    let goals = [
        Goal(id: firstID, name: "House", targetDate: Date(timeIntervalSince1970: 1_822_176_000), createdAt: now, sortIndex: 0),
        Goal(id: secondID, name: "Runway", targetDate: Date(timeIntervalSince1970: 1_791_331_200), createdAt: now, sortIndex: 1),
    ]
    let goalStore = GoalStore(
        storage: InMemoryGoalStore(file: GoalFile(goals: goals, pinnedGoalID: firstID)),
        clock: FixedClock(at: now),
        config: .test
    )
    let api = FakeStripeClient()
    let cached = appStateSnapshot(goalIDs: [firstID, secondID], pinnedGoalID: firstID)
    let coordinator = RefreshCoordinator(
        api: { _ in api },
        keyStore: InMemoryKeyStore("test-key"),
        goalStore: goalStore,
        cache: InMemorySnapshotCache(snapshot: cached),
        clock: FixedClock(at: now),
        config: .test
    )
    let state = AppState(
        coordinator: coordinator,
        formatter: MenuBarFormatter(locale: Locale(identifier: "en_US")),
        titleFormat: .daysAndMRR
    )
    state.publish(.loaded(cached))
    let callsBefore = await (api.activeSubscriptionsCallCount, api.balanceTransactionsCallCount, api.productsCallCount)

    try await state.switchPinnedGoal(to: secondID)

    #expect(state.title == "30d · $1.2k")
    #expect(await (api.activeSubscriptionsCallCount, api.balanceTransactionsCallCount, api.productsCallCount) == callsBefore)
}

private func appStateSnapshot(
    warnings: [String] = [],
    goalIDs: [UUID] = [UUID(uuidString: "00000000-0000-0000-0000-000000000001")!],
    pinnedGoalID: UUID? = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
) -> Snapshot {
    let instant = Date(timeIntervalSince1970: 1_788_771_600)
    return Snapshot(
        syncedAt: instant,
        revenue: RevenueSnapshot(
            mrr: Money(124_000, "usd"),
            earnedToDate: Money(100_000, "usd"),
            breakdown: [],
            subscriptionCount: 1,
            churnRisk: .zero("usd"),
            warnings: warnings
        ),
        goals: goalIDs.enumerated().map { index, goalID in
            GoalProgress(
                goalID: goalID,
                name: "Launch",
                targetDate: instant,
                targetAmount: Money(400_000, "usd"),
                daysRemaining: 387,
                projected: Money(200_000, "usd"),
                percentFunded: Decimal(string: "0.25"),
                percentOnTrack: Decimal(string: "0.5"),
                isPinned: goalID == pinnedGoalID
            )
        },
        specVersion: metricsSpecVersion
    )
}
