import Foundation

/// Result of validating a restricted key with Stripe before persistence.
public enum KeyVerification: Equatable, Sendable {
    case verified
    case rejected(String)
}

/// Verifies access through the Stripe seam and saves only successful keys, per
/// `docs/STRIPE.md` § Handling rules.
public struct KeyVerifier: Sendable {
    public init() {}

    public func verify(_ key: String, api: any StripeAPI, keyStore: any KeyStore) async -> KeyVerification {
        switch KeyValidation.validate(key) {
        case .valid: break
        case .empty: return .rejected("Enter a restricted Stripe key.")
        case .wrongPrefix: return .rejected("Use a restricted key beginning with rk_, not a secret key.")
        case .tooShort: return .rejected("This restricted key is too short.")
        }

        do {
            _ = try await api.activeSubscriptions(includeTrials: false)
            _ = try await api.balanceTransactions(since: .distantPast)
            _ = try await api.products()
            try keyStore.save(key)
            return .verified
        } catch StripeError.unauthorized {
            return .rejected("Stripe rejected this key (unauthorized).")
        } catch let StripeError.forbidden(resource) {
            return .rejected("This key cannot read \(resource).")
        } catch {
            return .rejected(String(describing: error))
        }
    }

    public static func displayString(for key: String) -> String {
        let prefix = key.hasPrefix("rk_live_") ? "rk_live_" : "rk_test_"
        return prefix + "••••" + key.suffix(4)
    }
}
