import Foundation

/// Calendar-day countdowns following docs/METRICS.md § Countdown.
public struct Countdown: Sendable {
    /// Returns the signed day difference between local starts of day in the supplied
    /// calendar. Same-day targets return zero; past targets remain negative.
    /// See docs/METRICS.md § Countdown.
    public static func daysRemaining(
        now: Date, target: Date, calendar: Calendar = .current
    ) -> Int {
        calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: now),
            to: calendar.startOfDay(for: target)
        ).day!
    }
}

/// Supplies time to the calendar calculations in docs/METRICS.md § Countdown.
public protocol Clock: Sendable {
    /// The instant to use as now; consumers never read the system clock directly.
    var now: Date { get }
}

/// The live time adapter; the sole Date() exception in docs/TDD.md.
public struct SystemClock: Clock {
    /// Creates a live clock for production use.
    public init() {}

    /// Reads the current system time for the injected Clock seam.
    public var now: Date { Date() }
}

/// Supplies a fixed instant for deterministic calculations per docs/METRICS.md § Countdown.
public struct FixedClock: Clock {
    /// The exact instant supplied at initialization.
    public let now: Date

    /// Creates a clock that always returns the supplied instant.
    public init(at instant: Date) {
        now = instant
    }
}
