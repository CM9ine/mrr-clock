/// The net Stripe balance recognised under METRICS.md § Earned to date.
public struct EarningsResult: Equatable, Sendable {
    public let total: Money
    public let transactionCount: Int
    public let otherCurrencies: Set<String>
}

/// Totals Stripe balance transactions according to METRICS.md § Earned to date.
public struct EarningsCalculator: Sendable {
    public init() {}

    /// Returns net earnings on or after the configured start date in the configured currency.
    public func earned(transactions: [BalanceTransaction], config: Config) -> EarningsResult {
        let excludedTypes = Set(["payout", "payout_cancel", "payout_failure", "transfer", "topup"])
        let candidates = transactions.filter {
            !excludedTypes.contains($0.type) && $0.created >= config.earningsStartDate
        }
        let included = candidates.filter { $0.currency == config.currency }
        return EarningsResult(
            total: Money(included.reduce(0) { $0 + $1.net }, config.currency),
            transactionCount: included.count,
            otherCurrencies: Set(candidates.lazy.map(\.currency).filter { $0 != config.currency })
        )
    }
}
