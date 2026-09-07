# Stripe integration

## The key

MRRClock uses a **restricted API key** (`rk_live_…`), read-only, created at
Stripe Dashboard → Developers → API keys → *Create restricted key*.

Grant exactly these, all **Read**:

| Resource | Why |
| --- | --- |
| Subscriptions | MRR |
| Balance transactions | Earned to date |
| Products | Names for the breakdown |
| Prices | Amounts and intervals |

Grant nothing else. A key that cannot write cannot be used to move money even if the
machine is compromised, and this app never needs to write.

### Handling rules

- Stored in the macOS Keychain only. Service `com.mrrclock.app`,
  account `stripe.restricted_key`.
- **Never** written to `UserDefaults`, a plist, a log line, a crash report, or an error
  message. `StripeError` descriptions must not interpolate the key or the raw
  `Authorization` header — there is a test for this (T06).
- Redact in any debug output as `rk_live_…` + last 4.
- Settings shows only the last 4 once saved, with a *Replace* button.

## Requests

Base `https://api.stripe.com/v1`. Auth `Authorization: Bearer <key>`.
Also send `Stripe-Version: 2024-06-20` — **pin the version**, so Stripe changing their
default cannot silently change your MRR.

### Subscriptions

```
GET /v1/subscriptions
    ?status=active
    &limit=100
    &expand[]=data.default_payment_method   ← not needed; do not send
```

- Subscription items are embedded but **capped at 10** with `items.has_more`.
  When `has_more` is true, fetch the rest:
  `GET /v1/subscription_items?subscription=sub_xxx&limit=100`.
  Rare for a solo product business, but a silently truncated MRR is exactly the failure
  this app exists to prevent. T05 tests it.
- `status=active` excludes trials. Fetch `status=trialing` separately only when
  `config.includeTrials` is on.
- Prices come embedded in each item (`item.price`). No extra request needed.

### Balance transactions

```
GET /v1/balance_transactions
    ?created[gte]=<unix seconds of config.earningsStartDate>
    &limit=100
```

Sum `net`; filter by `type` per [METRICS.md](METRICS.md#earned-to-date).

### Products

```
GET /v1/products?active=true&limit=100
```

Only for display names in the breakdown. If this call fails, **do not fail the refresh** —
fall back to product ids and carry on. Names are cosmetic; the money is not.

## Pagination

Every list endpoint is the same envelope:

```json
{ "object": "list", "has_more": true, "data": [ … ] }
```

Loop: request → append `data` → if `has_more`, repeat with
`starting_after=<id of last element>` → stop when `has_more` is false.

Guard rails, all tested in T05:

- **Hard cap of 100 pages** per endpoint, then throw `.paginationLimitExceeded`.
  An infinite loop against a paid API is a bad way to find out about a bug.
- A page with `has_more: true` but empty `data` → throw, do not spin.
- Preserve order across pages; the caller relies on it for deterministic breakdowns.

## Errors

Map HTTP status to a typed `StripeError`. The UI reacts to the case, never to a string.

| Status | Case | What the app does |
| --- | --- | --- |
| 401 | `.unauthorized` | → `.needsSetup`, "Key rejected — replace it in Settings" |
| 403 | `.forbidden(resource:)` | "Key is missing read access to \(resource)" |
| 404 | `.notFound` | Treat as empty list where sensible |
| 429 | `.rateLimited(retryAfter:)` | Back off, keep showing cached snapshot |
| 5xx | `.serverError(status:)` | Retry with backoff, keep cache |
| — | `.network(underlying:)` | Offline. Keep cache, mark stale. |
| — | `.decoding(underlying:)` | Keep cache, surface in popover. Means Stripe changed shape. |

Retry policy: exponential backoff, 1s → 2s → 4s, **3 attempts**, only for 429 and 5xx.
Never retry 401/403 — a wrong key does not become right by asking twice.

## Fixtures

Tests never touch the network. Capture real responses once and commit them redacted:

```bash
curl -s https://api.stripe.com/v1/subscriptions?status=active\&limit=3 \
  -H "Authorization: Bearer $STRIPE_RK" \
  -H "Stripe-Version: 2024-06-20" | python3 -m json.tool \
  > Tests/MRRClockCoreTests/Fixtures/subscriptions_active.json
```

Then **redact by hand** before committing: replace customer ids, emails, and any
`metadata` with placeholders. Keep ids structurally realistic (`sub_test_1`, `prod_test_1`)
so decoding is still exercised.

Fixture set the tasks assume:

| File | Contents |
| --- | --- |
| `subscriptions_active.json` | 3 subs: monthly, yearly, multi-item |
| `subscriptions_edge.json` | trialing, past_due, metered, tiered, discounted, non-USD |
| `subscriptions_page1.json` / `_page2.json` | `has_more` pagination pair |
| `subscription_items_extra.json` | the `items.has_more` follow-up |
| `balance_transactions.json` | charges, refunds, fees, one payout to be excluded |
| `products.json` | names for the breakdown |
| `error_401.json`, `error_429.json` | Stripe error envelopes |

## Sandbox

Do the whole build against a Stripe **test-mode** key (`rk_test_…`) with seeded test
subscriptions. Switch to live only at T18. Test mode has its own balance transactions, so
"earned to date" will read $0 there — that is correct, not a bug.
