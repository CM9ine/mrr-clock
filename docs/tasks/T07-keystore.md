# T07 · `KeyStore` — Keychain and in-memory

**Depends on:** T01 · **Milestone:** M2

## Goal

Save, read, and delete the Stripe restricted key in the macOS Keychain, behind a protocol
with a test double.

## Read first

- [STRIPE.md § Handling rules](../STRIPE.md#handling-rules)

## Build

`Sources/MRRClockCore/KeyStore.swift`

```swift
public protocol KeyStore: Sendable {
    func read() throws -> String?     // nil when never saved
    func save(_ key: String) throws   // overwrites
    func delete() throws              // idempotent
}

public struct KeychainKeyStore: KeyStore {
    init(service: String = "com.mrrclock.app",
         account: String = "stripe.restricted_key")
}
public final class InMemoryKeyStore: KeyStore { init(_ initial: String? = nil) }
```

- Generic password item, `kSecAttrAccessibleWhenUnlocked`
- `save` on an existing item is an update, not a duplicate-item error
- `errSecItemNotFound` on read → `nil`, not a throw
- Any other OSStatus → `KeyStoreError.keychain(OSStatus)`

Plus validation, used by Settings in T17:

```swift
public enum KeyValidation { case valid, empty, wrongPrefix, tooShort }
public static func validate(_ key: String) -> KeyValidation
```

Accept `rk_live_` and `rk_test_`. Reject `sk_` with `.wrongPrefix` — a secret key would
work, and that is exactly why it must be refused.

## Tests

`Tests/MRRClockCoreTests/KeyStoreTests.swift`

**`InMemoryKeyStore`** — the contract every implementation must satisfy:

1. **`reads nil before anything is saved`**
2. **`reads back what was saved`**
3. **`saving twice keeps the second value`**
4. **`reads nil after delete`**
5. **`deleting when empty does not throw`**

**`KeychainKeyStore`** — real Keychain, with a per-run unique service name
(`"com.mrrclock.app.tests.\(UUID())"`) and cleanup in the test's teardown so it
never touches the real item:

6. **`saves and reads back a value`**
7. **`overwrites an existing item instead of failing`** — save twice, read the second
8. **`reads nil for an account that was never written`**
9. **`delete removes the item`**
10. **`two stores with different services do not see each other's keys`**

**Validation**

11. **`accepts a live restricted key`** — `"rk_live_abc123def456"` → `.valid`
12. **`accepts a test restricted key`** — `.valid`
13. **`rejects an empty string`** — `.empty`; also `"   "` → `.empty`
14. **`rejects a secret key`** — `"sk_live_abc123def456"` → `.wrongPrefix`
15. **`rejects a publishable key`** — `"pk_live_…"` → `.wrongPrefix`
16. **`rejects a key that is too short`** — `"rk_live_x"` → `.tooShort`

## Done when

All pass, and the run leaves no items behind in the real Keychain (check
Keychain Access for `MRRClock`).

## Out of scope

The settings UI (T17), which also verifies the key against Stripe by making a real call.
