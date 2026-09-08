import Foundation
@testable import MRRClockCore

extension StripeList {
    static func stub(data: [Element], hasMore: Bool = false) -> Self {
        Self(data: data, hasMore: hasMore)
    }
}

extension Subscription {
    static func stub(
        id: String = "sub_1",
        status: String = "active",
        currency: String = "usd",
        cancelAtPeriodEnd: Bool = false,
        items: [SubscriptionItem] = [.stub()],
        itemsHasMore: Bool = false,
        discount: Discount? = nil
    ) -> Self {
        Self(
            id: id,
            status: status,
            currency: currency,
            cancelAtPeriodEnd: cancelAtPeriodEnd,
            items: .stub(data: items, hasMore: itemsHasMore),
            discount: discount
        )
    }
}

extension SubscriptionItems {
    static func stub(
        data: [SubscriptionItem] = [.stub()],
        hasMore: Bool = false
    ) -> Self {
        Self(data: data, hasMore: hasMore)
    }
}

extension SubscriptionItem {
    static func stub(
        id: String = "si_1",
        quantity: Int = 1,
        price: Price = .stub()
    ) -> Self {
        Self(id: id, quantity: quantity, price: price)
    }

    static func stub(
        id: String = "si_1",
        quantity: Int = 1,
        unitAmount: Int?,
        interval: Interval = .month
    ) -> Self {
        Self(id: id, quantity: quantity, price: .stub(unitAmount: unitAmount, interval: interval))
    }
}

extension Price {
    static func stub(
        id: String = "price_1",
        product: String = "prod_1",
        currency: String = "usd",
        unitAmount: Int? = 1000,
        recurring: Recurring? = .stub(),
        interval: Interval? = nil,
        intervalCount: Int = 1,
        usageType: String = "licensed",
        billingScheme: String = "per_unit"
    ) -> Self {
        Self(
            id: id,
            product: product,
            currency: currency,
            unitAmount: unitAmount,
            recurring: interval.map {
                .stub(interval: $0, intervalCount: intervalCount, usageType: usageType)
            } ?? recurring,
            billingScheme: billingScheme
        )
    }
}

extension Recurring {
    static func stub(
        interval: Interval = .month,
        intervalCount: Int = 1,
        usageType: String = "licensed"
    ) -> Self {
        Self(interval: interval, intervalCount: intervalCount, usageType: usageType)
    }
}

extension Discount {
    static func stub(coupon: Coupon = .stub(), end: Date? = nil) -> Self {
        Self(coupon: coupon, end: end)
    }
}

extension Coupon {
    static func stub(
        percentOff: Decimal? = nil,
        amountOff: Int? = nil,
        duration: String = "forever"
    ) -> Self {
        Self(percentOff: percentOff, amountOff: amountOff, duration: duration)
    }
}

extension BalanceTransaction {
    static func stub(
        id: String = "txn_1",
        type: String = "charge",
        net: Int = 1000,
        currency: String = "usd",
        created: Date = Date(timeIntervalSince1970: 1_700_000_000)
    ) -> Self {
        Self(id: id, type: type, net: net, currency: currency, created: created)
    }
}

extension Product {
    static func stub(id: String = "prod_1", name: String = "Test Product") -> Self {
        Self(id: id, name: name)
    }
}
