import Foundation

/// Why an otherwise recurring item was excluded from MRR (METRICS.md § MRR).
public enum SkipReason: Equatable, Sendable {
    case metered, tiered, noUnitAmount, notRecurring
}

/// An excluded Stripe price and the rule that excluded it (METRICS.md § MRR).
public struct SkippedItem: Equatable, Sendable {
    public let priceID: String
    public let reason: SkipReason

    public init(priceID: String, reason: SkipReason) {
        self.priceID = priceID
        self.reason = reason
    }
}

/// The account-wide MRR result defined by METRICS.md § MRR.
public struct MRRResult: Equatable, Sendable {
    public let total: Money
    public let subscriptionCount: Int
    public let skipped: [SkippedItem]
    public let otherCurrencies: Set<String>
    public let churnRisk: Money
}

/// Calculates monthly recurring revenue using the normalization rules in METRICS.md § MRR.
public struct MRRCalculator: Sendable {
    private let clock: any Clock

    public init(clock: any Clock = SystemClock()) {
        self.clock = clock
    }

    /// Normalizes and totals eligible subscriptions, rounding once per subscription.
    public func mrr(subscriptions: [Subscription], config: Config) -> MRRResult {
        var total = Money.zero(config.currency)
        var count = 0
        var skipped: [SkippedItem] = []
        var otherCurrencies: Set<String> = []
        var churnRisk = Money.zero(config.currency)

        for subscription in subscriptions {
            let includedStatus = subscription.status == "active"
                || (subscription.status == "trialing" && config.includeTrials)
            guard includedStatus else { continue }
            guard subscription.currency.lowercased() == config.currency else {
                otherCurrencies.insert(subscription.currency.lowercased())
                continue
            }

            var monthly = Decimal.zero
            var discountFactor: Decimal?
            for item in subscription.items.data {
                guard let recurring = item.price.recurring else {
                    skipped.append(.init(priceID: item.price.id, reason: .notRecurring))
                    continue
                }
                guard recurring.usageType == "licensed" else {
                    skipped.append(.init(priceID: item.price.id, reason: .metered))
                    continue
                }
                guard item.price.billingScheme == "per_unit" else {
                    skipped.append(.init(priceID: item.price.id, reason: .tiered))
                    continue
                }
                guard let amount = item.price.unitAmount else {
                    skipped.append(.init(priceID: item.price.id, reason: .noUnitAmount))
                    continue
                }
                let itemFactor = factor(for: recurring)
                monthly += Decimal(amount) * Decimal(item.quantity) * itemFactor
                if discountFactor == nil { discountFactor = itemFactor }
            }

            if let discount = subscription.discount,
               !(discount.coupon.duration == "once" && discount.end.map { $0 < clock.now } == true) {
                if let percentOff = discount.coupon.percentOff {
                    monthly *= 1 - percentOff / 100
                } else if let amountOff = discount.coupon.amountOff, let discountFactor {
                    monthly -= Decimal(amountOff) * discountFactor
                }
            }
            monthly = max(0, monthly)
            let subscriptionMoney = Money.from(monthly, config.currency)
            total = total + subscriptionMoney
            count += 1
            if subscription.status == "active" && subscription.cancelAtPeriodEnd {
                churnRisk = churnRisk + subscriptionMoney
            }
        }

        return MRRResult(
            total: total,
            subscriptionCount: count,
            skipped: skipped,
            otherCurrencies: otherCurrencies,
            churnRisk: churnRisk
        )
    }

    private func factor(for recurring: Recurring) -> Decimal {
        let count = Decimal(recurring.intervalCount)
        switch recurring.interval {
        case .month: return 1 / count
        case .year: return 1 / (12 * count)
        case .week: return (Decimal(365) / 12) / (7 * count)
        case .day: return (Decimal(365) / 12) / count
        case .unknown: return 0
        }
    }
}
