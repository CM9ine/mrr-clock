import Foundation
import Testing
@testable import MRRClockCore

struct GoalTests {
    private let date = Date(iso: "2026-09-07T00:00:00Z")

    @Test("accepts a goal with a name and a date")
    func acceptsNameAndDate() {
        #expect(Goal.validate(name: "Buy a house", targetAmount: Money(1, "usd"), config: Config(currency: "usd")) == .valid)
    }

    @Test("accepts a goal with no target amount")
    func acceptsNoAmount() { #expect(Goal.validate(name: "Launch", targetAmount: nil, config: Config()) == .valid) }

    @Test("rejects an empty name", arguments: ["", "   "])
    func rejectsEmptyName(_ name: String) { #expect(Goal.validate(name: name, targetAmount: nil, config: Config()) == .emptyName) }

    @Test("trims whitespace from the name")
    func trimsName() {
        let goal = Goal(name: "  Buy a house  ", targetDate: date, createdAt: date, sortIndex: 0)
        #expect(goal.name == "Buy a house")
    }

    @Test("rejects a name over sixty characters")
    func rejectsLongName() {
        #expect(Goal.validate(name: String(repeating: "a", count: 61), targetAmount: nil, config: Config()) == .nameTooLong)
        #expect(Goal.validate(name: String(repeating: "a", count: 60), targetAmount: nil, config: Config()) == .valid)
    }

    @Test("rejects a zero or negative target amount", arguments: [0, -100])
    func rejectsNonPositiveAmount(_ amount: Int) {
        #expect(Goal.validate(name: "Launch", targetAmount: Money(amount, "usd"), config: Config()) == .nonPositiveAmount)
    }

    @Test("rejects a target amount in the wrong currency")
    func rejectsWrongCurrency() {
        #expect(Goal.validate(name: "Launch", targetAmount: Money(1, "gbp"), config: Config(currency: "usd")) == .currencyMismatch(expected: "usd", got: "gbp"))
    }

    @Test("accepts a target date in the past")
    func acceptsPastDate() {
        #expect(Goal.validate(name: "Missed", targetAmount: nil, config: Config()) == .valid)
    }

    @Test("round-trips through Codable")
    func codableRoundTrip() throws {
        let goals = [
            Goal(name: "With amount", targetDate: date, targetAmount: Money(10_000, "usd"), createdAt: date, sortIndex: 0),
            Goal(name: "Without amount", targetDate: date, createdAt: date, sortIndex: 1),
        ]
        let decoded = try JSONDecoder().decode([Goal].self, from: JSONEncoder().encode(goals))
        #expect(decoded == goals)
    }
}
