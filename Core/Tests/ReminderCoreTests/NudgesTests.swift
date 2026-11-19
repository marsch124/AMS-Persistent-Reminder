import XCTest
@testable import ReminderCore

/// 0.5 lane "nudges": one small test per rule.
final class NudgesTests: XCTestCase {
    var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Stockholm")!
        return c
    }()

    // 19 Nov 2026 is a Thursday; 21 = Saturday, 22 = Sunday, 23 = Monday.
    func d(_ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        cal.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute))!
    }

    func plan(_ r: [Reminder], _ now: Date, up: Date? = nil, from: Date? = nil, quiet: QuietHours? = nil, limit: Int = 60) -> [PlannedNudge] {
        NudgePlan.plan(r, from: now, allPausedUntil: up, allPausedFrom: from, quiet: quiet, limit: limit, calendar: cal)
    }

    func testLouderNudgesComeTwiceAsOftenFromTheFourth() {
        let r = Reminder(title: "Pills", due: d(19, 9), nudgeMinutes: 10)
        let p = plan([r], d(19, 8, 59), limit: 7)
        XCTAssertEqual(p.map(\.date), [d(19, 9), d(19, 9, 10), d(19, 9, 20), d(19, 9, 30), d(19, 9, 35), d(19, 9, 40), d(19, 9, 45)])
        XCTAssertEqual(p.map(\.louder), [false, false, false, true, true, true, true])
        XCTAssertEqual(r.nudgesSoFar(at: d(19, 9, 36)), 5)
        XCTAssertEqual(r.nextNudge(after: d(19, 9, 36)), d(19, 9, 40))
    }

    func testLouderNeverGoesUnderOneMinuteAndCanBeSwitchedOff() {
        XCTAssertEqual(Reminder(title: "a", due: d(19, 9), nudgeMinutes: 1).louderInterval, 60)
        let quiet = Reminder(title: "b", due: d(19, 9), nudgeMinutes: 10, louder: false)
        XCTAssertEqual(plan([quiet], d(19, 8), limit: 6).map(\.date).last, d(19, 9, 50))
        XCTAssertFalse(plan([quiet], d(19, 8), limit: 6).contains { $0.louder })
    }

    func testLouderWords() {
        let r = Reminder(title: "Pills", due: d(19, 9), nudgeMinutes: 5)
        XCTAssertEqual(Words.nudgeBody(r, number: 4, calendar: cal), "Since 09:00 · 4th nudge. I'll keep at it every 2½ min.")
        let r10 = Reminder(title: "Pills", due: d(19, 9), nudgeMinutes: 10)
        XCTAssertEqual(Words.nudgeBody(r10, number: 4, calendar: cal), "Since 09:00 · 4th nudge. I'll keep at it every 5 min.")
        XCTAssertEqual(Words.nudgeBody(r10, number: 3, calendar: cal), "Since 09:00 · 3rd nudge. Next one in 10 min.")
    }

    func testTheNoteClosesTheNudge() {
        let r = Reminder(title: "Pills", due: d(19, 9), note: "With water")
        XCTAssertTrue(Words.nudgeBody(r, number: 1, calendar: cal).hasSuffix("\nWith water"))
    }

    func testQuietHoursDropNudgesAndOneComesWhenTheyEnd() {
        let r = Reminder(title: "Call", due: d(19, 21, 30), nudgeMinutes: 40, louder: false)
        let p = plan([r], d(19, 21), quiet: QuietHours(), limit: 4)
        XCTAssertEqual(p.map(\.date), [d(19, 21, 30), d(20, 7), d(20, 7, 30), d(20, 8, 10)])
        XCTAssertEqual(p[1].number, 15)   // the one at 07:00 says how many it has missed
    }

    func testQuietHoursThatDoNotCrossMidnight() {
        let q = QuietHours(from: 13 * 60, to: 15 * 60)
        XCTAssertEqual(q.endIfInside(d(19, 14), calendar: cal), d(19, 15))
        XCTAssertNil(q.endIfInside(d(19, 15), calendar: cal))
        XCTAssertEqual(QuietHours().endIfInside(d(19, 23), calendar: cal), d(20, 7))
        XCTAssertEqual(QuietHours().endIfInside(d(19, 3), calendar: cal), d(19, 7))
    }

    func testStopNudgingAtATime() {
        let r = Reminder(title: "Plants", due: d(19, 17, 30), nudgeMinutes: 15, louder: false, stopAt: 18 * 60)
        XCTAssertEqual(plan([r], d(19, 17)).map(\.date), [d(19, 17, 30), d(19, 17, 45), d(19, 18)])
        XCTAssertEqual(Words.rowLine(r, at: d(19, 18, 10), calendar: cal), "Stopped nudging at 18:00")
        XCTAssertEqual(Words.rowLine(r, at: d(19, 17, 40), calendar: cal), "Nudging every 15 min · 1st nudge")
        // A repeating one is for its next time after a tick, so it nudges again then.
        var list = ReminderList(reminders: [Reminder(title: "Plants", due: d(19, 17, 30), repeats: .daily, louder: false, stopAt: 18 * 60)])
        list.tick(list.reminders[0].id, at: d(19, 18, 30), calendar: cal)
        XCTAssertEqual(plan(list.reminders, d(19, 19)).first?.date, d(20, 17, 30))
    }

    func testTheLaterButtonsAreAlwaysThree() {
        XCTAssertEqual(LaterChoice.parse(nil), LaterChoice.defaults)
        XCTAssertEqual(LaterChoice.parse("fiveMinutes,bogus"), [.fiveMinutes, .tenMinutes, .oneHour])
        let swapped = LaterChoice.picking(.twoHours, in: LaterChoice.defaults)
        XCTAssertEqual(swapped, [.oneHour, .evening, .twoHours])
        XCTAssertEqual(LaterChoice.picking(.oneHour, in: swapped), swapped)
        XCTAssertEqual(LaterChoice.fifteenMinutes.date(from: d(19, 9, 2), calendar: cal), d(19, 9, 17))
        XCTAssertEqual(LaterChoice.twoHours.date(from: d(19, 9, 2), calendar: cal), d(19, 11, 2))
    }

    func testTheWeekendRuns() {
        let thursday = Pause.weekend(after: d(19, 9), calendar: cal)
        XCTAssertEqual(thursday.from, d(21, 0))
        XCTAssertEqual(thursday.until, d(23, 8))
        let sunday = Pause.weekend(after: d(22, 15), calendar: cal)
        XCTAssertEqual(sunday.from, d(22, 15))
        XCTAssertEqual(sunday.until, d(23, 8))
        XCTAssertEqual(Pause.weekend(after: d(23, 9), calendar: cal).until, d(30, 8))
        XCTAssertEqual(Pause.text(thursday.until, at: d(19, 9), from: thursday.from, calendar: cal), "for the weekend")
    }

    func testAWeekendPauseOnOneReminder() {
        let w = Pause.weekend(after: d(19, 9), calendar: cal)
        var r = Reminder(title: "Bins", due: d(19, 9), nudgeMinutes: 60, pausedUntil: w.until, louder: false)
        r.pausedFrom = w.from
        XCTAssertFalse(r.isPaused(at: d(19, 10)))
        XCTAssertTrue(r.isPaused(at: d(21, 1)))
        XCTAssertEqual(Words.rowLine(r, at: d(19, 10), calendar: cal), "Paused for the weekend")
        let p = plan([r], d(19, 10), limit: 40)
        XCTAssertTrue(p.contains { $0.date == d(20, 23) })
        XCTAssertFalse(p.contains { $0.date >= d(21) && $0.date < d(23, 8) })
        XCTAssertEqual(p.first { $0.date >= d(21) }?.date, d(23, 8))   // one nudge when it ends
    }

    func testAWeekendPauseOnAllNudges() {
        let r = Reminder(title: "Bins", due: d(19, 9), nudgeMinutes: 60, louder: false)
        let w = Pause.weekend(after: d(20, 9), calendar: cal)
        let p = plan([r], d(20, 9), up: w.until, from: w.from, limit: 30)
        XCTAssertTrue(p.contains { $0.date == d(20, 23) })
        XCTAssertEqual(p.first { $0.date >= d(21) }?.date, d(23, 8))
    }
}
