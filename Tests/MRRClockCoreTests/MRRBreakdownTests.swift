import Testing
@testable import MRRClockCore

struct MRRBreakdownTests {
    @Test("an empty list produces no lines")
    func empty() {
        let lines = MRRCalculator().breakdown(
            subscriptions: [],
            productNames: [:],
            config: .test
        )
        #expect(lines == [])
    }

    @Test("one product produces one line")
    func oneProduct() throws {
        let lines = MRRCalculator().breakdown(
            subscriptions: [.stub(items: [.stub(price: .stub(product: "prod_a", unitAmount: 1000))])],
            productNames: ["prod_a": "Aurora"],
            config: .test
        )
        let line = try #require(lines.first)
        #expect(lines.count == 1)
        #expect(line.productID == "prod_a")
        #expect(line.name == "Aurora")
        #expect(line.amount == Money(1000, "usd"))
    }

    @Test("falls back to the product id when the name is unknown")
    func unknownName() throws {
        let lines = MRRCalculator().breakdown(
            subscriptions: [.stub(items: [.stub(price: .stub(product: "prod_a"))])],
            productNames: [:],
            config: .test
        )
        #expect(try #require(lines.first).name == "prod_a")
    }

    @Test("sums several subscriptions of the same product into one line")
    func sumsSubscriptions() throws {
        let subscriptions = [
            Subscription.stub(id: "sub_1", items: [.stub(price: .stub(product: "prod_a", unitAmount: 1000))]),
            Subscription.stub(id: "sub_2", items: [.stub(price: .stub(product: "prod_a", unitAmount: 500))]),
        ]
        let lines = MRRCalculator().breakdown(subscriptions: subscriptions, productNames: [:], config: .test)
        #expect(lines.count == 1)
        #expect(try #require(lines.first).amount == Money(1500, "usd"))
    }

    @Test("sorts lines by amount descending")
    func sortsByAmount() {
        let lines = MRRCalculator().breakdown(
            subscriptions: [subscription("prod_a", 820), subscription("prod_b", 310), subscription("prod_c", 60)],
            productNames: [:],
            config: .test
        )
        #expect(lines.map(\.productID) == ["prod_a", "prod_b", "prod_c"])
    }

    @Test("breaks ties by name ascending")
    func breaksTiesByName() {
        let lines = MRRCalculator().breakdown(
            subscriptions: [subscription("prod_a", 500), subscription("prod_b", 500)],
            productNames: ["prod_a": "Zebra", "prod_b": "Alpha"],
            config: .test
        )
        #expect(lines.map(\.name) == ["Alpha", "Zebra"])
    }

    @Test("collapses everything past the limit into Other")
    func collapsesPastLimit() {
        let lines = MRRCalculator().breakdown(
            subscriptions: [subscription("prod_a", 820), subscription("prod_b", 310), subscription("prod_c", 60), subscription("prod_d", 50)],
            productNames: [:],
            config: Config(currency: "usd", breakdownLimit: 3)
        )
        #expect(lines.map(\.amount.amount) == [820, 310, 60, 50])
        #expect(lines.last?.productID == "other")
        #expect(lines.last?.name == "Other")
    }

    @Test("sums several tail products into one Other line")
    func sumsTailProducts() {
        let lines = MRRCalculator().breakdown(
            subscriptions: [subscription("prod_a", 820), subscription("prod_b", 310), subscription("prod_c", 60), subscription("prod_d", 50), subscription("prod_e", 40)],
            productNames: [:],
            config: Config(currency: "usd", breakdownLimit: 3)
        )
        #expect(lines.last?.amount == Money(90, "usd"))
    }

    @Test("omits Other when nothing is left over")
    func omitsEmptyOther() {
        let lines = MRRCalculator().breakdown(
            subscriptions: [subscription("prod_a", 820), subscription("prod_b", 310), subscription("prod_c", 60)],
            productNames: [:],
            config: Config(currency: "usd", breakdownLimit: 3)
        )
        #expect(lines.count == 3)
        #expect(!lines.contains { $0.name == "Other" })
    }

    @Test("respects a limit of one")
    func limitOfOne() {
        let lines = MRRCalculator().breakdown(
            subscriptions: [subscription("prod_a", 820), subscription("prod_b", 310)],
            productNames: [:],
            config: Config(currency: "usd", breakdownLimit: 1)
        )
        #expect(lines.map(\.amount.amount) == [820, 310])
        #expect(lines.map(\.name) == ["prod_a", "Other"])
    }

    @Test("splits a discount across the products of one subscription")
    func splitsDiscount() {
        let subscription = Subscription.stub(items: [
            .stub(id: "si_a", price: .stub(product: "prod_a", unitAmount: 1000)),
            .stub(id: "si_b", price: .stub(product: "prod_b", unitAmount: 1000)),
        ], discount: .stub(coupon: .stub(percentOff: 50)))
        let calculator = MRRCalculator()
        let lines = calculator.breakdown(subscriptions: [subscription], productNames: [:], config: .test)
        #expect(lines.map(\.amount.amount) == [500, 500])
        #expect(lines.reduce(0) { $0 + $1.amount.amount } == calculator.mrr(subscriptions: [subscription], config: .test).total.amount)
    }

    @Test("excludes skipped items from the breakdown")
    func excludesSkippedItems() {
        let subscription = Subscription.stub(items: [
            .stub(id: "si_a", price: .stub(product: "prod_a", unitAmount: 1000)),
            .stub(id: "si_b", price: .stub(product: "prod_b", unitAmount: 500, interval: .month, usageType: "metered")),
        ])
        let lines = MRRCalculator().breakdown(subscriptions: [subscription], productNames: [:], config: .test)
        #expect(lines.map(\.productID) == ["prod_a"])
    }

    @Test("excludes foreign-currency subscriptions")
    func excludesForeignCurrency() {
        let lines = MRRCalculator().breakdown(
            subscriptions: [subscription("prod_a", 1000), subscription("prod_b", 500, currency: "gbp")],
            productNames: [:],
            config: .test
        )
        #expect(lines.map(\.productID) == ["prod_a"])
    }

    @Test("line totals reconcile with the MRR total")
    func linesReconcileWithTotal() {
        let subscriptions = [
            subscription("prod_a", 1000),
            .stub(id: "sub_mixed", items: [
                .stub(id: "si_b", price: .stub(product: "prod_b", unitAmount: 9900, interval: .year)),
                .stub(id: "si_c", price: .stub(product: "prod_c", unitAmount: 700, interval: .week)),
            ], discount: .stub(coupon: .stub(percentOff: 20))),
            .stub(id: "sub_skipped", items: [.stub(price: .stub(product: "prod_metered", interval: .month, usageType: "metered"))]),
            subscription("prod_gbp", 5000, currency: "gbp"),
            .stub(id: "sub_canceled", status: "canceled", items: [.stub(price: .stub(product: "prod_canceled", unitAmount: 100_000))]),
        ]
        let calculator = MRRCalculator()
        let lines = calculator.breakdown(subscriptions: subscriptions, productNames: [:], config: .test)
        let total = calculator.mrr(subscriptions: subscriptions, config: .test).total.amount
        #expect(abs(lines.reduce(0) { $0 + $1.amount.amount } - total) <= lines.count)
    }

    private func subscription(_ productID: String, _ amount: Int, currency: String = "usd") -> Subscription {
        .stub(id: "sub_\(productID)", currency: currency, items: [.stub(price: .stub(product: productID, currency: currency, unitAmount: amount))])
    }
}
