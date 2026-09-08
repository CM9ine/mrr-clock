import Foundation

/// Offline goal-editing state backed only by cached revenue, following
/// `docs/ARCHITECTURE.md` § Data flow and `docs/METRICS.md` § Goal.
public struct GoalEditorModel: Sendable {
    public var name: String
    public var targetDate: Date?
    public var amountText: String
    public let existingGoal: Goal?

    private let config: Config
    private let revenue: RevenueSnapshot
    private let clock: any Clock
    private let calendar: Calendar
    private let locale: Locale

    public init(goal: Goal? = nil, config: Config, revenue: RevenueSnapshot, clock: any Clock, calendar: Calendar = .current, locale: Locale = .current) {
        existingGoal = goal
        name = goal?.name ?? ""
        targetDate = goal?.targetDate
        amountText = goal?.targetAmount.map { Self.amountString($0) } ?? ""
        self.config = config
        self.revenue = revenue
        self.clock = clock
        self.calendar = calendar
        self.locale = locale
    }

    public var targetAmount: Money? {
        amountText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? nil : AmountParser.parse(amountText, currency: config.currency, locale: locale)
    }

    public var validation: GoalValidation {
        if !amountText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, targetAmount == nil { return .nonPositiveAmount }
        return Goal.validate(name: name, targetAmount: targetAmount, config: config)
    }

    public var validationMessage: String? {
        switch validation {
        case .valid: nil
        case .emptyName: "Enter a goal name."
        case .nameTooLong: "Goal names can contain at most 60 characters."
        case .nonPositiveAmount: "Enter an amount greater than zero."
        case let .currencyMismatch(expected, _): "Enter an amount in \(expected.uppercased())."
        }
    }

    public var canSave: Bool { validation == .valid && targetDate != nil }

    public var preview: GoalEditorPreview? {
        guard let targetDate else { return nil }
        let days = Countdown.daysRemaining(now: clock.now, target: targetDate, calendar: calendar)
        let projected = Projection().project(.init(earnedToDate: revenue.earnedToDate, mrr: revenue.mrr, now: clock.now, targetDate: targetDate, monthlyGrowthRate: config.monthlyGrowthRate, calendar: calendar)).projected
        let percent = targetAmount.map { target in
            var value = Decimal(projected.amount) / Decimal(target.amount) * 100
            var rounded = Decimal()
            NSDecimalRound(&rounded, &value, 0, .plain)
            return "\(NSDecimalNumber(decimal: rounded).intValue) %"
        } ?? "—"
        return GoalEditorPreview(days: days == 1 ? "1 day" : "\(days) days", projected: projected, percent: percent)
    }

    private static func amountString(_ money: Money) -> String {
        let sign = money.amount < 0 ? "-" : ""
        let absolute = abs(money.amount)
        return "\(sign)\(absolute / 100).\(String(format: "%02d", absolute % 100))"
    }
}

/// Cached, display-ready values for the goal editor preview.
public struct GoalEditorPreview: Equatable, Sendable {
    public let days: String
    public let projected: Money
    public let percent: String
}
