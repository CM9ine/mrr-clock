import Foundation
import Testing
@testable import MRRClockCore

struct StripeDTOTests {
    private func fixture(_ name: String) throws -> Data {
        try Data(contentsOf: Bundle.module.url(forResource: name, withExtension: nil)!)
    }

    @Test("decodes a monthly subscription from the fixture")
    func decodesMonthlySubscription() throws {
        let list = try StripeJSON.decoder().decode(
            StripeList<Subscription>.self,
            from: fixture("subscriptions_active.json")
        )
        let subscription = try #require(list.data.first)
        #expect(subscription.id == "sub_test_monthly")
        #expect(subscription.status == "active")
        #expect(subscription.items.data.count == 1)
        let price = try #require(subscription.items.data.first?.price)
        #expect(price.unitAmount == 1000)
        #expect(price.recurring?.interval == .month)
        #expect(price.recurring?.intervalCount == 1)
    }

    @Test("decodes a yearly subscription")
    func decodesYearlySubscription() throws {
        let list = try StripeJSON.decoder().decode(
            StripeList<Subscription>.self,
            from: fixture("subscriptions_active.json")
        )
        let yearly = try #require(list.data.first { $0.id == "sub_test_yearly" })
        #expect(yearly.items.data.first?.price.recurring?.interval == .year)
        #expect(yearly.items.data.first?.price.unitAmount == 9900)
    }

    @Test("decodes a subscription with several items")
    func decodesSeveralItems() throws {
        let list = try StripeJSON.decoder().decode(
            StripeList<Subscription>.self,
            from: fixture("subscriptions_active.json")
        )
        let multi = try #require(list.data.first { $0.id == "sub_test_multi" })
        #expect(multi.items.data.count == 2)
    }

    @Test("converts snake_case keys")
    func convertsSnakeCaseKeys() throws {
        struct Probe: Decodable {
            let cancelAtPeriodEnd: Bool
            let unitAmount: Int
        }
        let json = Data(#"{"cancel_at_period_end":true,"unit_amount":1234}"#.utf8)
        let value = try StripeJSON.decoder().decode(Probe.self, from: json)
        #expect(value.cancelAtPeriodEnd)
        #expect(value.unitAmount == 1234)
    }

    @Test("decodes created as a date from a unix timestamp")
    func decodesCreatedDate() throws {
        let list = try StripeJSON.decoder().decode(
            StripeList<BalanceTransaction>.self,
            from: fixture("balance_transactions.json")
        )
        #expect(list.data.first?.created == Date(timeIntervalSince1970: 1_700_000_000))
    }

    @Test("decodes a tiered price with a nil unit amount")
    func decodesTieredPrice() throws {
        let list = try StripeJSON.decoder().decode(
            StripeList<Subscription>.self,
            from: fixture("subscriptions_edge.json")
        )
        let tiered = try #require(list.data.first { $0.id == "sub_test_tiered" })
        #expect(tiered.items.data.first?.price.unitAmount == nil)
        #expect(tiered.items.data.first?.price.billingScheme == "tiered")
    }

    @Test("decodes a percent-off discount as a Decimal")
    func decodesPercentOffDiscount() throws {
        let list = try StripeJSON.decoder().decode(
            StripeList<Subscription>.self,
            from: fixture("subscriptions_edge.json")
        )
        let discounted = try #require(list.data.first { $0.id == "sub_test_percent_off" })
        let percent: Decimal? = discounted.discount?.coupon.percentOff
        #expect(percent == Decimal(20))
    }

    @Test("decodes an amount-off discount in minor units")
    func decodesAmountOffDiscount() throws {
        let list = try StripeJSON.decoder().decode(
            StripeList<Subscription>.self,
            from: fixture("subscriptions_edge.json")
        )
        let discounted = try #require(list.data.first { $0.id == "sub_test_amount_off" })
        #expect(discounted.discount?.coupon.amountOff == 500)
    }

    @Test("decodes an unknown interval as .unknown instead of throwing")
    func decodesUnknownInterval() throws {
        let json = Data(#"{"interval":"fortnight","interval_count":1,"usage_type":"licensed"}"#.utf8)
        let recurring = try StripeJSON.decoder().decode(Recurring.self, from: json)
        #expect(recurring.interval == .unknown)
    }

    @Test("ignores unknown top-level fields")
    func ignoresUnknownFields() throws {
        let json = Data(#"{"livemode":true,"some_new_field":{},"data":[],"has_more":false}"#.utf8)
        let list = try StripeJSON.decoder().decode(StripeList<Subscription>.self, from: json)
        #expect(list.data.isEmpty)
    }

    @Test("decodes the list envelope with has_more")
    func decodesListEnvelope() throws {
        let list = try StripeJSON.decoder().decode(StripeList<Subscription>.self, from: fixture("subscriptions_active.json"))
        #expect(list.hasMore)
        #expect(list.data.count == 3)
    }

    @Test("decodes balance transactions of every type in the fixture")
    func decodesBalanceTransactionTypes() throws {
        let list = try StripeJSON.decoder().decode(StripeList<BalanceTransaction>.self, from: fixture("balance_transactions.json"))
        #expect(Set(list.data.map(\.type)) == Set(["charge", "refund", "payout"]))
        #expect(list.data.first { $0.type == "refund" }?.net == -500)
    }

    @Test("decodes products with names")
    func decodesProducts() throws {
        let list = try StripeJSON.decoder().decode(StripeList<Product>.self, from: fixture("products.json"))
        #expect(Dictionary(uniqueKeysWithValues: list.data.map { ($0.id, $0.name) }) == [
            "prod_test_clock": "MRR Clock Pro",
            "prod_test_extra": "Extra Workspace"
        ])
    }

    @Test("stub factories produce a decodable-equivalent value")
    func stubFactoryDefaults() {
        let subscription = Subscription.stub()
        #expect(subscription.status == "active")
        #expect(subscription.items.data.count == 1)
        #expect(subscription.items.data.first?.price.recurring?.interval == .month)
        #expect(subscription.items.data.first?.price.unitAmount == 1000)
    }
}
