import Foundation
import Testing
@testable import MRRClockCore

@Suite("Live Stripe client")
struct LiveStripeClientTests {
    @Test("sends the bearer token")
    func sendsBearerToken() async throws {
        let transport = StubTransport(responses: [.success(listResponse())])
        let client = LiveStripeClient(key: "rk_test_123", transport: transport, retry: .none)

        _ = try await client.activeSubscriptions(includeTrials: false)

        let request = try #require(await transport.requests.first)
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer rk_test_123")
    }

    @Test("pins the Stripe API version")
    func pinsStripeVersion() async throws {
        let transport = StubTransport(responses: [.success(listResponse())])
        let client = LiveStripeClient(
            key: "rk_test_123", transport: transport, scheduler: FakeRetryScheduler()
        )

        _ = try await client.activeSubscriptions(includeTrials: false)

        let request = try #require(await transport.requests.first)
        #expect(request.value(forHTTPHeaderField: "Stripe-Version") == "2024-06-20")
    }

    @Test("requests active subscriptions with a page size of 100")
    func requestsActiveSubscriptions() async throws {
        let transport = StubTransport(responses: [.success(listResponse())])
        let client = LiveStripeClient(key: "rk_test_123", transport: transport)

        _ = try await client.activeSubscriptions(includeTrials: false)

        let url = try #require(await transport.requests.first?.url?.absoluteString)
        #expect(url.contains("status=active"))
        #expect(url.contains("limit=100"))
    }

    @Test("sends created[gte] as unix seconds")
    func sendsCreatedSince() async throws {
        let transport = StubTransport(responses: [.success(listResponse())])
        let client = LiveStripeClient(key: "rk_test_123", transport: transport)
        let januaryFirst2026 = Date(timeIntervalSince1970: 1_767_225_600)

        _ = try await client.balanceTransactions(since: januaryFirst2026)

        let url = try #require(await transport.requests.first?.url?.absoluteString)
        #expect(url.contains("created%5Bgte%5D=1767225600"))
    }

    @Test("requests trialing subscriptions only when trials are included")
    func requestsTrialsConditionally() async throws {
        let withoutTrialsTransport = StubTransport(responses: [.success(listResponse())])
        let withoutTrials = LiveStripeClient(key: "rk_test_123", transport: withoutTrialsTransport)
        _ = try await withoutTrials.activeSubscriptions(includeTrials: false)
        #expect(await withoutTrialsTransport.requests.count == 1)

        let withTrialsTransport = StubTransport(responses: [
            .success(listResponse()), .success(listResponse())
        ])
        let withTrials = LiveStripeClient(key: "rk_test_123", transport: withTrialsTransport)
        _ = try await withTrials.activeSubscriptions(includeTrials: true)
        let requests = await withTrialsTransport.requests
        #expect(requests.count == 2)
        _ = try #require(requests.count == 2)
        #expect(requests[1].url?.absoluteString.contains("status=trialing") == true)
    }

    @Test("maps 401 to unauthorized")
    func mapsUnauthorized() async {
        let transport = StubTransport(responses: [.success(listResponse(status: 401))])
        let client = LiveStripeClient(key: "rk_test_123", transport: transport, retry: .none)

        await #expect(throws: StripeError.unauthorized) {
            try await client.activeSubscriptions(includeTrials: false)
        }
    }

    @Test("maps 403 to forbidden with the resource name")
    func mapsForbidden() async {
        let body = #"{"error":{"message":"subscriptions"}}"#
        let transport = StubTransport(responses: [.success(listResponse(status: 403, body: body))])
        let client = LiveStripeClient(key: "rk_test_123", transport: transport, retry: .none)

        await #expect(throws: StripeError.forbidden(resource: "subscriptions")) {
            try await client.activeSubscriptions(includeTrials: false)
        }
    }

    @Test("maps 429 to rateLimited with the Retry-After value")
    func mapsRateLimited() async {
        let response = listResponse(status: 429, headers: ["Retry-After": "7"])
        let transport = StubTransport(responses: [.success(response)])
        let client = LiveStripeClient(key: "rk_test_123", transport: transport, retry: .none)

        await #expect(throws: StripeError.rateLimited(retryAfter: 7)) {
            try await client.activeSubscriptions(includeTrials: false)
        }
    }

    @Test("maps 500 to serverError")
    func mapsServerError() async {
        let transport = StubTransport(responses: [.success(listResponse(status: 500))])
        let client = LiveStripeClient(key: "rk_test_123", transport: transport, retry: .none)

        await #expect(throws: StripeError.serverError(status: 500)) {
            try await client.activeSubscriptions(includeTrials: false)
        }
    }

    @Test("maps a transport failure to network")
    func mapsNetworkFailure() async {
        let transport = StubTransport(responses: [.failure(URLError(.notConnectedToInternet))])
        let client = LiveStripeClient(key: "rk_test_123", transport: transport, retry: .none)

        await #expect(throws: StripeError.network(underlying: URLError(.notConnectedToInternet))) {
            try await client.activeSubscriptions(includeTrials: false)
        }
    }

    @Test("maps malformed JSON to decoding")
    func mapsMalformedJSON() async {
        let transport = StubTransport(responses: [.success(listResponse(body: "{"))])
        let client = LiveStripeClient(key: "rk_test_123", transport: transport)

        do {
            _ = try await client.activeSubscriptions(includeTrials: false)
            Issue.record("Expected a decoding error")
        } catch let error as StripeError {
            guard case .decoding = error else {
                Issue.record("Expected decoding, got \(error)")
                return
            }
        } catch {
            Issue.record("Expected StripeError, got \(error)")
        }
    }

    @Test("retries a 429 and succeeds on the second attempt")
    func retriesRateLimit() async throws {
        let transport = StubTransport(responses: [
            .success(listResponse(status: 429)), .success(listResponse())
        ])
        let scheduler = FakeRetryScheduler()
        let client = LiveStripeClient(
            key: "rk_test_123", transport: transport, scheduler: scheduler
        )

        _ = try await client.activeSubscriptions(includeTrials: false)

        #expect(await transport.requests.count == 2)
        #expect(await scheduler.delays == [.seconds(1)])
    }

    @Test("gives up after three attempts")
    func givesUpAfterThreeAttempts() async {
        let transport = StubTransport(responses: [
            .success(listResponse(status: 500)),
            .success(listResponse(status: 500)),
            .success(listResponse(status: 500))
        ])
        let scheduler = FakeRetryScheduler()
        let client = LiveStripeClient(
            key: "rk_test_123", transport: transport, scheduler: scheduler
        )

        await #expect(throws: StripeError.serverError(status: 500)) {
            try await client.activeSubscriptions(includeTrials: false)
        }
        #expect(await transport.requests.count == 3)
    }

    @Test("does not retry a 401")
    func doesNotRetryUnauthorized() async {
        let transport = StubTransport(responses: [
            .success(listResponse(status: 401)),
            .success(listResponse(status: 401)),
            .success(listResponse(status: 401))
        ])
        let client = LiveStripeClient(
            key: "rk_test_123", transport: transport, scheduler: FakeRetryScheduler()
        )

        await #expect(throws: StripeError.unauthorized) {
            try await client.activeSubscriptions(includeTrials: false)
        }
        #expect(await transport.requests.count == 1)
    }

    @Test("no error description contains the API key")
    func errorDescriptionsHideAPIKey() {
        let transport = StubTransport(responses: [])
        _ = LiveStripeClient(key: "rk_live_SECRET", transport: transport, retry: .none)
        let underlying = SecretBearingError()
        let errors: [StripeError] = [
            .unauthorized,
            .forbidden(resource: "subscriptions"),
            .notFound,
            .rateLimited(retryAfter: 7),
            .serverError(status: 500),
            .network(underlying: underlying),
            .decoding(underlying: underlying),
            .malformedPage,
            .paginationLimitExceeded
        ]

        for error in errors {
            #expect(!String(describing: error).contains("SECRET"))
        }
    }
}

private struct SecretBearingError: Error, CustomStringConvertible {
    let description = "transport failure for rk_live_SECRET"
}

private actor StubTransport: HTTPTransport {
    private(set) var requests: [URLRequest] = []
    private var responses: [Result<(Data, HTTPURLResponse), Error>]

    init(responses: [Result<(Data, HTTPURLResponse), Error>]) {
        self.responses = responses
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        return try responses.removeFirst().get()
    }
}

private actor FakeRetryScheduler: RetryScheduler {
    private(set) var delays: [Duration] = []

    func wait(for delay: Duration) async throws {
        delays.append(delay)
    }
}

private func listResponse(
    status: Int = 200,
    body: String = #"{"object":"list","has_more":false,"data":[]}"#,
    headers: [String: String]? = nil
) -> (Data, HTTPURLResponse) {
    let response = HTTPURLResponse(
        url: URL(string: "https://api.stripe.com/v1/subscriptions")!,
        statusCode: status,
        httpVersion: nil,
        headerFields: headers
    )!
    return (Data(body.utf8), response)
}
