import Foundation

/// Inputs for the growth-compounded forecast in docs/METRICS.md § Projection.
public struct ProjectionInput: Sendable {
    public let earnedToDate: Money
    public let mrr: Money
    public let now: Date
    public let targetDate: Date
    public let monthlyGrowthRate: Decimal
    public let calendar: Calendar

    public init(
        earnedToDate: Money,
        mrr: Money,
        now: Date,
        targetDate: Date,
        monthlyGrowthRate: Decimal,
        calendar: Calendar
    ) {
        self.earnedToDate = earnedToDate
        self.mrr = mrr
        self.now = now
        self.targetDate = targetDate
        self.monthlyGrowthRate = monthlyGrowthRate
        self.calendar = calendar
    }
}

/// The rounded forecast and calendar-month split from docs/METRICS.md § Projection.
public struct ProjectionResult: Equatable, Sendable {
    public let projected: Money
    public let wholeMonths: Int
    public let partialMonth: Decimal
    public let mrrAtTarget: Money
}

/// Projects earned revenue through an arbitrary target date using docs/METRICS.md § Projection.
public struct Projection: Sendable {
    public init() {}

    public func project(_ input: ProjectionInput) -> ProjectionResult {
        precondition(
            input.earnedToDate.currency == input.mrr.currency,
            "Currency mismatch"
        )

        let calendar = input.calendar
        let start = calendar.startOfDay(for: input.now)
        let target = calendar.startOfDay(for: input.targetDate)

        guard target > start else {
            return ProjectionResult(
                projected: input.earnedToDate,
                wholeMonths: 0,
                partialMonth: 0,
                mrrAtTarget: input.mrr
            )
        }

        let wholeMonths = calendar.dateComponents([.month], from: start, to: target).month!
        let wholeMonthDate = calendar.date(byAdding: .month, value: wholeMonths, to: start)!
        let remainingDays = calendar.dateComponents([.day], from: wholeMonthDate, to: target).day!
        let daysInTargetMonth = calendar.range(of: .day, in: .month, for: target)!.count
        let partialMonth = Decimal(remainingDays) / Decimal(daysInTargetMonth)

        let growthMultiplier = Decimal(1) + input.monthlyGrowthRate
        let monthlyMRR = Decimal(input.mrr.amount)
        var rate = Decimal(1)
        var projected = Decimal(input.earnedToDate.amount)

        for _ in 0..<wholeMonths {
            projected += monthlyMRR * rate
            rate *= growthMultiplier
        }
        projected += monthlyMRR * rate * partialMonth

        return ProjectionResult(
            projected: Money.from(projected, input.earnedToDate.currency),
            wholeMonths: wholeMonths,
            partialMonth: partialMonth,
            mrrAtTarget: Money.from(monthlyMRR * rate, input.mrr.currency)
        )
    }
}
