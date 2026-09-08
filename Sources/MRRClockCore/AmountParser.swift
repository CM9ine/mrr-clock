import Foundation

/// Parses a user-entered major-unit amount into integer minor units under
/// `docs/METRICS.md` § Money representation.
public enum AmountParser {
    public static func parse(_ text: String, currency: String, locale: Locale = .current) -> Money? {
        let grouping = locale.groupingSeparator ?? ","
        var normalized = text.replacingOccurrences(of: grouping, with: "")
            .replacingOccurrences(of: " ", with: "")
        if normalized.first?.isCurrencySymbol == true { normalized.removeFirst() }
        let decimalSeparator = locale.decimalSeparator ?? "."
        if decimalSeparator != "." {
            normalized = normalized.replacingOccurrences(of: decimalSeparator, with: ".")
        }
        guard !normalized.isEmpty,
              normalized.allSatisfy({ $0.isNumber || $0 == "." }),
              normalized.filter({ $0 == "." }).count <= 1,
              let amount = Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX")) else { return nil }
        return Money.from(amount * 100, currency)
    }
}

private extension Character {
    var isCurrencySymbol: Bool { unicodeScalars.allSatisfy { $0.properties.generalCategory == .currencySymbol } }
}
