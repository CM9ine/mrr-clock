import Foundation

/// An in-memory `StripeAPI` implementation for deterministic tests, previews, and demo mode.
public actor FakeStripeClient: StripeAPI {
    public private(set) var activeSubscriptionsCallCount = 0
    public private(set) var subscriptionItemsCallCount = 0
    public private(set) var balanceTransactionsCallCount = 0
    public private(set) var productsCallCount = 0

    private let subscriptions: [Subscription]
    private let transactions: [BalanceTransaction]
    private let seededProducts: [Product]
    private let seededSubscriptionItems: [String: [SubscriptionItem]]
    private let error: StripeError?
    private let delay: (@Sendable () async -> Void)?

    public init(
        subscriptions: [Subscription] = [],
        balanceTransactions: [BalanceTransaction] = [],
        products: [Product] = [],
        subscriptionItems: [String: [SubscriptionItem]] = [:],
        error: StripeError? = nil,
        delay: (@Sendable () async -> Void)? = nil
    ) {
        self.subscriptions = subscriptions
        self.transactions = balanceTransactions
        self.seededProducts = products
        self.seededSubscriptionItems = subscriptionItems
        self.error = error
        self.delay = delay
    }

    public func activeSubscriptions(includeTrials: Bool) async throws -> [Subscription] {
        activeSubscriptionsCallCount += 1
        if let delay { await delay() }
        if let error { throw error }
        let includedStatuses = includeTrials ? ["active", "trialing"] : ["active"]
        let included = subscriptions.filter { includedStatuses.contains($0.status) }
        var expanded: [Subscription] = []
        for subscription in included {
            guard subscription.items.hasMore else {
                expanded.append(subscription)
                continue
            }
            let fetched = try await subscriptionItems(subscriptionID: subscription.id)
            var seen = Set(subscription.items.data.map(\.id))
            let unique = fetched.filter { seen.insert($0.id).inserted }
            expanded.append(Subscription(
                id: subscription.id,
                status: subscription.status,
                currency: subscription.currency,
                cancelAtPeriodEnd: subscription.cancelAtPeriodEnd,
                items: SubscriptionItems(data: subscription.items.data + unique, hasMore: false),
                discount: subscription.discount
            ))
        }
        return expanded
    }

    public func subscriptionItems(subscriptionID: String) async throws -> [SubscriptionItem] {
        subscriptionItemsCallCount += 1
        if let delay { await delay() }
        if let error { throw error }
        return seededSubscriptionItems[subscriptionID] ?? []
    }

    public func balanceTransactions(since: Date) async throws -> [BalanceTransaction] {
        balanceTransactionsCallCount += 1
        if let delay { await delay() }
        if let error { throw error }
        return transactions
    }

    public func products() async throws -> [Product] {
        productsCallCount += 1
        if let delay { await delay() }
        if let error { throw error }
        return seededProducts
    }
}
