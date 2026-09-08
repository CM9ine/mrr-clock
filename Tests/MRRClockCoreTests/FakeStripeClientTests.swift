import Testing
@testable import MRRClockCore

@Suite("Fake Stripe client")
struct FakeStripeClientTests {
    @Test("returns the subscriptions it was seeded with")
    func returnsSeededSubscriptions() async throws {
        let client = FakeStripeClient(subscriptions: [
            .stub(id: "sub_1"),
            .stub(id: "sub_2")
        ])

        let result = try await client.activeSubscriptions(includeTrials: false)

        #expect(result.map(\.id) == ["sub_1", "sub_2"])
    }

    @Test("throws the error it was configured with")
    func throwsConfiguredError() async {
        let client = FakeStripeClient(error: .unauthorized)

        await #expect(throws: StripeError.unauthorized) {
            try await client.products()
        }
    }

    @Test("counts calls per endpoint")
    func countsEndpointCalls() async throws {
        let client = FakeStripeClient()

        _ = try await client.products()
        _ = try await client.products()

        #expect(await client.productsCallCount == 2)
    }

    @Test("excludes trialing subscriptions unless includeTrials is set")
    func filtersTrials() async throws {
        let client = FakeStripeClient(subscriptions: [
            .stub(id: "sub_active", status: "active"),
            .stub(id: "sub_trial", status: "trialing")
        ])

        let withoutTrials = try await client.activeSubscriptions(includeTrials: false)
        let withTrials = try await client.activeSubscriptions(includeTrials: true)

        #expect(withoutTrials.map(\.id) == ["sub_active"])
        #expect(withTrials.map(\.id) == ["sub_active", "sub_trial"])
    }
}
