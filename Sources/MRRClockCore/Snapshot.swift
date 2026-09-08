import Foundation

/// The complete point-in-time value rendered by the UI (docs/ARCHITECTURE.md § Data flow).
public struct Snapshot: Equatable, Codable, Sendable {
    public let syncedAt: Date
    public let revenue: RevenueSnapshot
    public let goals: [GoalProgress]
    public let specVersion: Int

    public init(syncedAt: Date, revenue: RevenueSnapshot, goals: [GoalProgress], specVersion: Int) {
        self.syncedAt = syncedAt
        self.revenue = revenue
        self.goals = goals
        self.specVersion = specVersion
    }

    /// Reports whether this snapshot is older than the allowed cache age.
    public func isStale(now: Date, maxAge: TimeInterval) -> Bool {
        now.timeIntervalSince(syncedAt) > maxAge
    }
}

/// Account-wide calculator output retained in a snapshot.
public struct RevenueSnapshot: Equatable, Codable, Sendable {
    public let mrr: Money
    public let earnedToDate: Money
    public let breakdown: [ProductLine]
    public let subscriptionCount: Int
    public let churnRisk: Money
    public let warnings: [String]

    public init(mrr: Money, earnedToDate: Money, breakdown: [ProductLine], subscriptionCount: Int, churnRisk: Money, warnings: [String]) {
        self.mrr = mrr
        self.earnedToDate = earnedToDate
        self.breakdown = breakdown
        self.subscriptionCount = subscriptionCount
        self.churnRisk = churnRisk
        self.warnings = warnings
    }
}

/// The per-goal countdown and funding calculations from docs/METRICS.md.
public struct GoalProgress: Equatable, Codable, Sendable {
    public let goalID: UUID
    public let name: String
    public let targetDate: Date
    public let targetAmount: Money?
    public let daysRemaining: Int
    public let projected: Money
    public let percentFunded: Decimal?
    public let percentOnTrack: Decimal?
    public var isPinned: Bool
    public var isOverdue: Bool { daysRemaining < 0 }

    public init(goalID: UUID, name: String, targetDate: Date, targetAmount: Money?, daysRemaining: Int, projected: Money, percentFunded: Decimal?, percentOnTrack: Decimal?, isPinned: Bool) {
        self.goalID = goalID
        self.name = name
        self.targetDate = targetDate
        self.targetAmount = targetAmount
        self.daysRemaining = daysRemaining
        self.projected = projected
        self.percentFunded = percentFunded
        self.percentOnTrack = percentOnTrack
        self.isPinned = isPinned
    }
}

/// The three account-wide calculator results consumed by `SnapshotBuilder`.
public struct SnapshotRevenueInput: Sendable {
    public let mrr: MRRResult
    public let earned: EarningsResult
    public let breakdown: [ProductLine]

    public init(mrr: MRRResult, earned: EarningsResult, breakdown: [ProductLine]) {
        self.mrr = mrr
        self.earned = earned
        self.breakdown = breakdown
    }
}

/// Purely assembles calculator results according to docs/ARCHITECTURE.md § Data flow.
public struct SnapshotBuilder: Sendable {
    private let clock: any Clock
    private let calendar: Calendar

    public init(clock: any Clock, calendar: Calendar = .current) {
        self.clock = clock
        self.calendar = calendar
    }

    public func build(revenue input: SnapshotRevenueInput, goals: [Goal], pinnedGoalID: UUID?, config: Config) -> Snapshot {
        let now = clock.now
        let skippedWarnings = input.mrr.skipped.map { item in
            let cause: String
            switch item.reason {
            case .metered: cause = "metered"
            case .tiered: cause = "tiered"
            case .noUnitAmount: cause = "missing unit amount"
            case .notRecurring: cause = "not recurring"
            }
            return "Skipped price \(item.priceID): \(cause)"
        }
        let currencies = input.mrr.otherCurrencies.union(input.earned.otherCurrencies).sorted()
        let currencyWarnings = currencies.map { "Excluded foreign currency: \($0)" }
        let ordered = goals.sorted { $0.sortIndex < $1.sortIndex }
        let pinnedFirst = ordered.filter { $0.id == pinnedGoalID } + ordered.filter { $0.id != pinnedGoalID }
        let progress = pinnedFirst.map { goal in
            let projected = Projection().project(ProjectionInput(
                earnedToDate: input.earned.total,
                mrr: input.mrr.total,
                now: now,
                targetDate: goal.targetDate,
                monthlyGrowthRate: config.monthlyGrowthRate,
                calendar: calendar
            )).projected
            let percentFunded = goal.targetAmount.map { target in
                precondition(target.amount > 0, "Goal target amount must be positive")
                precondition(target.currency == input.earned.total.currency, "Currency mismatch")
                return Decimal(input.earned.total.amount) / Decimal(target.amount)
            }
            let percentOnTrack = goal.targetAmount.map { target in
                precondition(target.amount > 0, "Goal target amount must be positive")
                precondition(target.currency == projected.currency, "Currency mismatch")
                return Decimal(projected.amount) / Decimal(target.amount)
            }
            return GoalProgress(
                goalID: goal.id,
                name: goal.name,
                targetDate: goal.targetDate,
                targetAmount: goal.targetAmount,
                daysRemaining: Countdown.daysRemaining(now: now, target: goal.targetDate, calendar: calendar),
                projected: projected,
                percentFunded: percentFunded,
                percentOnTrack: percentOnTrack,
                isPinned: goal.id == pinnedGoalID
            )
        }
        return Snapshot(
            syncedAt: now,
            revenue: RevenueSnapshot(
                mrr: input.mrr.total,
                earnedToDate: input.earned.total,
                breakdown: input.breakdown,
                subscriptionCount: input.mrr.subscriptionCount,
                churnRisk: input.mrr.churnRisk,
                warnings: skippedWarnings + currencyWarnings
            ),
            goals: progress,
            specVersion: metricsSpecVersion
        )
    }
}
