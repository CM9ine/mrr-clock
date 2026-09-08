import Foundation

/// Produces deterministic menu-bar display strings from snapshot values using the
/// money and percentage rules in docs/METRICS.md.
public struct MenuBarFormatter: Sendable {
    private let locale: Locale

    public init(locale: Locale = .current) {
        self.locale = locale
    }

    /// Abbreviates integer minor units without converting money through `Double`.
    public func compactMoney(_ money: Money) -> String {
        let amount = Decimal(money.amount) / 100
        let magnitude = amount.magnitude
        let divisor: Decimal
        let suffix: String
        if magnitude >= 1_000_000 {
            divisor = 1_000_000
            suffix = "M"
        } else if magnitude >= 1_000 {
            divisor = 1_000
            suffix = "k"
        } else {
            divisor = 1
            suffix = ""
        }

        let abbreviated = amount / divisor
        let number = NumberFormatter()
        number.locale = locale
        number.numberStyle = .currency
        number.currencyCode = money.currency.uppercased()
        number.minimumFractionDigits = 0
        number.maximumFractionDigits = abbreviated.magnitude < 10 && !suffix.isEmpty ? 1 : 0
        number.roundingMode = .halfUp
        return number.string(from: NSDecimalNumber(decimal: abbreviated))! + suffix
    }

    /// Labels a calendar-day countdown according to docs/METRICS.md § Countdown.
    public func daysLabel(_ days: Int) -> String {
        switch days {
        case 0: return "today"
        case 1: return "1 day"
        case let value where value > 1: return "\(value) days"
        case -1: return "1 day over"
        default: return "\(-days) days over"
        }
    }

    /// Spells positive countdown spans using the fixed 365-day year and 30-day month display convention.
    public func longDaysLabel(_ days: Int) -> String {
        guard days > 0 else { return daysLabel(days) }
        let years = days / 365
        let afterYears = days % 365
        let months = afterYears / 30
        let remainingDays = afterYears % 30
        var parts: [String] = []
        if years > 0 { parts.append("\(years) \(years == 1 ? "year" : "years")") }
        if months > 0 { parts.append("\(months) \(months == 1 ? "month" : "months")") }
        if remainingDays > 0 { parts.append("\(remainingDays) \(remainingDays == 1 ? "day" : "days")") }
        return parts.joined(separator: ", ")
    }

    /// Formats the pinned goal and account MRR for the current application phase.
    public func title(for snapshot: Snapshot?, phase: AppPhase, format: TitleFormat) -> String {
        switch phase {
        case .needsSetup: return "Set up"
        case .noGoals: return "Add a goal"
        default: break
        }
        guard let snapshot, let goal = snapshot.goals.first(where: { $0.isPinned }) else { return "—" }
        let days = compactDays(goal.daysRemaining)
        let hasRemoteSnapshot: Bool
        let isStale: Bool
        switch phase {
        case let .stale(previous, _):
            hasRemoteSnapshot = previous != nil
            isStale = previous != nil
        default:
            hasRemoteSnapshot = true
            isStale = false
        }
        let money = hasRemoteSnapshot ? compactMoney(snapshot.revenue.mrr) : "—"
        let base: String
        switch format {
        case .daysOnly: base = days
        case .mrrOnly: base = money
        case .daysAndMRR: base = "\(days) · \(money)"
        case .percentAndDays:
            base = goal.targetAmount == nil ? "\(days) · \(money)" : "\(percentLabel(goal.percentFunded)) · \(days)"
        }
        return isStale ? "\(base) ⚠" : base
    }

    /// Describes elapsed time from an explicitly supplied current instant.
    public func relativeSync(_ syncedAt: Date, now: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(syncedAt)))
        if seconds < 60 { return "just now" }
        if seconds < 3_600 { return "\(seconds / 60)m ago" }
        if seconds < 86_400 { return "\(seconds / 3_600)h ago" }
        return "\(seconds / 86_400)d ago"
    }

    /// Renders a METRICS.md percent-funded ratio as a whole percent, rounded half up.
    public func percentLabel(_ ratio: Decimal?) -> String {
        guard var percent = ratio.map({ $0 * 100 }) else { return "—" }
        var rounded = Decimal()
        NSDecimalRound(&rounded, &percent, 0, .plain)
        return "\(NSDecimalNumber(decimal: rounded).stringValue)%"
    }

    private func compactDays(_ days: Int) -> String {
        if days < 0 { return "\(-days)d over" }
        return "\(days)d"
    }
}
