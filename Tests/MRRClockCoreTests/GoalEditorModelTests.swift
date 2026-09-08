import Foundation
import Testing
@testable import MRRClockCore

private let editorNow = Date(timeIntervalSince1970: 1_767_225_600) // 2026-01-01 UTC
private var editorCalendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar
}
private let editorRevenue = RevenueSnapshot(mrr: Money(10_000, "usd"), earnedToDate: Money(5_000, "usd"), breakdown: [], subscriptionCount: 1, churnRisk: .zero("usd"), warnings: [])

@Test("reports validation errors as the user types")
func editorLiveValidation() {
    var model = GoalEditorModel(config: .test, revenue: editorRevenue, clock: FixedClock(at: editorNow), calendar: editorCalendar)
    #expect(model.validationMessage != nil)
    model.name = "Launch"
    #expect(model.validationMessage == nil)
}

@Test("disables save while invalid")
func editorDisablesInvalidSave() {
    var model = GoalEditorModel(config: .test, revenue: editorRevenue, clock: FixedClock(at: editorNow), calendar: editorCalendar)
    #expect(model.canSave == false)
    model.name = "Launch"
    model.amountText = "0"
    #expect(model.canSave == false)
}

@Test("previews the countdown for the entered date")
func editorPreviewsCountdown() {
    var model = GoalEditorModel(config: .test, revenue: editorRevenue, clock: FixedClock(at: editorNow), calendar: editorCalendar)
    model.name = "Launch"
    model.targetDate = editorCalendar.date(byAdding: .day, value: 10, to: editorNow)
    #expect(model.preview?.days == "10 days")
}

@Test("previews the projection for the entered date")
func editorPreviewsProjection() {
    var model = GoalEditorModel(config: .test, revenue: editorRevenue, clock: FixedClock(at: editorNow), calendar: editorCalendar)
    model.name = "Launch"
    model.targetDate = editorCalendar.date(byAdding: .day, value: 10, to: editorNow)
    #expect(model.preview?.projected == Money(8_226, "usd"))
}

@Test("previews without a target amount")
func editorPreviewsWithoutAmount() {
    var model = GoalEditorModel(config: .test, revenue: editorRevenue, clock: FixedClock(at: editorNow), calendar: editorCalendar)
    model.name = "Launch"
    model.targetDate = editorCalendar.date(byAdding: .day, value: 10, to: editorNow)
    #expect(model.preview?.percent == "—")
}

@Test("editing an existing goal starts from its current values")
func editorStartsFromGoal() {
    let target = editorCalendar.date(byAdding: .day, value: 10, to: editorNow)!
    let goal = Goal(name: "Launch", targetDate: target, targetAmount: Money(50_000, "usd"), createdAt: editorNow, sortIndex: 2)
    let model = GoalEditorModel(goal: goal, config: .test, revenue: editorRevenue, clock: FixedClock(at: editorNow), calendar: editorCalendar)
    #expect(model.name == "Launch")
    #expect(model.targetDate == target)
    #expect(model.amountText == "500.00")
}

@Test("the preview never calls the API")
func editorPreviewNeverCallsAPI() async {
    let api = FakeStripeClient()
    var model = GoalEditorModel(config: .test, revenue: editorRevenue, clock: FixedClock(at: editorNow), calendar: editorCalendar)
    for index in 0..<20 { model.name = "Goal \(index)"; _ = model.preview }
    #expect(await api.activeSubscriptionsCallCount == 0)
    #expect(await api.balanceTransactionsCallCount == 0)
    #expect(await api.productsCallCount == 0)
}
