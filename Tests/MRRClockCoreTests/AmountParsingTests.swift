import Foundation
import Testing
@testable import MRRClockCore

@Test("parses a plain number")
func parsesPlainNumber() {
    #expect(AmountParser.parse("50000", currency: "usd", locale: Locale(identifier: "en_US")) == Money(5_000_000, "usd"))
}

@Test("parses decimals")
func parsesDecimals() {
    #expect(AmountParser.parse("1234.56", currency: "usd", locale: Locale(identifier: "en_US")) == Money(123_456, "usd"))
}

@Test("ignores grouping separators")
func ignoresGroupingSeparators() {
    #expect(AmountParser.parse("50,000", currency: "usd", locale: Locale(identifier: "en_US")) == Money(5_000_000, "usd"))
    #expect(AmountParser.parse("50 000", currency: "usd", locale: Locale(identifier: "en_US")) == Money(5_000_000, "usd"))
}

@Test("ignores a leading currency symbol")
func ignoresLeadingCurrencySymbol() {
    #expect(AmountParser.parse("$50,000", currency: "usd", locale: Locale(identifier: "en_US")) == Money(5_000_000, "usd"))
}

@Test("rejects junk")
func rejectsJunk() {
    for input in ["", "abc", "1.2.3", "-"] {
        #expect(AmountParser.parse(input, currency: "usd", locale: Locale(identifier: "en_US")) == nil)
    }
}

@Test("rounds beyond two decimal places half up")
func roundsBeyondTwoPlacesHalfUp() {
    #expect(AmountParser.parse("1.005", currency: "usd", locale: Locale(identifier: "en_US")) == Money(101, "usd"))
}

@Test("parses in a comma-decimal locale")
func parsesCommaDecimalLocale() {
    #expect(AmountParser.parse("1.234,56", currency: "usd", locale: Locale(identifier: "de_DE")) == Money(123_456, "usd"))
}
