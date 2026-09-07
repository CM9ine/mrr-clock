import Foundation
import Testing
@testable import MRRClockCore

struct CountdownTests {
    private func calendar(_ zone: String = "UTC") -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: zone)!
        return calendar
    }

    @Test("counts the days between two dates")
    func countsDays() {
        #expect(Countdown.daysRemaining(
            now: Date(iso: "2026-09-07T09:00:00Z"),
            target: Date(iso: "2027-09-29T00:00:00Z"), calendar: calendar()) == 387)
    }

    @Test("the same calendar day is zero days")
    func sameDay() {
        let target = Date(iso: "2027-09-29T23:59:00Z")
        let result = Countdown.daysRemaining(now: Date(iso: "2027-09-29T00:01:00Z"), target: target, calendar: calendar("UTC"))
        #expect(result == 0)
    }

    @Test("time of day does not matter")
    func timeOfDay() {
        let target = Date(iso: "2026-09-10T00:00:00Z")
        let result = Countdown.daysRemaining(now: Date(iso: "2026-09-07T23:59:00Z"), target: target, calendar: calendar("UTC"))
        #expect(result == 3)
        #expect(Countdown.daysRemaining(now: Date(iso: "2026-09-07T00:01:00Z"), target: target, calendar: calendar("UTC")) == result)
    }

    @Test("a past target is negative")
    func pastTarget() {
        let target = Date(iso: "2027-09-29T00:00:00Z")
        let result = Countdown.daysRemaining(now: Date(iso: "2027-10-01T00:00:00Z"), target: target, calendar: calendar("UTC"))
        #expect(result == -2)
    }

    @Test("tomorrow is one day")
    func tomorrow() {
        let target = Date(iso: "2026-09-08T12:00:00Z")
        let result = Countdown.daysRemaining(now: Date(iso: "2026-09-07T12:00:00Z"), target: target, calendar: calendar("UTC"))
        #expect(result == 1)
    }

    @Test("spring forward is still one calendar day")
    func springForward() {
        #expect(Countdown.daysRemaining(
            now: Date(iso: "2027-03-13T12:00:00-05:00"),
            target: Date(iso: "2027-03-14T12:00:00-04:00"), calendar: calendar("America/New_York")) == 1)
    }

    @Test("autumn back is still one calendar day")
    func autumnBack() {
        #expect(Countdown.daysRemaining(
            now: Date(iso: "2027-11-06T12:00:00-04:00"),
            target: Date(iso: "2027-11-07T12:00:00-05:00"), calendar: calendar("America/New_York")) == 1)
    }

    @Test("counts in the supplied time zone, not UTC")
    func suppliedTimeZone() {
        #expect(Countdown.daysRemaining(
            now: Date(iso: "2026-09-07T23:00:00-07:00"),
            target: Date(iso: "2026-09-10T00:00:00-07:00"), calendar: calendar("America/Los_Angeles")) == 3)
    }

    @Test("crosses a leap day correctly")
    func leapDay() {
        #expect(Countdown.daysRemaining(
            now: Date(iso: "2028-02-28T00:00:00Z"),
            target: Date(iso: "2028-03-01T00:00:00Z"), calendar: calendar("UTC")) == 2)
    }

    @Test("FixedClock returns the instant it was given")
    func fixedClock() {
        let instant = Date(iso: "2026-09-07T09:00:00Z")
        let clock: any MRRClockCore.Clock = FixedClock(at: instant)
        #expect(clock.now == instant)
    }
}
