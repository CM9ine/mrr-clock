/// Errors raised while accessing Stripe data, mapped according to `docs/STRIPE.md`.
public enum StripeError: Error, Equatable, CustomStringConvertible, @unchecked Sendable {
    case unauthorized
    case forbidden(resource: String)
    case notFound
    case rateLimited(retryAfter: Int?)
    case serverError(status: Int)
    case network(underlying: any Error)
    case decoding(underlying: any Error)
    case malformedPage
    case paginationLimitExceeded

    public static func == (lhs: StripeError, rhs: StripeError) -> Bool {
        switch (lhs, rhs) {
        case (.unauthorized, .unauthorized), (.notFound, .notFound),
             (.malformedPage, .malformedPage),
             (.paginationLimitExceeded, .paginationLimitExceeded): true
        case let (.forbidden(left), .forbidden(right)): left == right
        case let (.rateLimited(left), .rateLimited(right)): left == right
        case let (.serverError(left), .serverError(right)): left == right
        case (.network, .network), (.decoding, .decoding): true
        default: false
        }
    }

    public var description: String {
        switch self {
        case .unauthorized: "unauthorized"
        case let .forbidden(resource): "forbidden(resource: \(resource))"
        case .notFound: "notFound"
        case let .rateLimited(retryAfter): "rateLimited(retryAfter: \(String(describing: retryAfter)))"
        case let .serverError(status): "serverError(status: \(status))"
        case .network: "network"
        case .decoding: "decoding"
        case .malformedPage: "malformedPage"
        case .paginationLimitExceeded: "paginationLimitExceeded"
        }
    }
}
