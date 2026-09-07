import Foundation
import Testing
@testable import MRRClockCore

struct MoneyTests {
    @Test("init lowercases the currency code")
    func lowercaseCurrency() {
        #expect(Money(100, "USD").currency == "usd")
    }

    @Test("adding two amounts in the same currency sums the minor units")
    func addition() {
        #expect(Money(1000, "usd") + Money(250, "usd") == Money(1250, "usd"))
    }

    @Test("subtracting can produce a negative amount")
    func subtraction() {
        #expect(Money(100, "usd") - Money(250, "usd") == Money(-150, "usd"))
    }

    @Test("multiplying by a quantity scales the amount")
    func quantity() {
        #expect(Money(1000, "usd") * 3 == Money(3000, "usd"))
    }

    @Test("from(decimal:) rounds half up", arguments: [
        ("0.5", 1), ("1.5", 2), ("2.4", 2), ("2.6", 3),
        ("-0.5", -1), ("833.33", 833), ("3041.66", 3042)
    ])
    func rounding(input: String, expected: Int) throws {
        let decimal = try #require(Decimal(string: input, locale: Locale(identifier: "en_US_POSIX")))
        #expect(Money.from(decimal, "usd") == Money(expected, "usd"))
    }

    @Test("from(decimal:) is exact for values that need no rounding")
    func exactDecimal() {
        #expect(Money.from(Decimal(1000), "usd") == Money(1000, "usd"))
    }

    @Test("zero is zero in the given currency")
    func zero() {
        #expect(Money.zero("gbp") == Money(0, "gbp"))
        #expect(Money.zero("gbp").isZero)
        #expect(!Money(1, "gbp").isZero)
    }

    @Test("round-trips through Codable")
    func codable() throws {
        let original = Money(124000, "usd")
        let data = try JSONEncoder().encode(original)
        #expect(try JSONDecoder().decode(Money.self, from: data) == original)
    }

    @Test("formats US dollars with a symbol and thousands separator")
    func formatting() {
        #expect(Money(124000, "usd").formatted(locale: Locale(identifier: "en_US")) == "$1,240.00")
    }

    @Test("formats a negative amount")
    func negativeFormatting() {
        #expect(Money(-500, "usd").formatted(locale: Locale(identifier: "en_US")) == "-$5.00")
    }

    // T02 explicitly permits skipping this test: Swift Testing cannot catch a
    // precondition trap. Both binary arithmetic operators guard currency equality.
    @Test("adding different currencies traps", .disabled("Swift Testing cannot catch a precondition trap"))
    func currencyMismatch() {
        _ = Money(100, "usd") + Money(100, "gbp")
    }

    @Test("unary negation reverses the amount")
    func negation() {
        #expect(-Money(500, "usd") == Money(-500, "usd"))
    }
}
