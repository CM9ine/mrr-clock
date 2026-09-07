import Foundation

/// Integer minor units with explicit currency (METRICS.md § Money representation).
public struct Money: Equatable, Hashable, Codable, Sendable {
    /// The amount in minor units, as required by METRICS.md § Money representation.
    public let amount: Int
    /// Lowercase currency code (METRICS.md § Money representation).
    public let currency: String

    /// Creates an amount and normalizes its currency (METRICS.md § Money representation).
    public init(_ amount: Int, _ currency: String) {
        self.amount = amount
        self.currency = currency.lowercased()
    }
    /// Adds matching currencies (METRICS.md § Money representation); mismatches trap.
    public static func + (lhs: Money, rhs: Money) -> Money {
        precondition(lhs.currency == rhs.currency, "Currency mismatch")
        return Money(lhs.amount + rhs.amount, lhs.currency)
    }

    /// Subtracts matching currencies (METRICS.md § Money representation); mismatches trap.
    public static func - (lhs: Money, rhs: Money) -> Money {
        precondition(lhs.currency == rhs.currency, "Currency mismatch")
        return Money(lhs.amount - rhs.amount, lhs.currency)
    }

    /// Scales minor units by an integer quantity (METRICS.md § Money representation).
    public static func * (lhs: Money, rhs: Int) -> Money {
        Money(lhs.amount * rhs, lhs.currency)
    }

    /// Rounds Decimal minor units half up (METRICS.md § Money representation).
    public static func from(_ decimal: Decimal, _ currency: String) -> Money {
        var value = decimal
        var rounded = Decimal()
        NSDecimalRound(&rounded, &value, 0, .plain)
        return Money(NSDecimalNumber(decimal: rounded).intValue, currency)
    }

    /// Reports zero minor units (METRICS.md § Money representation).
    public var isZero: Bool { amount == 0 }

    /// Creates zero in the specified currency (METRICS.md § Money representation).
    public static func zero(_ currency: String) -> Money { Money(0, currency) }

    /// Formats cents using the locale's currency style (METRICS.md § Money representation).
    public func formatted(locale: Locale) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .currency
        formatter.currencyCode = currency.uppercased()
        return formatter.string(from: NSDecimalNumber(decimal: Decimal(amount) / 100))!
    }

    /// Negates minor units, preserving currency (METRICS.md § Money representation).
    public static prefix func - (value: Money) -> Money {
        Money(-value.amount, value.currency)
    }
}
