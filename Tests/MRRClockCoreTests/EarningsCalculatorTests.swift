import Foundation
import Testing
@testable import MRRClockCore

@Suite("EarningsCalculator")
struct EarningsCalculatorTests {
    private let startDate = Date(timeIntervalSince1970: 1_767_225_600)

    private func fixtureData(named name: String) throws -> Data {
        try Data(contentsOf: Bundle.module.url(forResource: name, withExtension: nil)!)
    }

    private func transaction(
        id: String = "txn_1",
        type: String = "charge",
        net: Int,
        currency: String = "usd",
        created: Date = Date(timeIntervalSince1970: 1_767_225_601)
    ) -> BalanceTransaction {
        .stub(id: id, type: type, net: net, currency: currency, created: created)
    }

    @Test("an empty list is zero")
    func emptyList() {
        let result = EarningsCalculator().earned(
            transactions: [],
            config: Config(currency: "usd", earningsStartDate: startDate)
        )

        #expect(result.total == Money.zero("usd"))
        #expect(result.transactionCount == 0)
    }

    @Test("sums charges")
    func sumsCharges() {
        let result = EarningsCalculator().earned(
            transactions: [
                transaction(id: "txn_1", net: 1000),
                transaction(id: "txn_2", net: 2000),
            ],
            config: Config(currency: "usd", earningsStartDate: startDate)
        )

        #expect(result.total == Money(3000, "usd"))
        #expect(result.transactionCount == 2)
    }

    @Test("net is already after fees")
    func netAfterFees() {
        let result = EarningsCalculator().earned(
            transactions: [transaction(net: 971)],
            config: Config(currency: "usd", earningsStartDate: startDate)
        )

        #expect(result.total == Money(971, "usd"))
    }

    @Test("refunds reduce the total")
    func refundsReduceTotal() {
        let result = EarningsCalculator().earned(
            transactions: [
                transaction(id: "charge_1", net: 1000),
                transaction(id: "charge_2", net: 2000),
                transaction(id: "refund_1", type: "refund", net: -500),
            ],
            config: Config(currency: "usd", earningsStartDate: startDate)
        )

        #expect(result.total == Money(2500, "usd"))
    }

    @Test("a refund-only period is negative")
    func refundOnlyPeriod() {
        let result = EarningsCalculator().earned(
            transactions: [transaction(type: "refund", net: -500)],
            config: Config(currency: "usd", earningsStartDate: startDate)
        )

        #expect(result.total == Money(-500, "usd"))
    }

    @Test("excludes payouts")
    func excludesPayouts() {
        let result = EarningsCalculator().earned(
            transactions: [
                transaction(type: "charge", net: 1000),
                transaction(type: "payout", net: -1000),
            ],
            config: Config(currency: "usd", earningsStartDate: startDate)
        )

        #expect(result.total == Money(1000, "usd"))
        #expect(result.transactionCount == 1)
    }

    @Test(
        "excludes transfers, topups and payout reversals",
        arguments: ["transfer", "topup", "payout_cancel", "payout_failure"]
    )
    func excludesMoneyMovement(type: String) {
        let result = EarningsCalculator().earned(
            transactions: [
                transaction(type: "charge", net: 1000),
                transaction(type: type, net: -600),
            ],
            config: Config(currency: "usd", earningsStartDate: startDate)
        )

        #expect(result.total == Money(1000, "usd"))
    }

    @Test("includes adjustments and disputes")
    func includesAdjustmentsAndDisputes() {
        let result = EarningsCalculator().earned(
            transactions: [
                transaction(type: "charge", net: 2000),
                transaction(type: "adjustment", net: -1500),
            ],
            config: Config(currency: "usd", earningsStartDate: startDate)
        )

        #expect(result.total == Money(500, "usd"))
    }

    @Test("excludes transactions before the start date")
    func excludesBeforeStartDate() {
        let result = EarningsCalculator().earned(
            transactions: [
                transaction(net: 1000, created: Date(timeIntervalSince1970: 1_767_225_599)),
                transaction(net: 2000, created: Date(timeIntervalSince1970: 1_767_225_601)),
            ],
            config: Config(currency: "usd", earningsStartDate: startDate)
        )

        #expect(result.total == Money(2000, "usd"))
    }

    @Test("includes a transaction exactly on the start date")
    func includesStartDateBoundary() {
        let result = EarningsCalculator().earned(
            transactions: [transaction(net: 1000, created: startDate)],
            config: Config(currency: "usd", earningsStartDate: startDate)
        )

        #expect(result.total == Money(1000, "usd"))
    }

    @Test("excludes other currencies and reports them")
    func excludesOtherCurrencies() {
        let result = EarningsCalculator().earned(
            transactions: [
                transaction(net: 1000),
                transaction(net: 5000, currency: "gbp"),
            ],
            config: Config(currency: "usd", earningsStartDate: startDate)
        )

        #expect(result.total == Money(1000, "usd"))
        #expect(result.otherCurrencies == ["gbp"])
    }

    @Test("counts only the transactions it included")
    func countsOnlyIncludedTransactions() {
        let result = EarningsCalculator().earned(
            transactions: [
                transaction(id: "included_charge", net: 1000),
                transaction(id: "included_refund", type: "refund", net: -100),
                transaction(id: "old", net: 500, created: Date(timeIntervalSince1970: 1_767_225_599)),
                transaction(id: "payout", type: "payout", net: -900),
                transaction(id: "gbp", net: 2000, currency: "gbp"),
            ],
            config: Config(currency: "usd", earningsStartDate: startDate)
        )

        #expect(result.transactionCount == 2)
    }

    @Test("decodes and totals the committed fixture")
    func totalsCommittedFixture() throws {
        let data = try fixtureData(named: "balance_transactions.json")
        let list = try StripeJSON.decoder().decode(
            StripeList<BalanceTransaction>.self,
            from: data
        )
        let result = EarningsCalculator().earned(
            transactions: list.data,
            config: Config(
                currency: "usd",
                earningsStartDate: Date(timeIntervalSince1970: 1_699_999_999)
            )
        )

        // 925 charge - 500 refund = 425; the -425 payout is excluded.
        #expect(result.total == Money(425, "usd"))
    }
}
