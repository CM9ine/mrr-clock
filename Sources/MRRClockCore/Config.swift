/// Calculator settings introduced by T08 and extended by T13.
public struct Config: Equatable, Sendable {
    public var currency: String
    public var includeTrials: Bool
    /// Maximum named product lines before the tail becomes Other (METRICS.md § Breakdown by product).
    public var breakdownLimit: Int

    public init(currency: String = "usd", includeTrials: Bool = false, breakdownLimit: Int = 3) {
        self.currency = currency.lowercased()
        self.includeTrials = includeTrials
        self.breakdownLimit = breakdownLimit
    }
}
