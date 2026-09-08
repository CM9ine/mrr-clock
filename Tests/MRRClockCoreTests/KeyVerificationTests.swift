import Foundation
import Testing
@testable import MRRClockCore

private final class CountingKeyStore: KeyStore, @unchecked Sendable {
    var key: String?
    var writeCount = 0
    func read() throws -> String? { key }
    func save(_ key: String) throws { self.key = key; writeCount += 1 }
    func delete() throws { key = nil }
}

@Test("accepts a working key")
func acceptsWorkingKey() async {
    let store = CountingKeyStore()
    let result = await KeyVerifier().verify("rk_test_abcdefghijkl", api: FakeStripeClient(), keyStore: store)
    #expect(result == .verified)
}

@Test("reports a rejected key")
func reportsRejectedKey() async {
    let store = CountingKeyStore()
    let result = await KeyVerifier().verify("rk_test_abcdefghijkl", api: FakeStripeClient(error: .unauthorized), keyStore: store)
    #expect(result == .rejected("Stripe rejected this key (unauthorized)."))
    #expect(store.key == nil)
}

@Test("reports a key that is missing a permission")
func reportsMissingPermission() async {
    let result = await KeyVerifier().verify("rk_test_abcdefghijkl", api: FakeStripeClient(error: .forbidden(resource: "balance transactions")), keyStore: CountingKeyStore())
    #expect(result == .rejected("This key cannot read balance transactions."))
}

@Test("saves the key only after verification succeeds")
func savesOnlyAfterVerification() async {
    let failed = CountingKeyStore()
    _ = await KeyVerifier().verify("rk_test_abcdefghijkl", api: FakeStripeClient(error: .unauthorized), keyStore: failed)
    #expect(failed.writeCount == 0)
    let working = CountingKeyStore()
    _ = await KeyVerifier().verify("rk_test_abcdefghijkl", api: FakeStripeClient(), keyStore: working)
    #expect(working.writeCount == 1)
}

@Test("shows only the last four characters once saved")
func redactsSavedKey() {
    let display = KeyVerifier.displayString(for: "rk_live_abcdef2f9c")
    #expect(display == "rk_live_••••2f9c")
    #expect(!display.contains("abcdef"))
}
