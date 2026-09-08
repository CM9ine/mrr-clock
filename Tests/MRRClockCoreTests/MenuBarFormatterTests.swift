import Foundation
import Testing
@testable import MRRClockCore

@Test(
    "abbreviates thousands",
    arguments: [
        (0, "$0"),
        (99_900, "$999"),
        (100_000, "$1k"),
        (124_000, "$1.2k"),
        (999_900, "$10k"),
        (1_000_000, "$10k"),
        (123_456_700, "$1.2M"),
    ]
)
func abbreviatesThousands(amount: Int, expected: String) {
    let formatter = MenuBarFormatter(locale: Locale(identifier: "en_US"))

    #expect(formatter.compactMoney(Money(amount, "usd")) == expected)
}

@Test("drops a trailing .0")
func dropsTrailingZero() {
    let formatter = MenuBarFormatter(locale: Locale(identifier: "en_US"))
    #expect(formatter.compactMoney(Money(200_000, "usd")) == "$2k")
}

@Test("abbreviates a negative amount")
func abbreviatesNegativeAmount() {
    let formatter = MenuBarFormatter(locale: Locale(identifier: "en_US"))
    #expect(formatter.compactMoney(Money(-124_000, "usd")) == "-$1.2k")
}

@Test("uses the currency symbol for the money's currency")
func usesCurrencySymbol() {
    let formatter = MenuBarFormatter(locale: Locale(identifier: "en_US"))
    #expect(formatter.compactMoney(Money(124_000, "gbp")) == "£1.2k")
}

@Test("labels a normal count")
func labelsNormalCount() {
    let formatter = MenuBarFormatter(locale: Locale(identifier: "en_US"))
    #expect(formatter.daysLabel(387) == "387 days")
}

@Test("uses the singular for one day")
func usesSingularDay() {
    let formatter = MenuBarFormatter(locale: Locale(identifier: "en_US"))
    #expect(formatter.daysLabel(1) == "1 day")
}

@Test("says today for zero")
func saysTodayForZero() {
    let formatter = MenuBarFormatter(locale: Locale(identifier: "en_US"))
    #expect(formatter.daysLabel(0) == "today")
}

@Test("labels an overdue goal", arguments: [(-3, "3 days over"), (-1, "1 day over")])
func labelsOverdueGoal(days: Int, expected: String) {
    let formatter = MenuBarFormatter(locale: Locale(identifier: "en_US"))
    #expect(formatter.daysLabel(days) == expected)
}

@Test("spells out long spans", arguments: [(387, "1 year, 22 days"), (365, "1 year"), (45, "1 month, 15 days"), (20, "20 days")])
func spellsOutLongSpans(days: Int, expected: String) {
    let formatter = MenuBarFormatter(locale: Locale(identifier: "en_US"))
    #expect(formatter.longDaysLabel(days) == expected)
}

@Test("daysOnly shows the pinned goal's countdown")
func daysOnlyTitle() {
    let formatter = MenuBarFormatter(locale: Locale(identifier: "en_US"))
    let snapshot = menuSnapshot()
    #expect(formatter.title(for: snapshot, phase: .loaded(snapshot), format: .daysOnly) == "387d")
}

@Test("mrrOnly shows compact MRR")
func mrrOnlyTitle() {
    let formatter = MenuBarFormatter(locale: Locale(identifier: "en_US"))
    let snapshot = menuSnapshot()
    #expect(formatter.title(for: snapshot, phase: .loaded(snapshot), format: .mrrOnly) == "$1.2k")
}

@Test("daysAndMRR joins them")
func daysAndMRRTitle() {
    let formatter = MenuBarFormatter(locale: Locale(identifier: "en_US"))
    let snapshot = menuSnapshot()
    #expect(formatter.title(for: snapshot, phase: .loaded(snapshot), format: .daysAndMRR) == "387d · $1.2k")
}

@Test("percentAndDays shows funding progress")
func percentAndDaysTitle() {
    let formatter = MenuBarFormatter(locale: Locale(identifier: "en_US"))
    let snapshot = menuSnapshot()
    #expect(formatter.title(for: snapshot, phase: .loaded(snapshot), format: .percentAndDays) == "25% · 387d")
}

@Test("percentAndDays falls back to daysAndMRR when the goal has no target amount")
func percentAndDaysFallback() {
    let formatter = MenuBarFormatter(locale: Locale(identifier: "en_US"))
    let snapshot = menuSnapshot(targetAmount: nil, percentFunded: nil)
    #expect(formatter.title(for: snapshot, phase: .loaded(snapshot), format: .percentAndDays) == "387d · $1.2k")
}

@Test("shows a setup prompt when there is no key")
func setupPrompt() {
    let formatter = MenuBarFormatter(locale: Locale(identifier: "en_US"))
    #expect(formatter.title(for: nil, phase: .needsSetup, format: .daysAndMRR) == "Set up")
}

@Test("shows an add-goal prompt when there are no goals")
func addGoalPrompt() {
    let formatter = MenuBarFormatter(locale: Locale(identifier: "en_US"))
    #expect(formatter.title(for: nil, phase: .noGoals, format: .daysAndMRR) == "Add a goal")
}

@Test("marks a stale title")
func marksStaleTitle() {
    let formatter = MenuBarFormatter(locale: Locale(identifier: "en_US"))
    let snapshot = menuSnapshot()
    #expect(formatter.title(for: snapshot, phase: .stale(snapshot, .notFound), format: .daysAndMRR) == "387d · $1.2k ⚠")
}

@Test("shows the countdown but not the money when stale with no snapshot")
func staleWithoutSnapshot() {
    let formatter = MenuBarFormatter(locale: Locale(identifier: "en_US"))
    let localProgress = menuSnapshot()
    #expect(formatter.title(for: localProgress, phase: .stale(nil, .notFound), format: .daysAndMRR) == "387d · —")
}

@Test("shows an overdue title")
func overdueTitle() {
    let formatter = MenuBarFormatter(locale: Locale(identifier: "en_US"))
    let snapshot = menuSnapshot(daysRemaining: -3)
    #expect(formatter.title(for: snapshot, phase: .loaded(snapshot), format: .daysAndMRR) == "3d over · $1.2k")
}

@Test("title stays under sixteen characters", arguments: TitleFormat.allCases)
func titleLength(format: TitleFormat) {
    let formatter = MenuBarFormatter(locale: Locale(identifier: "en_US"))
    let snapshot = menuSnapshot(mrr: Money(123_456_700, "usd"))
    #expect(formatter.title(for: snapshot, phase: .loaded(snapshot), format: format).count < 16)
}

@Test("describes a recent sync", arguments: [(5, "just now"), (90, "1m ago"), (600, "10m ago"), (7_200, "2h ago"), (172_800, "2d ago")])
func describesRecentSync(seconds: Int, expected: String) {
    let formatter = MenuBarFormatter(locale: Locale(identifier: "en_US"))
    let now = Date(iso: "2026-09-07T09:00:00Z")
    #expect(formatter.relativeSync(now.addingTimeInterval(TimeInterval(-seconds)), now: now) == expected)
}

@Test("formats a percent", arguments: [(Decimal(string: "0.25"), "25%"), (Decimal(string: "1.2"), "120%"), (Decimal(string: "0.005"), "1%"), (nil, "—"), (Decimal(string: "-0.1"), "-10%")])
func formatsPercent(ratio: Decimal?, expected: String) {
    let formatter = MenuBarFormatter(locale: Locale(identifier: "en_US"))
    #expect(formatter.percentLabel(ratio) == expected)
}

private func menuSnapshot(
    mrr: Money = Money(124_000, "usd"),
    targetAmount: Money? = Money(400_000, "usd"),
    daysRemaining: Int = 387,
    percentFunded: Decimal? = Decimal(string: "0.25")
) -> Snapshot {
    let syncedAt = Date(iso: "2026-09-07T09:00:00Z")
    return Snapshot(
        syncedAt: syncedAt,
        revenue: RevenueSnapshot(mrr: mrr, earnedToDate: Money(100_000, "usd"), breakdown: [], subscriptionCount: 1, churnRisk: .zero("usd"), warnings: []),
        goals: [GoalProgress(goalID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, name: "Launch", targetDate: syncedAt, targetAmount: targetAmount, daysRemaining: daysRemaining, projected: Money(200_000, "usd"), percentFunded: percentFunded, percentOnTrack: Decimal(string: "0.5"), isPinned: true)],
        specVersion: metricsSpecVersion
    )
}
