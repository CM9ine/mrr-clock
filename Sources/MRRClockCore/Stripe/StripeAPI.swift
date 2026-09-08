import Foundation

/// Errors raised while accessing Stripe data.
public enum StripeError: Error, Equatable {
    case unauthorized
    case malformedPage
    case paginationLimitExceeded
}

/// The Stripe data seam consumed by the core refresh pipeline.
public protocol StripeAPI: Sendable {
    func activeSubscriptions(includeTrials: Bool) async throws -> [Subscription]
    func subscriptionItems(subscriptionID: String) async throws -> [SubscriptionItem]
    func balanceTransactions(since: Date) async throws -> [BalanceTransaction]
    func products() async throws -> [Product]
}

/// Fetches a Stripe list while preserving endpoint order, following the pagination rule in
/// `docs/STRIPE.md`.
public func paginate<Element: Decodable & Sendable>(
    fetchPage: (String?) async throws -> StripeList<Element>,
    id: (Element) -> String
) async throws -> [Element] {
    var items: [Element] = []
    var cursor: String?

    for _ in 0..<100 {
        let page = try await fetchPage(cursor)
        items.append(contentsOf: page.data)
        guard page.hasMore else { return items }
        guard let last = page.data.last else { throw StripeError.malformedPage }
        cursor = id(last)
    }

    throw StripeError.paginationLimitExceeded
}
