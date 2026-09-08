import Foundation
import Security

/// Stores the Stripe restricted key according to the Keychain handling rules in
/// `docs/STRIPE.md`.
public protocol KeyStore: Sendable {
    func read() throws -> String?
    func save(_ key: String) throws
    func delete() throws
}

/// Errors produced while accessing the macOS Keychain.
public enum KeyStoreError: Error, Equatable, Sendable {
    case keychain(OSStatus)
}

/// The local format check applied before a Stripe key is stored, following the
/// restricted-key requirement in `docs/STRIPE.md`.
public enum KeyValidation: Equatable, Sendable {
    case valid
    case empty
    case wrongPrefix
    case tooShort

    public static func validate(_ key: String) -> KeyValidation {
        if key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return .empty }
        let prefixes = ["rk_live_", "rk_test_"]
        guard let prefix = prefixes.first(where: key.hasPrefix) else { return .wrongPrefix }
        guard key.dropFirst(prefix.count).count >= 12 else { return .tooShort }
        return .valid
    }
}

/// Stores the Stripe restricted key as a generic-password Keychain item under
/// the service and account prescribed by `docs/STRIPE.md`.
public struct KeychainKeyStore: KeyStore {
    private let service: String
    private let account: String

    public init(
        service: String = "com.mrrclock.app",
        account: String = "stripe.restricted_key"
    ) {
        self.service = service
        self.account = account
    }

    public func read() throws -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw KeyStoreError.keychain(status) }
        guard let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else {
            throw KeyStoreError.keychain(errSecDecode)
        }
        return key
    }

    public func save(_ key: String) throws {
        var query = baseQuery
        query[kSecValueData as String] = Data(key.utf8)
        query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlocked
        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecDuplicateItem {
            let attributes = [kSecValueData as String: Data(key.utf8)]
            let updateStatus = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)
            guard updateStatus == errSecSuccess else {
                throw KeyStoreError.keychain(updateStatus)
            }
            return
        }
        guard status == errSecSuccess else { throw KeyStoreError.keychain(status) }
    }

    public func delete() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeyStoreError.keychain(status)
        }
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}

/// An in-process key store for tests and previews.
public final class InMemoryKeyStore: KeyStore, @unchecked Sendable {
    private let lock = NSLock()
    private var key: String?

    public init(_ initial: String? = nil) {
        key = initial
    }

    public func read() throws -> String? {
        lock.withLock { key }
    }

    public func save(_ key: String) throws {
        lock.withLock { self.key = key }
    }

    public func delete() throws {
        lock.withLock { key = nil }
    }
}
