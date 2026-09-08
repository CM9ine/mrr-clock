import Testing
@testable import MRRClockCore

@Suite("Subscription item expansion")
struct SubscriptionItemsTests {
    @Test("fetches the remaining items when items.has_more is true")
    func fetchesRemainingItems() async throws {
        let embedded = SubscriptionItem.stub(id: "si_1")
        let repeated = SubscriptionItem.stub(id: "si_1")
        let additional = SubscriptionItem.stub(id: "si_2")
        let client = FakeStripeClient(
            subscriptions: [.stub(id: "sub_1", items: [embedded], itemsHasMore: true)],
            subscriptionItems: ["sub_1": [repeated, additional]]
        )

        let subscriptions = try await client.activeSubscriptions(includeTrials: false)
        let result = try #require(subscriptions.first)

        #expect(await client.subscriptionItemsCallCount == 1)
        #expect(result.items.data.map(\.id) == ["si_1", "si_2"])
    }

    @Test("does not fetch items when has_more is false")
    func skipsCompleteItems() async throws {
        let client = FakeStripeClient(subscriptions: [
            .stub(id: "sub_1", items: [.stub(id: "si_1")], itemsHasMore: false)
        ])

        _ = try await client.activeSubscriptions(includeTrials: false)

        #expect(await client.subscriptionItemsCallCount == 0)
    }
}
