import Testing
import Foundation
@testable import MRRClockCore

@Suite("InMemoryKeyStore")
struct InMemoryKeyStoreTests {
    @Test("reads nil before anything is saved")
    func readsNilInitially() throws {
        let store = InMemoryKeyStore()

        #expect(try store.read() == nil)
    }

    @Test("reads back what was saved")
    func readsSavedValue() throws {
        let store = InMemoryKeyStore()

        try store.save("saved value")

        #expect(try store.read() == "saved value")
    }

    @Test("saving twice keeps the second value")
    func savingTwiceKeepsSecondValue() throws {
        let store = InMemoryKeyStore()

        try store.save("first value")
        try store.save("second value")

        #expect(try store.read() == "second value")
    }

    @Test("reads nil after delete")
    func readsNilAfterDelete() throws {
        let store = InMemoryKeyStore("saved value")

        try store.delete()

        #expect(try store.read() == nil)
    }

    @Test("deleting when empty does not throw")
    func deletingWhenEmptyDoesNotThrow() throws {
        let store = InMemoryKeyStore()

        try store.delete()
    }
}

@Suite("KeychainKeyStore")
struct KeychainKeyStoreTests {
    @Test("saves and reads back a value")
    func savesAndReadsValue() throws {
        let store = KeychainKeyStore(service: "com.mrrclock.app.tests.\(UUID())")
        defer { try? store.delete() }

        try store.save("saved value")

        #expect(try store.read() == "saved value")
    }

    @Test("overwrites an existing item instead of failing")
    func overwritesExistingItem() throws {
        let store = KeychainKeyStore(service: "com.mrrclock.app.tests.\(UUID())")
        defer { try? store.delete() }

        try store.save("first value")
        try store.save("second value")

        #expect(try store.read() == "second value")
    }

    @Test("reads nil for an account that was never written")
    func readsNilForMissingAccount() throws {
        let store = KeychainKeyStore(service: "com.mrrclock.app.tests.\(UUID())")
        defer { try? store.delete() }

        #expect(try store.read() == nil)
    }

    @Test("delete removes the item")
    func deleteRemovesItem() throws {
        let store = KeychainKeyStore(service: "com.mrrclock.app.tests.\(UUID())")
        defer { try? store.delete() }
        try store.save("saved value")

        try store.delete()

        #expect(try store.read() == nil)
    }

    @Test("two stores with different services do not see each other's keys")
    func differentServicesAreIsolated() throws {
        let first = KeychainKeyStore(service: "com.mrrclock.app.tests.\(UUID())")
        let second = KeychainKeyStore(service: "com.mrrclock.app.tests.\(UUID())")
        defer {
            try? first.delete()
            try? second.delete()
        }

        try first.save("first service value")

        #expect(try second.read() == nil)
    }
}

@Suite("KeyValidation")
struct KeyValidationTests {
    @Test("accepts a live restricted key")
    func acceptsLiveRestrictedKey() {
        #expect(KeyValidation.validate("rk_live_abc123def456") == .valid)
    }

    @Test("accepts a test restricted key")
    func acceptsTestRestrictedKey() {
        #expect(KeyValidation.validate("rk_test_abc123def456") == .valid)
    }

    @Test("rejects an empty string")
    func rejectsEmptyString() {
        #expect(KeyValidation.validate("") == .empty)
        #expect(KeyValidation.validate("   ") == .empty)
    }

    @Test("rejects a secret key")
    func rejectsSecretKey() {
        #expect(KeyValidation.validate("sk_live_abc123def456") == .wrongPrefix)
    }

    @Test("rejects a publishable key")
    func rejectsPublishableKey() {
        #expect(KeyValidation.validate("pk_live_abc123def456") == .wrongPrefix)
    }

    @Test("rejects a key that is too short")
    func rejectsTooShortKey() {
        #expect(KeyValidation.validate("rk_live_x") == .tooShort)
    }
}
