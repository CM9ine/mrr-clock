import Foundation
import Testing
@testable import MRRClockCore

struct SnapshotBuilderTests {
    private let now = Date(iso: "2026-09-07T09:00:00Z")
    private let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private func goal(_ name: String, target: String, amount: Money? = nil, sortIndex: Int) -> Goal {
        Goal(
            name: name,
            targetDate: Date(iso: target),
            targetAmount: amount,
            createdAt: now,
            sortIndex: sortIndex
        )
    }

    private func revenue(
        mrr: Money = Money(10_000, "usd"),
        earned: Money = Money(25_000, "usd"),
        skipped: [SkippedItem] = [],
        otherCurrencies: Set<String> = []
    ) -> SnapshotRevenueInput {
        SnapshotRevenueInput(
            mrr: MRRResult(
                total: mrr,
                subscriptionCount: 2,
                skipped: skipped,
                otherCurrencies: otherCurrencies,
                churnRisk: Money(1_000, "usd")
            ),
            earned: EarningsResult(total: earned, transactionCount: 3, otherCurrencies: []),
            breakdown: [ProductLine(productID: "prod_1", name: "Product", amount: mrr)]
        )
    }

    private func builder() -> SnapshotBuilder {
        SnapshotBuilder(clock: FixedClock(at: now), calendar: utc)
    }

    @Test("builds one progress entry per goal")
    func oneProgressPerGoal() {
        let goals = [
            goal("One", target: "2026-10-07T00:00:00Z", sortIndex: 0),
            goal("Two", target: "2026-11-07T00:00:00Z", sortIndex: 1),
            goal("Three", target: "2026-12-07T00:00:00Z", sortIndex: 2),
        ]

        let snapshot = builder().build(
            revenue: revenue(), goals: goals, pinnedGoalID: nil, config: Config()
        )

        #expect(snapshot.goals.count == 3)
    }

    @Test("puts the pinned goal first")
    func pinnedFirst() throws {
        let goals = [
            goal("One", target: "2026-10-07T00:00:00Z", sortIndex: 0),
            goal("Two", target: "2026-11-07T00:00:00Z", sortIndex: 1),
            goal("Three", target: "2026-12-07T00:00:00Z", sortIndex: 2),
        ]

        let snapshot = builder().build(
            revenue: revenue(), goals: goals, pinnedGoalID: goals[2].id, config: Config()
        )

        #expect(try #require(snapshot.goals.first).goalID == goals[2].id)
        #expect(try #require(snapshot.goals.first).isPinned)
        #expect(snapshot.goals.dropFirst().map(\.goalID) == [goals[0].id, goals[1].id])
    }

    @Test("carries the revenue figures through unchanged")
    func carriesRevenue() {
        let snapshot = builder().build(
            revenue: revenue(mrr: Money(12_345, "usd"), earned: Money(67_890, "usd")),
            goals: [],
            pinnedGoalID: nil,
            config: Config()
        )

        #expect(snapshot.revenue.mrr == Money(12_345, "usd"))
        #expect(snapshot.revenue.earnedToDate == Money(67_890, "usd"))
    }

    @Test("computes days remaining per goal")
    func daysRemainingPerGoal() {
        let goals = [
            goal("Near", target: "2026-10-07T00:00:00Z", sortIndex: 0),
            goal("Far", target: "2026-12-07T00:00:00Z", sortIndex: 1),
        ]

        let snapshot = builder().build(
            revenue: revenue(), goals: goals, pinnedGoalID: nil, config: Config()
        )

        #expect(snapshot.goals.map(\.daysRemaining) == [30, 91])
    }

    @Test("computes a projection per goal")
    func projectionPerGoal() {
        let goals = [
            goal("Near", target: "2026-10-07T00:00:00Z", sortIndex: 0),
            goal("Far", target: "2026-12-07T00:00:00Z", sortIndex: 1),
        ]
        let snapshot = builder().build(
            revenue: revenue(), goals: goals, pinnedGoalID: nil, config: Config()
        )
        let expected = goals.map {
            Projection().project(ProjectionInput(
                earnedToDate: Money(25_000, "usd"),
                mrr: Money(10_000, "usd"),
                now: now,
                targetDate: $0.targetDate,
                monthlyGrowthRate: 0,
                calendar: utc
            )).projected
        }

        #expect(snapshot.goals.map(\.projected) == [Money(35_000, "usd"), Money(55_000, "usd")])
        #expect(snapshot.goals.map(\.projected) == expected)
        #expect(snapshot.goals[0].projected.amount < snapshot.goals[1].projected.amount)
    }

    @Test("computes percent funded when the goal has a target amount")
    func percentFunded() throws {
        let fundedGoal = goal(
            "Funded", target: "2026-10-07T00:00:00Z", amount: Money(100_000, "usd"), sortIndex: 0
        )

        let snapshot = builder().build(
            revenue: revenue(earned: Money(25_000, "usd")),
            goals: [fundedGoal],
            pinnedGoalID: nil,
            config: Config()
        )

        #expect(try #require(snapshot.goals.first).percentFunded == Decimal(string: "0.25")!)
    }

    @Test("leaves percent funded nil when the goal has no target amount")
    func noPercentFundedWithoutTarget() throws {
        let snapshot = builder().build(
            revenue: revenue(),
            goals: [goal("No target", target: "2026-10-07T00:00:00Z", sortIndex: 0)],
            pinnedGoalID: nil,
            config: Config()
        )

        #expect(try #require(snapshot.goals.first).percentFunded == nil)
    }

    @Test("computes percent on track from the projection")
    func percentOnTrack() throws {
        let trackedGoal = goal(
            "Tracked", target: "2027-09-07T00:00:00Z", amount: Money(100_000, "usd"), sortIndex: 0
        )
        let snapshot = builder().build(
            revenue: revenue(mrr: Money(10_000, "usd"), earned: Money(0, "usd")),
            goals: [trackedGoal],
            pinnedGoalID: nil,
            config: Config()
        )

        #expect(try #require(snapshot.goals.first).projected == Money(120_000, "usd"))
        #expect(try #require(snapshot.goals.first).percentOnTrack == Decimal(string: "1.2")!)
    }

    @Test("marks a past goal overdue")
    func marksOverdue() throws {
        let snapshot = builder().build(
            revenue: revenue(),
            goals: [goal("Past", target: "2026-09-06T00:00:00Z", sortIndex: 0)],
            pinnedGoalID: nil,
            config: Config()
        )

        #expect(try #require(snapshot.goals.first).daysRemaining == -1)
        #expect(try #require(snapshot.goals.first).isOverdue)
    }

    @Test("builds an empty goals array when there are no goals")
    func emptyGoals() {
        let snapshot = builder().build(
            revenue: revenue(mrr: Money(12_345, "usd")),
            goals: [],
            pinnedGoalID: nil,
            config: Config()
        )

        #expect(snapshot.goals.isEmpty)
        #expect(snapshot.revenue.mrr == Money(12_345, "usd"))
    }

    @Test("collects warnings from skipped items and foreign currencies")
    func collectsWarnings() {
        let snapshot = builder().build(
            revenue: revenue(
                skipped: [SkippedItem(priceID: "price_metered", reason: .metered)],
                otherCurrencies: ["gbp"]
            ),
            goals: [],
            pinnedGoalID: nil,
            config: Config()
        )

        #expect(snapshot.revenue.warnings.count == 2)
        #expect(snapshot.revenue.warnings.contains { $0.contains("metered") })
        #expect(snapshot.revenue.warnings.contains { $0.contains("gbp") })
    }

    @Test("stamps syncedAt from the injected clock")
    func stampsInjectedTime() {
        let snapshot = builder().build(
            revenue: revenue(), goals: [], pinnedGoalID: nil, config: Config()
        )

        #expect(snapshot.syncedAt == now)
    }

    @Test("stamps the current spec version")
    func stampsSpecVersion() {
        let snapshot = builder().build(
            revenue: revenue(), goals: [], pinnedGoalID: nil, config: Config()
        )

        #expect(snapshot.specVersion == metricsSpecVersion)
    }
}
