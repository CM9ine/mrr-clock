# T05 · `StripeAPI` protocol, pagination, `FakeStripeClient`

**Depends on:** T04 · **Milestone:** M2

## Goal

The seam between the app and Stripe, plus the auto-paging loop and the fake that every
later test uses instead of the network.

## Read first

- [STRIPE.md § Pagination](../STRIPE.md#pagination)
- [ARCHITECTURE.md § The seams](../ARCHITECTURE.md#the-seams)

## Build

`Sources/MRRClockCore/Stripe/StripeAPI.swift`

```swift
public protocol StripeAPI: Sendable {
    func activeSubscriptions(includeTrials: Bool) async throws -> [Subscription]
    func subscriptionItems(subscriptionID: String) async throws -> [SubscriptionItem]
    func balanceTransactions(since: Date) async throws -> [BalanceTransaction]
    func products() async throws -> [Product]
}
```

Plus a reusable pagination helper, generic over page-fetching, that:

- appends `data`, follows `has_more` using `starting_after` = last element's id
- stops at **100 pages** with `StripeError.paginationLimitExceeded`
- throws on `has_more == true` with empty `data`
- preserves order across pages

`Sources/MRRClockCore/Stripe/FakeStripeClient.swift` — in the **main target**, not the test
target, so the app can use it for previews and a demo mode:

- init takes canned `[Subscription]`, `[BalanceTransaction]`, `[Product]`
- optional `error: StripeError?` to force a failure
- optional `delay` (as an injected value, never a real sleep in tests)
- records call counts so tests can assert "products was fetched once"

## Tests

`Tests/MRRClockCoreTests/PaginationTests.swift` (against a page-source closure, no HTTP)

1. **`a single page with has_more false returns its items`** — 3 in, 3 out.
2. **`follows has_more across two pages`** — page 1 has 2 items + `has_more`, page 2 has
   1 item → 3 items, in page order.
3. **`sends starting_after with the last id of the previous page`** — assert the cursor
   the second request received equals the last id of page 1.
4. **`an empty first page returns an empty array`** — no error.
5. **`throws when has_more is true but data is empty`** — `.paginationLimitExceeded` is
   wrong here; expect a distinct `.malformedPage`.
6. **`throws after 100 pages`** — a source that always says `has_more` →
   `.paginationLimitExceeded`, and assert it stopped at exactly 100 requests.
7. **`propagates an error from any page`** — page 2 throws → the call throws, and the
   items from page 1 are not returned.

`Tests/MRRClockCoreTests/FakeStripeClientTests.swift`

8. **`returns the subscriptions it was seeded with`**.
9. **`throws the error it was configured with`** — `.unauthorized` in, `.unauthorized` out.
10. **`counts calls per endpoint`** — two `products()` calls → `productsCallCount == 2`.
11. **`excludes trialing subscriptions unless includeTrials is set`** — seeded with one
    active and one trialing: `includeTrials: false` → 1, `true` → 2. The fake must model
    the same filter the live client gets from `status=active`, or T08's tests will pass
    against a fake that lies.

`Tests/MRRClockCoreTests/SubscriptionItemsTests.swift`

12. **`fetches the remaining items when items.has_more is true`** — a subscription whose
    embedded `items.hasMore` is true triggers a `subscriptionItems(subscriptionID:)` call,
    and the merged result has all items with no duplicates.
13. **`does not fetch items when has_more is false`** — call count is 0.

## Done when

All pass with zero network access.

## Out of scope

URLSession, real URLs, auth headers — all T06.
