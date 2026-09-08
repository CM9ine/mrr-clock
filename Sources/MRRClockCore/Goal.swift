import Foundation

/// A user-authored target following docs/METRICS.md § Goal.
public struct Goal: Identifiable, Equatable, Codable, Sendable {
    public let id: UUID
    public var name: String
    public var targetDate: Date
    public var targetAmount: Money?
    public let createdAt: Date
    public var sortIndex: Int

    /// Creates a goal and stores its user-facing name without surrounding whitespace.
    public init(
        id: UUID = UUID(),
        name: String,
        targetDate: Date,
        targetAmount: Money? = nil,
        createdAt: Date,
        sortIndex: Int
    ) {
        self.id = id
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.targetDate = targetDate
        self.targetAmount = targetAmount
        self.createdAt = createdAt
        self.sortIndex = sortIndex
    }

    /// Validates goal input using docs/METRICS.md § Goal.
    public static func validate(name: String, targetAmount: Money?, config: Config) -> GoalValidation {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return .emptyName }
        guard trimmedName.count <= 60 else { return .nameTooLong }
        if let targetAmount {
            guard targetAmount.amount > 0 else { return .nonPositiveAmount }
            guard targetAmount.currency == config.currency else {
                return .currencyMismatch(expected: config.currency, got: targetAmount.currency)
            }
        }
        return .valid
    }
}

/// The validation outcomes defined by docs/METRICS.md § Goal.
public enum GoalValidation: Equatable, Sendable {
    case valid
    case emptyName
    case nameTooLong
    case nonPositiveAmount
    case currencyMismatch(expected: String, got: String)
}
