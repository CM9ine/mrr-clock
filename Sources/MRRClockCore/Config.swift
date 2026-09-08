import Foundation

/// The menu-bar title layouts stored with user settings.
public enum TitleFormat: String, Equatable, Codable, CaseIterable, Sendable {
    case daysOnly, mrrOnly, daysAndMRR, percentAndDays
}

/// Calculator and display settings described by docs/ARCHITECTURE.md § Storage.
public struct Config: Equatable, Codable, Sendable {
    public var currency: String
    public var includeTrials: Bool
    /// Maximum named product lines before the tail becomes Other (METRICS.md § Breakdown by product).
    public var breakdownLimit: Int
    /// First instant included in earned-to-date totals (METRICS.md § Earned to date).
    public var earningsStartDate: Date
    /// Monthly growth assumption used by METRICS.md § Projection.
    public var monthlyGrowthRate: Decimal
    public var refreshInterval: TimeInterval
    public var titleFormat: TitleFormat

    public init(
        currency: String = "usd",
        includeTrials: Bool = false,
        breakdownLimit: Int = 3,
        earningsStartDate: Date = .distantPast,
        monthlyGrowthRate: Decimal = 0,
        refreshInterval: TimeInterval = 900,
        titleFormat: TitleFormat = .daysAndMRR
    ) {
        self.currency = currency.lowercased()
        self.includeTrials = includeTrials
        self.breakdownLimit = breakdownLimit
        self.earningsStartDate = earningsStartDate
        self.monthlyGrowthRate = monthlyGrowthRate
        self.refreshInterval = refreshInterval
        self.titleFormat = titleFormat
    }

    /// Defaults earnings to the first day of the current calendar year.
    public static let `default`: Config = {
        let calendar = Calendar.current
        let start = calendar.date(from: calendar.dateComponents([.year], from: SystemClock().now))!
        return Config(earningsStartDate: start)
    }()
}
