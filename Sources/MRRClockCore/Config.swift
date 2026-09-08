import Foundation

/// Calculator settings introduced by T08 and extended by T13.
public struct Config: Equatable, Sendable {
    public var currency: String
    public var includeTrials: Bool
    /// Maximum named product lines before the tail becomes Other (METRICS.md § Breakdown by product).
    public var breakdownLimit: Int
    /// First instant included in earned-to-date totals (METRICS.md § Earned to date).
    public var earningsStartDate: Date

    public init(
        currency: String = "usd",
        includeTrials: Bool = false,
        breakdownLimit: Int = 3,
        earningsStartDate: Date = .distantPast
    ) {
        self.currency = currency.lowercased()
        self.includeTrials = includeTrials
        self.breakdownLimit = breakdownLimit
        self.earningsStartDate = earningsStartDate
    }
}
