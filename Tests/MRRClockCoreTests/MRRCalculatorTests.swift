import Foundation
import Testing
@testable import MRRClockCore

struct MRRCalculatorTests {
    struct IntervalCase: Sendable {
        let unitAmount: Int
        let interval: Interval
        let intervalCount: Int
        let quantity: Int
        let expected: Int
    }

    @Test(
        "normalises a billing interval to a monthly amount",
        arguments: [
            IntervalCase(unitAmount: 1000, interval: .month, intervalCount: 1, quantity: 1, expected: 1000),
            IntervalCase(unitAmount: 1000, interval: .month, intervalCount: 1, quantity: 3, expected: 3000),
            IntervalCase(unitAmount: 3000, interval: .month, intervalCount: 3, quantity: 1, expected: 1000),
            IntervalCase(unitAmount: 12000, interval: .year, intervalCount: 1, quantity: 1, expected: 1000),
            IntervalCase(unitAmount: 9900, interval: .year, intervalCount: 1, quantity: 1, expected: 825),
            IntervalCase(unitAmount: 10000, interval: .year, intervalCount: 1, quantity: 1, expected: 833),
            IntervalCase(unitAmount: 24000, interval: .year, intervalCount: 2, quantity: 1, expected: 1000),
            IntervalCase(unitAmount: 700, interval: .week, intervalCount: 1, quantity: 1, expected: 3042),
            IntervalCase(unitAmount: 1000, interval: .week, intervalCount: 2, quantity: 1, expected: 2173),
            IntervalCase(unitAmount: 100, interval: .day, intervalCount: 1, quantity: 1, expected: 3042),
        ]
    )
    func normalisesInterval(testCase: IntervalCase) {
        let item = SubscriptionItem.stub(
            quantity: testCase.quantity,
            price: .stub(
                unitAmount: testCase.unitAmount,
                interval: testCase.interval,
                intervalCount: testCase.intervalCount
            )
        )
        let result = MRRCalculator().mrr(subscriptions: [.stub(items: [item])], config: .test)
        #expect(result.total == Money(testCase.expected, "usd"))
    }

    @Test("an empty list is zero MRR")
    func empty() {
        let result = calculator().mrr(subscriptions: [], config: .test)
        #expect(result.total == .zero("usd"))
        #expect(result.subscriptionCount == 0)
    }

    @Test("sums several subscriptions")
    func severalSubscriptions() {
        let monthly = Subscription.stub(id: "sub_month", items: [.stub(unitAmount: 1000)])
        let yearly = Subscription.stub(id: "sub_year", items: [.stub(unitAmount: 9900, interval: .year)])
        let result = calculator().mrr(subscriptions: [monthly, yearly], config: .test)
        #expect(result.total == Money(1825, "usd"))
        #expect(result.subscriptionCount == 2)
    }

    @Test("sums several items within one subscription")
    func severalItems() {
        let sub = Subscription.stub(items: [
            .stub(id: "si_month", unitAmount: 1000),
            .stub(id: "si_year", unitAmount: 9900, interval: .year),
        ])
        let result = calculator().mrr(subscriptions: [sub], config: .test)
        #expect(result.total == Money(1825, "usd"))
        #expect(result.subscriptionCount == 1)
    }

    @Test("counts active subscriptions")
    func active() { #expect(result(status: "active").total == Money(1000, "usd")) }

    @Test("ignores past_due, unpaid, paused, canceled, incomplete", arguments: ["past_due", "unpaid", "paused", "canceled", "incomplete"])
    func ignoredStatuses(status: String) { #expect(result(status: status).total == .zero("usd")) }

    @Test("ignores trialing by default")
    func ignoresTrials() {
        let result = calculator().mrr(subscriptions: [.stub(), .stub(id: "trial", status: "trialing", items: [.stub(unitAmount: 5000)])], config: .test)
        #expect(result.total == Money(1000, "usd"))
    }

    @Test("includes trialing when the config says so")
    func includesTrials() {
        let result = calculator().mrr(subscriptions: [.stub(), .stub(id: "trial", status: "trialing", items: [.stub(unitAmount: 5000)])], config: Config(currency: "usd", includeTrials: true))
        #expect(result.total == Money(6000, "usd"))
    }

    @Test("counts a subscription that is set to cancel at period end")
    func cancelAtPeriodEnd() {
        let result = calculator().mrr(subscriptions: [.stub(cancelAtPeriodEnd: true)], config: .test)
        #expect(result.total == Money(1000, "usd"))
        #expect(result.churnRisk == Money(1000, "usd"))
    }

    @Test("skips a metered price")
    func metered() { assertSkipped(price: .stub(interval: .month, usageType: "metered"), reason: .metered) }

    @Test("skips a tiered price")
    func tiered() { assertSkipped(price: .stub(billingScheme: "tiered"), reason: .tiered) }

    @Test("skips a price with no unit amount")
    func noUnitAmount() { assertSkipped(price: .stub(unitAmount: nil), reason: .noUnitAmount) }

    @Test("skips a one-off price with no recurring block")
    func notRecurring() { assertSkipped(price: .stub(recurring: nil), reason: .notRecurring) }

    @Test("still counts the good items on a subscription with one bad item")
    func mixedItems() {
        let result = calculator().mrr(subscriptions: [.stub(items: [.stub(), .stub(id: "bad", price: .stub(id: "metered", interval: .month, usageType: "metered"))])], config: .test)
        #expect(result.total == Money(1000, "usd"))
        #expect(result.skipped.count == 1)
    }

    @Test("applies a percent-off coupon")
    func percentOff() { #expect(discounted(.stub(percentOff: 20)) == Money(800, "usd")) }

    @Test("rounds a percent-off result half up")
    func percentOffRounding() { #expect(discounted(.stub(percentOff: Decimal(string: "33.33")!)) == Money(667, "usd")) }

    @Test("applies an amount-off coupon at the subscription interval")
    func amountOff() { #expect(discounted(.stub(amountOff: 500)) == Money(500, "usd")) }

    @Test("normalises an amount-off coupon on a yearly subscription")
    func yearlyAmountOff() { #expect(discounted(.stub(amountOff: 500), unitAmount: 9900, interval: .year) == Money(783, "usd")) }

    @Test("never lets a discount go below zero")
    func discountClamp() { #expect(discounted(.stub(amountOff: 5000)) == .zero("usd")) }

    @Test("ignores a once-only coupon that has already ended")
    func expiredOnce() {
        let coupon = Coupon.stub(percentOff: 50, duration: "once")
        #expect(discounted(coupon, end: Date(timeIntervalSince1970: 900)) == Money(1000, "usd"))
    }

    @Test("applies a repeating coupon that has not ended")
    func activeRepeating() {
        let coupon = Coupon.stub(percentOff: 50, duration: "repeating")
        #expect(discounted(coupon, end: Date(timeIntervalSince1970: 1_100)) == Money(500, "usd"))
    }

    @Test("excludes a subscription in another currency")
    func foreignCurrency() {
        let result = calculator().mrr(subscriptions: [.stub(), .stub(id: "gbp", currency: "gbp", items: [.stub(unitAmount: 5000)])], config: .test)
        #expect(result.total == Money(1000, "usd"))
        #expect(result.otherCurrencies == ["gbp"])
    }

    @Test("an all-foreign-currency account reports zero and lists the currencies")
    func allForeign() {
        let result = calculator().mrr(subscriptions: [.stub(currency: "gbp")], config: .test)
        #expect(result.total == .zero("usd"))
        #expect(result.otherCurrencies == ["gbp"])
    }

    private func calculator() -> MRRCalculator { MRRCalculator(clock: FixedClock(at: Date(timeIntervalSince1970: 1_000))) }
    private func result(status: String) -> MRRResult { calculator().mrr(subscriptions: [.stub(status: status)], config: .test) }
    private func assertSkipped(price: Price, reason: SkipReason) {
        let result = calculator().mrr(subscriptions: [.stub(items: [.stub(price: price)])], config: .test)
        #expect(result.total == .zero("usd"))
        #expect(result.skipped == [SkippedItem(priceID: price.id, reason: reason)])
    }
    private func discounted(_ coupon: Coupon, unitAmount: Int = 1000, interval: Interval = .month, end: Date? = nil) -> Money {
        let sub = Subscription.stub(items: [.stub(unitAmount: unitAmount, interval: interval)], discount: .stub(coupon: coupon, end: end))
        return calculator().mrr(subscriptions: [sub], config: .test).total
    }
}
