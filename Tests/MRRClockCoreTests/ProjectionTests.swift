import Foundation
import Testing
@testable import MRRClockCore

struct ProjectionTests {
    private let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private func input(
        earned: Money = Money(0, "usd"),
        mrr: Money = Money(0, "usd"),
        now: String = "2026-09-07T09:00:00Z",
        target: String = "2027-09-29T00:00:00Z",
        growth: Decimal = 0
    ) -> ProjectionInput {
        ProjectionInput(
            earnedToDate: earned,
            mrr: mrr,
            now: Date(iso: now),
            targetDate: Date(iso: target),
            monthlyGrowthRate: growth,
            calendar: utc
        )
    }

    @Test("splits the real deadline into whole and partial months")
    func realDeadlineSplit() {
        let result = Projection().project(input())

        #expect(result.wholeMonths == 12)
        #expect(result.partialMonth == Decimal(22) / Decimal(30))
    }

    @Test("a target exactly n months out has no partial month")
    func exactMonths() {
        let result = Projection().project(input(target: "2027-09-07T00:00:00Z"))
        #expect(result.wholeMonths == 12)
        #expect(result.partialMonth == 0)
    }

    @Test("a target inside the same month is all partial")
    func sameMonth() {
        let result = Projection().project(input(target: "2026-09-22T00:00:00Z"))
        #expect(result.wholeMonths == 0)
        #expect(result.partialMonth == Decimal(15) / Decimal(30))
    }

    @Test("a past target is zero months")
    func pastSplit() {
        let result = Projection().project(input(target: "2026-09-06T00:00:00Z"))
        #expect(result.wholeMonths == 0)
        #expect(result.partialMonth == 0)
    }

    @Test("today is zero months")
    func todaySplit() {
        let result = Projection().project(input(target: "2026-09-07T09:00:00Z"))
        #expect(result.wholeMonths == 0)
        #expect(result.partialMonth == 0)
    }

    @Test("projects MRR across whole months")
    func flatWholeMonths() {
        let result = Projection().project(input(mrr: Money(10_000, "usd"), target: "2027-09-07T00:00:00Z"))
        #expect(result.projected == Money(120_000, "usd"))
    }

    @Test("adds earnings already banked")
    func addsEarned() {
        let result = Projection().project(input(earned: Money(50_000, "usd"), mrr: Money(10_000, "usd"), target: "2027-09-07T00:00:00Z"))
        #expect(result.projected == Money(170_000, "usd"))
    }

    @Test("counts a partial month pro rata")
    func flatPartialMonth() {
        let result = Projection().project(input(mrr: Money(10_000, "usd"), target: "2027-09-22T00:00:00Z"))
        #expect(result.projected == Money(125_000, "usd"))
    }

    @Test("zero MRR projects exactly what is already earned")
    func zeroMRR() {
        let result = Projection().project(input(earned: Money(50_000, "usd")))
        #expect(result.projected == Money(50_000, "usd"))
    }

    @Test("a past target projects exactly what is already earned")
    func pastProjection() {
        let result = Projection().project(input(earned: Money(50_000, "usd"), mrr: Money(10_000, "usd"), target: "2026-09-06T00:00:00Z"))
        #expect(result.projected == Money(50_000, "usd"))
    }

    @Test("compounds two months at ten percent")
    func twoMonthsCompounded() {
        let result = Projection().project(input(mrr: Money(10_000, "usd"), target: "2026-11-07T00:00:00Z", growth: Decimal(string: "0.10")!))
        #expect(result.projected == Money(21_000, "usd"))
    }

    @Test("compounds three months at ten percent")
    func threeMonthsCompounded() {
        let result = Projection().project(input(mrr: Money(10_000, "usd"), target: "2026-12-07T00:00:00Z", growth: Decimal(string: "0.10")!))
        #expect(result.projected == Money(33_100, "usd"))
    }

    @Test("compounds the partial month at the final rate")
    func partialMonthCompounded() {
        let result = Projection().project(input(mrr: Money(10_000, "usd"), target: "2026-11-22T00:00:00Z", growth: Decimal(string: "0.10")!))
        #expect(result.projected == Money(27_050, "usd"))
    }

    @Test("reports MRR at the target date")
    func targetMRR() {
        let result = Projection().project(input(mrr: Money(10_000, "usd"), target: "2027-09-07T00:00:00Z", growth: Decimal(string: "0.10")!))
        #expect(result.mrrAtTarget == Money(31_384, "usd"))
    }

    @Test("a negative growth rate shrinks the projection")
    func negativeGrowth() {
        let result = Projection().project(input(mrr: Money(10_000, "usd"), target: "2026-11-07T00:00:00Z", growth: Decimal(string: "-0.10")!))
        #expect(result.projected == Money(19_000, "usd"))
    }

    @Test("projects for any target date, not just one")
    func arbitraryTargets() {
        let january = Projection().project(input(mrr: Money(10_000, "usd"), target: "2027-01-31T00:00:00Z"))
        let june = Projection().project(input(mrr: Money(10_000, "usd"), target: "2028-06-15T00:00:00Z"))
        #expect(january.projected == Money(47_742, "usd"))
        #expect(june.projected == Money(212_667, "usd"))
    }

    @Test("reproduces a row from the plan")
    func planReconciliation() {
        let result = Projection().project(input(mrr: Money(50_000, "usd"), growth: Decimal(string: "0.10")!))
        #expect(result.projected == Money(1_184_290, "usd"))
    }

    @Test("currency is preserved")
    func preservesCurrency() {
        let result = Projection().project(input(earned: Money(1_000, "gbp"), mrr: Money(10_000, "gbp")))
        #expect(result.projected.currency == "gbp")
        #expect(result.mrrAtTarget.currency == "gbp")
    }

    @Test("mismatched currencies between earned and MRR are rejected", .disabled("Swift Testing cannot catch a precondition trap"))
    func currencyMismatch() {
        _ = Projection().project(input(earned: Money(0, "usd"), mrr: Money(10_000, "gbp")))
    }
}
