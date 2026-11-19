import XCTest
@testable import ReminderCore

/// 0.5 lane "repeats": one small test per rule.
final class RepeatsTests: XCTestCase {
    var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Stockholm")!
        return c
    }()

    func d(_ day: Int, _ hour: Int, _ minute: Int = 0, month: Int = 11, year: Int = 2026) -> Date {
        cal.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    // 19 Nov 2026 is a Thursday.
    func testChosenDaysMoveToTheNextChosenDay() {
        let r = Reminder(title: "Gym", due: d(19, 7), repeats: .weekdays, weekdays: [2, 4, 6]) // Mon Wed Fri
        XCTAssertEqual(r.nextOccurrence(after: d(19, 7), calendar: cal), d(20, 7))   // Thu -> Fri
        let fri = Reminder(title: "Gym", due: d(20, 7), repeats: .weekdays, weekdays: [2, 4, 6])
        XCTAssertEqual(fri.nextOccurrence(after: d(20, 7, 5), calendar: cal), d(23, 7)) // Fri -> Mon, crossing the week
    }

    func testOnlyOneChosenDayComesBackNextWeek() {
        let r = Reminder(title: "Bins", due: d(19, 18), repeats: .weekdays, weekdays: [5]) // Thursday only
        XCTAssertEqual(r.nextOccurrence(after: d(19, 18, 1), calendar: cal), d(26, 18))
    }

    func testChosenDaysCatchUpWhenLongOverdue() {
        let r = Reminder(title: "Gym", due: d(2, 7), repeats: .weekdays, weekdays: [2]) // Monday 2 Nov
        XCTAssertEqual(r.nextOccurrence(after: d(19, 12), calendar: cal), d(23, 7))
    }

    func testEveryFewHoursIsTheFirstOneAfterNow() {
        let r = Reminder(title: "Drink", due: d(19, 8), repeats: .hours, every: 3)
        XCTAssertEqual(r.nextOccurrence(after: d(19, 8, 20), calendar: cal), d(19, 11))
        XCTAssertEqual(r.nextOccurrence(after: d(19, 14), calendar: cal), d(19, 17)) // missed 11 and 14: next after now
    }

    func testEveryFewDaysAcrossMonthEnd() {
        let r = Reminder(title: "Filter", due: d(29, 9), repeats: .days, every: 3)
        XCTAssertEqual(r.nextOccurrence(after: d(29, 9), calendar: cal), d(2, 9, month: 12))
    }

    func testAfterDoneCountsFromTheTick() {
        let tick = d(21, 15, 30)
        let daily = Reminder(title: "A", due: d(19, 8), repeats: .daily, afterDone: true)
        XCTAssertEqual(daily.nextOccurrence(after: tick, calendar: cal), d(22, 15, 30))
        let weekly = Reminder(title: "B", due: d(19, 8), repeats: .weekly, afterDone: true)
        XCTAssertEqual(weekly.nextOccurrence(after: tick, calendar: cal), d(28, 15, 30))
        let hours = Reminder(title: "C", due: d(19, 8), repeats: .hours, every: 4, afterDone: true)
        XCTAssertEqual(hours.nextOccurrence(after: tick, calendar: cal), d(21, 19, 30))
        let days = Reminder(title: "Plants", due: d(19, 8), repeats: .days, every: 3, afterDone: true)
        XCTAssertEqual(days.nextOccurrence(after: tick, calendar: cal), d(24, 15, 30))
    }

    func testAfterDoneMonthlyKeepsMonthEndSafe() {
        let r = Reminder(title: "Rent", due: d(1, 9, month: 1, year: 2027), repeats: .monthly, afterDone: true)
        let next = r.nextOccurrence(after: d(31, 9, month: 1, year: 2027), calendar: cal)!
        XCTAssertEqual(next, d(28, 9, month: 2, year: 2027))
    }

    func testAfterDoneChosenDaysUseTheReminderOwnTime() {
        let r = Reminder(title: "Gym", due: d(18, 7), repeats: .weekdays, weekdays: [2, 4], afterDone: true) // Mon Wed
        // Ticked Thursday evening: next chosen day is Monday 23rd at 07:00.
        XCTAssertEqual(r.nextOccurrence(after: d(19, 20), calendar: cal), d(23, 7))
        // Ticked Monday morning: not the same day, the next chosen one is Wednesday.
        XCTAssertEqual(r.nextOccurrence(after: d(23, 6), calendar: cal), d(25, 7))
    }

    func testTickUsesAfterDone() {
        var list = ReminderList(reminders: [Reminder(title: "Plants", due: d(19, 8), repeats: .days, every: 3, afterDone: true)])
        list.tick(list.reminders[0].id, at: d(20, 12), calendar: cal)
        XCTAssertEqual(list.reminders[0].due, d(23, 12))
    }

    func testRepeatWords() {
        func text(_ r: Reminder) -> String? { Words.repeatText(r, calendar: cal) }
        let due = d(19, 8)
        XCTAssertEqual(text(Reminder(title: "", due: due, repeats: .weekdays, weekdays: [6, 2, 4])), "Every Mon, Wed, Fri")
        XCTAssertEqual(text(Reminder(title: "", due: due, repeats: .weekdays, weekdays: [2, 3, 4, 5, 6])), "Every weekday")
        XCTAssertEqual(text(Reminder(title: "", due: due, repeats: .weekdays, weekdays: [7, 1])), "Every weekend")
        XCTAssertEqual(text(Reminder(title: "", due: due, repeats: .weekdays, weekdays: [1, 2, 3, 4, 5, 6, 7])), "Every day")
        XCTAssertEqual(text(Reminder(title: "", due: due, repeats: .hours, every: 2)), "Every 2 hours")
        XCTAssertEqual(text(Reminder(title: "", due: due, repeats: .hours, every: 1)), "Every hour")
        XCTAssertEqual(text(Reminder(title: "", due: due, repeats: .days, every: 3)), "Every 3 days")
        XCTAssertEqual(text(Reminder(title: "", due: due, repeats: .days, every: 3, afterDone: true)), "3 days after done")
        XCTAssertEqual(text(Reminder(title: "", due: due, repeats: .weekly, afterDone: true)), "1 week after done")
        XCTAssertEqual(text(Reminder(title: "", due: due, repeats: .daily, afterDone: true)), "1 day after done")
        XCTAssertEqual(text(Reminder(title: "", due: due, repeats: .hours, every: 2, afterDone: true)), "2 hours after done")
        XCTAssertEqual(text(Reminder(title: "", due: due, repeats: .weekdays, weekdays: [2, 4], afterDone: true)), "Mon, Wed after done")
    }

    func testSkipMovesARepeatingOneOnAndIsNotDone() {
        var list = ReminderList(reminders: [Reminder(title: "Stretch", due: d(19, 21), repeats: .daily)])
        let e = list.skip(list.reminders[0].id, at: d(19, 21, 10), calendar: cal)
        XCTAssertEqual(list.reminders[0].due, d(20, 21))
        XCTAssertEqual(e?.skipped, true)
        XCTAssertEqual(e?.nudges, 0)
        XCTAssertEqual(e?.howText, "Skipped")
        XCTAssertEqual(list.done.count, 1)
    }

    func testSkipCountsFromNowWhenAfterDone() {
        var list = ReminderList(reminders: [Reminder(title: "Plants", due: d(19, 8), repeats: .days, every: 3, afterDone: true)])
        list.skip(list.reminders[0].id, at: d(19, 10), calendar: cal)
        XCTAssertEqual(list.reminders[0].due, d(22, 10))
    }

    func testSkipOfAOneOffDoesNothing() {
        var list = ReminderList(reminders: [Reminder(title: "Call", due: d(19, 11))])
        XCTAssertNil(list.skip(list.reminders[0].id, at: d(19, 12), calendar: cal))
        XCTAssertEqual(list.reminders.count, 1)
        XCTAssertTrue(list.done.isEmpty)
    }

    func testSkippedTimeIsNotCountedAsDone() {
        var list = ReminderList(reminders: [
            Reminder(title: "A", due: d(19, 8), repeats: .daily),
            Reminder(title: "B", due: d(19, 9), repeats: .daily),
        ])
        list.tick(list.reminders[0].id, at: d(19, 10), calendar: cal)
        list.skip(list.reminders[1].id, at: d(19, 10), calendar: cal)
        XCTAssertEqual(list.todayCounts(at: d(19, 10), calendar: cal).done, 1)
        XCTAssertEqual(list.done.count, 2)
    }

    func testOlderFilesStillRead() {
        let json = #"{"format":1,"reminders":[{"title":"Old","repeats":"daily"}],"done":[]}"#
        let list = try? JSONDecoder().decode(ReminderList.self, from: Data(json.utf8))
        XCTAssertEqual(list?.reminders.first?.every, 2)
        XCTAssertEqual(list?.reminders.first?.afterDone, false)
    }
}
