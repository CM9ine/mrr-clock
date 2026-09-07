# T06 · `LiveStripeClient` — requests, auth, typed errors

**Depends on:** T05 · **Milestone:** M2

## Goal

The real HTTP client. Tested entirely against a stubbed transport — **the suite still
never touches the network.**

## Read first

- [STRIPE.md § Requests](../STRIPE.md#requests) and [§ Errors](../STRIPE.md#errors)

## Build

`Sources/MRRClockCore/Stripe/LiveStripeClient.swift`

Inject the transport so it can be stubbed:

```swift
public protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}
public struct URLSessionTransport: HTTPTransport { … }

public struct LiveStripeClient: StripeAPI {
    init(key: String, transport: HTTPTransport, retry: RetryPolicy = .default)
}
```

- Base `https://api.stripe.com/v1`
- Headers: `Authorization: Bearer <key>`, `Stripe-Version: 2024-06-20`
- Query building for `status`, `limit=100`, `created[gte]`, `starting_after`
- `StripeError` per the STRIPE.md table
- Retry: 1s → 2s → 4s, 3 attempts, **only** 429 and 5xx; delays come from an injected
  scheduler so tests never wait

## Tests

`Tests/MRRClockCoreTests/LiveStripeClientTests.swift`, all through a `StubTransport` that
records requests and returns canned `(Data, HTTPURLResponse)`.

**Request shape**

1. **`sends the bearer token`** — `Authorization == "Bearer rk_test_123"`.
2. **`pins the Stripe API version`** — `Stripe-Version == "2024-06-20"`.
3. **`requests active subscriptions with a page size of 100`** — URL contains
   `status=active` and `limit=100`.
4. **`sends created[gte] as unix seconds`** — `since = 2026-01-01T00:00:00Z` produces
   `created%5Bgte%5D=1767225600`. Compute the expected epoch by hand in the test.
5. **`requests trialing subscriptions only when trials are included`** — two calls when
   `includeTrials` is true, one when false.

**Error mapping**

6. **`maps 401 to unauthorized`**
7. **`maps 403 to forbidden with the resource name`** — parse the Stripe error body.
8. **`maps 429 to rateLimited with the Retry-After value`** — header `Retry-After: 7` →
   `.rateLimited(retryAfter: 7)`.
9. **`maps 500 to serverError`**
10. **`maps a transport failure to network`** — transport throws `URLError` →
    `.network`.
11. **`maps malformed JSON to decoding`** — body `{` → `.decoding`.

**Retry**

12. **`retries a 429 and succeeds on the second attempt`** — transport returns 429 then
    200 → the call succeeds, transport was hit twice, and the fake scheduler was asked to
    wait 1 second.
13. **`gives up after three attempts`** — always 500 → throws `.serverError`, exactly 3
    requests.
14. **`does not retry a 401`** — exactly 1 request.

**Secret hygiene**

15. **`no error description contains the API key`** — construct every `StripeError` case
    from a client built with key `"rk_live_SECRET"`, and assert
    `!String(describing: error).contains("SECRET")` for each. This is the test that stops
    a key ending up in a log or a crash report.

## Done when

All pass. Grep the source: the key is never string-interpolated into anything but the
`Authorization` header.

## Out of scope

Keychain (T07). Orchestration (T14).
