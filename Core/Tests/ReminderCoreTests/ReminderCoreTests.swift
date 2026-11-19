import XCTest
@testable import ReminderCore

/// One small test per rule.
final class ReminderCoreTests: XCTestCase {
    var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Stockholm")!
        return c
    }()

    func d(_ day: Int, _ hour: Int, _ minute: Int = 0, month: Int = 11) -> Date {
        cal.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
    }

    func testNudgesAreCountedFromTheDueTime() {
        let r = Reminder(title: "Vitamins", due: d(19, 8), nudgeMinutes: 5)
        XCTAssertEqual(r.nudgesSoFar(at: d(19, 7, 59)), 0)
        XCTAssertEqual(r.nudgesSoFar(at: d(19, 8)), 1)
        XCTAssertEqual(r.nudgesSoFar(at: d(19, 8, 12)), 3)
        XCTAssertEqual(r.nextNudge(after: d(19, 8, 12)), d(19, 8, 15))
    }

    func testTickingAOneOffMovesItToDone() {
        var list = ReminderList(reminders: [Reminder(title: "Call", due: d(19, 11), nudgeMinutes: 10)])
        let id = list.reminders[0].id
        let e = list.tick(id, at: d(19, 11, 25), calendar: cal)
        XCTAssertTrue(list.reminders.isEmpty)
        XCTAssertEqual(list.done.count, 1)
        XCTAssertEqual(e?.nudges, 3)
        XCTAssertEqual(e?.howText, "After 3 nudges")
    }

    func testTickingARepeatingOneMovesItOn() {
        var list = ReminderList(reminders: [Reminder(title: "Stretch", due: d(19, 21), repeats: .daily)])
        list.tick(list.reminders[0].id, at: d(19, 21, 3), calendar: cal)
        XCTAssertEqual(list.reminders[0].due, d(20, 21))
        // Ticked early (before its time) a weekly one still moves on a week.
        var w = ReminderList(reminders: [Reminder(title: "Plants", due: d(19, 18), repeats: .weekly)])
        w.tick(w.reminders[0].id, at: d(19, 9), calendar: cal)
        XCTAssertEqual(w.reminders[0].due, d(26, 18))
        XCTAssertEqual(w.done.first?.howText, "On time")
    }

    func testMonthlyKeepsItsDay() {
        let r = Reminder(title: "Rent", due: cal.date(from: DateComponents(year: 2027, month: 1, day: 31, hour: 9))!, repeats: .monthly)
        let feb = r.nextOccurrence(after: r.due, calendar: cal)!
        XCTAssertEqual(cal.component(.day, from: feb), 28)
        let afterFeb = r.nextOccurrence(after: feb, calendar: cal)!
        XCTAssertEqual(cal.component(.day, from: afterFeb), 31)
    }

    func testBringBackUndoesATick() {
        var list = ReminderList(reminders: [
            Reminder(title: "One-off", due: d(19, 8)),
            Reminder(title: "Daily", due: d(19, 9), repeats: .daily),
        ])
        let a = list.tick(list.reminders[0].id, at: d(19, 10), calendar: cal)!
        let b = list.tick(list.reminders[0].id, at: d(19, 10), calendar: cal)!
        list.bringBack(a.id)
        list.bringBack(b.id)
        XCTAssertTrue(list.done.isEmpty)
        XCTAssertEqual(list.reminders.map(\.due).sorted(), [d(19, 8), d(19, 9)])
    }

    func testSectionsAndTodayCounts() {
        var list = ReminderList(reminders: [
            Reminder(title: "Waiting", due: d(19, 8)),
            Reminder(title: "Today", due: d(19, 18)),
            Reminder(title: "Tomorrow", due: d(20, 9)),
            Reminder(title: "Later", due: d(25, 9)),
        ])
        list.done = [DoneEntry(reminder: Reminder(title: "x", due: d(19, 7)), doneAt: d(19, 7, 30), nudges: 1),
                     DoneEntry(reminder: Reminder(title: "y", due: d(18, 7)), doneAt: d(18, 7, 30), nudges: 1)]
        let s = list.sections(at: d(19, 9), calendar: cal)
        XCTAssertEqual([s.waiting, s.today, s.tomorrow, s.later].map { $0.map(\.title) },
                       [["Waiting"], ["Today"], ["Tomorrow"], ["Later"]])
        let c = list.todayCounts(at: d(19, 9), calendar: cal)
        XCTAssertEqual(c.done, 1)
        XCTAssertEqual(c.toGo, 2)
    }

    func testQuickTimesAndTheEveningRule() {
        XCTAssertEqual(QuickTime.evening.date(from: d(19, 9), calendar: cal), d(19, 19))
        XCTAssertEqual(QuickTime.evening.title(at: d(19, 9), calendar: cal), "This evening")
        XCTAssertEqual(QuickTime.evening.date(from: d(19, 20), calendar: cal), d(20, 19))
        XCTAssertEqual(QuickTime.evening.title(at: d(19, 20), calendar: cal), "Tomorrow evening")
        XCTAssertEqual(QuickTime.tomorrowMorning.date(from: d(19, 23), calendar: cal), d(20, 8))
        XCTAssertEqual(QuickTime.inTenMinutes.date(from: d(19, 9, 3), calendar: cal), d(19, 9, 13))
    }

    func testThePlanTakesTheEarliestNudgesAcrossAllReminders() {
        let a = Reminder(title: "A", due: d(19, 8), nudgeMinutes: 5)
        let b = Reminder(title: "B", due: d(19, 8, 7), nudgeMinutes: 10)
        let p = NudgePlan.plan([a, b], from: d(19, 8, 6), limit: 4)
        XCTAssertEqual(p.map(\.date), [d(19, 8, 7), d(19, 8, 10), d(19, 8, 15), d(19, 8, 17)])
        XCTAssertEqual(p.map(\.number), [1, 3, 4, 2])
        XCTAssertEqual(NudgePlan.plan([a, b], from: d(19, 9)).count, NudgePlan.limit)
    }

    func testWords() {
        XCTAssertEqual([1, 2, 3, 4, 11, 12, 21, 22, 113].map(Words.ordinal),
                       ["1st", "2nd", "3rd", "4th", "11th", "12th", "21st", "22nd", "113th"])
        let r = Reminder(title: "Vitamins", due: d(19, 8), nudgeMinutes: 5)
        XCTAssertEqual(Words.rowLine(r, at: d(19, 8, 12), calendar: cal), "Nudging every 5 min · 3rd nudge")
        let w = Reminder(title: "Plants", due: d(19, 18), repeats: .weekly)
        XCTAssertEqual(Words.rowLine(w, at: d(19, 9), calendar: cal), "Every Thursday")
    }

    func testAnOldOrDamagedFileStillReads() throws {
        let json = #"{"reminders":[{"title":"Only a title"}],"somethingNew":1}"#
        let list = try JSONDecoder().decode(ReminderList.self, from: Data(json.utf8))
        XCTAssertEqual(list.reminders.first?.title, "Only a title")
        XCTAssertEqual(list.reminders.first?.nudgeMinutes, 5)
        XCTAssertTrue(list.done.isEmpty)
    }

    func testOldDoneEntriesAreTidiedAway() {
        var list = ReminderList()
        list.done = [DoneEntry(reminder: Reminder(title: "old", due: d(1, 8, month: 10)), doneAt: d(1, 8, month: 10), nudges: 1),
                     DoneEntry(reminder: Reminder(title: "new", due: d(18, 8)), doneAt: d(18, 8), nudges: 1)]
        list.forgetDone(olderThan: 30, at: d(19, 9), calendar: cal)
        XCTAssertEqual(list.done.map(\.reminder.title), ["new"])
    }
}
