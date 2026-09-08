import Foundation

/// Creates decoders for Stripe response shapes used by the app.
public enum StripeJSON {
    /// Returns a decoder configured for the fields currently decoded from Stripe.
    public static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }
}

/// A Stripe list envelope, including its pagination marker.
public struct StripeList<Element: Decodable>: Decodable {
    public let data: [Element]
    public let hasMore: Bool
}

/// The subscription fields needed by the MRR rules in docs/METRICS.md.
public struct Subscription: Decodable {
    public let id: String
    public let status: String
    public let currency: String
    public let cancelAtPeriodEnd: Bool
    public let items: SubscriptionItems
    public let discount: Discount?
}

/// Embedded subscription items and their pagination marker.
public struct SubscriptionItems: Decodable {
    public let data: [SubscriptionItem]
    public let hasMore: Bool
}

/// A quantity and price attached to a subscription.
public struct SubscriptionItem: Decodable {
    public let id: String
    public let quantity: Int
    public let price: Price
}

/// Stripe price fields needed to identify recurring revenue in docs/METRICS.md.
public struct Price: Decodable {
    public let id: String
    public let product: String
    public let currency: String
    public let unitAmount: Int?
    public let recurring: Recurring?
    public let billingScheme: String
}

/// The cadence and usage mode of a recurring Stripe price.
public struct Recurring: Decodable {
    public let interval: Interval
    public let intervalCount: Int
    public let usageType: String
}

/// Supported Stripe billing intervals, preserving forward compatibility.
public enum Interval: String, Decodable {
    case day, week, month, year, unknown

    public init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        self = Interval(rawValue: value) ?? .unknown
    }
}

/// A subscription-level discount used by docs/METRICS.md § Discounts.
public struct Discount: Decodable {
    public let coupon: Coupon
    public let end: Date?
}

/// Stripe coupon values used by docs/METRICS.md § Discounts.
public struct Coupon: Decodable {
    public let percentOff: Decimal?
    public let amountOff: Int?
    public let duration: String
}

/// A net Stripe ledger entry used by docs/METRICS.md § Earned to date.
public struct BalanceTransaction: Decodable {
    public let id: String
    public let type: String
    public let net: Int
    public let currency: String
    public let created: Date
}

/// A Stripe product name used for the MRR breakdown in docs/METRICS.md.
public struct Product: Decodable {
    public let id: String
    public let name: String
}
