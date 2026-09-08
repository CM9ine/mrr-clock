import Foundation

/// Sends URL requests for the live Stripe adapter while allowing tests to provide a
/// deterministic transport with no network access.
public protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

/// The production HTTP transport backed by the shared URL session.
public struct URLSessionTransport: HTTPTransport {
    public init() {}

    public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        return (data, response)
    }
}

/// Controls how many times retryable Stripe responses may be attempted.
public struct RetryPolicy: Sendable {
    public let maximumAttempts: Int
    public let delays: [Duration]

    public static let `default` = RetryPolicy(maximumAttempts: 3, delays: [.seconds(1), .seconds(2), .seconds(4)])
    public static let none = RetryPolicy(maximumAttempts: 1, delays: [])

    public init(maximumAttempts: Int, delays: [Duration]) {
        precondition(maximumAttempts > 0)
        precondition(delays.count >= maximumAttempts - 1)
        self.maximumAttempts = maximumAttempts
        self.delays = delays
    }
}

/// Waits between retry attempts; tests inject a recorder so they never sleep.
public protocol RetryScheduler: Sendable {
    func wait(for delay: Duration) async throws
}

/// Uses Swift's monotonic clock for production retry delays.
public struct SystemRetryScheduler: RetryScheduler {
    public init() {}

    public func wait(for delay: Duration) async throws {
        try await ContinuousClock().sleep(for: delay)
    }
}

/// Fetches Stripe data using the request and pagination rules in `docs/STRIPE.md`.
public struct LiveStripeClient: StripeAPI {
    private let key: String
    private let transport: any HTTPTransport
    private let retry: RetryPolicy
    private let scheduler: any RetryScheduler

    public init(
        key: String,
        transport: any HTTPTransport,
        retry: RetryPolicy = .default,
        scheduler: any RetryScheduler = SystemRetryScheduler()
    ) {
        self.key = key
        self.transport = transport
        self.retry = retry
        self.scheduler = scheduler
    }

    public func activeSubscriptions(includeTrials: Bool) async throws -> [Subscription] {
        var result = try await subscriptions(status: "active")
        if includeTrials {
            result += try await subscriptions(status: "trialing")
        }
        return result
    }

    private func subscriptions(status: String) async throws -> [Subscription] {
        try await fetchAll(
            path: "subscriptions",
            queryItems: [
            URLQueryItem(name: "status", value: status),
            URLQueryItem(name: "limit", value: "100")
            ],
            id: { $0.id }
        )
    }

    public func subscriptionItems(subscriptionID: String) async throws -> [SubscriptionItem] {
        try await fetchAll(
            path: "subscription_items",
            queryItems: [
                URLQueryItem(name: "subscription", value: subscriptionID),
                URLQueryItem(name: "limit", value: "100")
            ],
            id: { $0.id }
        )
    }

    public func balanceTransactions(since: Date) async throws -> [BalanceTransaction] {
        try await fetchAll(
            path: "balance_transactions",
            queryItems: [
                URLQueryItem(name: "created[gte]", value: String(Int(since.timeIntervalSince1970))),
                URLQueryItem(name: "limit", value: "100")
            ],
            id: { $0.id }
        )
    }

    public func products() async throws -> [Product] {
        try await fetchAll(
            path: "products",
            queryItems: [
                URLQueryItem(name: "active", value: "true"),
                URLQueryItem(name: "limit", value: "100")
            ],
            id: { $0.id }
        )
    }

    private func fetchAll<Element: Decodable & Sendable>(
        path: String,
        queryItems: [URLQueryItem],
        id: @escaping (Element) -> String
    ) async throws -> [Element] {
        do {
            return try await paginate(fetchPage: { cursor in
                var pageQuery = queryItems
                if let cursor {
                    pageQuery.append(URLQueryItem(name: "starting_after", value: cursor))
                }
                let data = try await send(request(path: path, queryItems: pageQuery))
                return try decode(StripeList<Element>.self, from: data)
            }, id: id)
        } catch StripeError.notFound {
            return []
        }
    }

    private func request(path: String, queryItems: [URLQueryItem]) -> URLRequest {
        var components = URLComponents(string: "https://api.stripe.com/v1/" + path)!
        components.queryItems = queryItems
        var request = URLRequest(url: components.url!)
        request.setValue("Bearer " + key, forHTTPHeaderField: "Authorization")
        request.setValue("2024-06-20", forHTTPHeaderField: "Stripe-Version")
        return request
    }

    private func send(_ request: URLRequest) async throws -> Data {
        for attempt in 0..<retry.maximumAttempts {
            do {
                return try await sendOnce(request)
            } catch let error as StripeError where error.isRetryable && attempt + 1 < retry.maximumAttempts {
                try await scheduler.wait(for: retry.delays[attempt])
            }
        }
        fatalError("Retry loop must return or throw")
    }

    private func sendOnce(_ request: URLRequest) async throws -> Data {
        let data: Data
        let response: HTTPURLResponse
        do {
            (data, response) = try await transport.send(request)
        } catch {
            throw StripeError.network(underlying: error)
        }
        if response.statusCode == 401 {
            throw StripeError.unauthorized
        }
        if response.statusCode == 403 {
            struct ErrorEnvelope: Decodable {
                struct Detail: Decodable { let message: String }
                let error: Detail
            }
            let resource = try decode(ErrorEnvelope.self, from: data).error.message
            throw StripeError.forbidden(resource: resource)
        }
        if response.statusCode == 404 {
            throw StripeError.notFound
        }
        if response.statusCode == 429 {
            throw StripeError.rateLimited(
                retryAfter: response.value(forHTTPHeaderField: "Retry-After").flatMap(Int.init)
            )
        }
        if (500...599).contains(response.statusCode) {
            throw StripeError.serverError(status: response.statusCode)
        }
        return data
    }

    private func decode<Value: Decodable>(_ type: Value.Type, from data: Data) throws -> Value {
        do {
            return try StripeJSON.decoder().decode(type, from: data)
        } catch {
            throw StripeError.decoding(underlying: error)
        }
    }
}

private extension StripeError {
    var isRetryable: Bool {
        switch self {
        case .rateLimited, .serverError: true
        default: false
        }
    }
}
