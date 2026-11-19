import XCTest
@testable import ReminderCore

final class VoiceTests: XCTestCase {
    var cal: Calendar = { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!; return c }()
    // Thursday 19 Nov 2026, 10:00
    var now: Date { cal.date(from: DateComponents(year: 2026, month: 11, day: 19, hour: 10, minute: 0))! }
    func d(_ day: Int, _ h: Int, _ m: Int = 0) -> Date { cal.date(from: DateComponents(year: 2026, month: 11, day: day, hour: h, minute: m))! }
    func p(_ s: String) -> (title: String, due: Date?) { Spoken.parse(s, now: now, calendar: cal) }

    func testAtTimes() {
        XCTAssertEqual(p("Remind me to call Anna at 3").due, d(19, 15))
        XCTAssertEqual(p("Remind me to call Anna at 3").title, "Call Anna")
        XCTAssertEqual(p("water plants at 3 pm").due, d(19, 15))
        XCTAssertEqual(p("water plants at 15:30").due, d(19, 15, 30))
        XCTAssertEqual(p("water plants at half past 4").due, d(19, 16, 30))
        XCTAssertEqual(p("pills at 8").due, d(20, 8)) // 08:00 already passed today
    }
    func testIn() {
        XCTAssertEqual(p("stretch in 20 minutes").due, now.addingTimeInterval(1200))
        XCTAssertEqual(p("stretch in 2 hours").due, now.addingTimeInterval(7200))
        XCTAssertEqual(p("stretch in an hour").due, now.addingTimeInterval(3600))
        XCTAssertEqual(p("stretch in an hour").title, "Stretch")
    }
    func testDays() {
        XCTAssertEqual(p("buy milk tomorrow").due, d(20, 8))
        XCTAssertEqual(p("buy milk tomorrow morning").due, d(20, 8))
        XCTAssertEqual(p("buy milk tonight").due, d(19, 19))
        XCTAssertEqual(p("buy milk this evening").due, d(19, 19))
        XCTAssertEqual(p("buy milk tomorrow at 3").due, d(20, 15))
        XCTAssertEqual(p("call Mum on Monday").due, d(23, 8))
        XCTAssertEqual(p("call Mum on Monday").title, "Call Mum")
    }
    func testNothingFound() {
        let r = p("just a thought")
        XCTAssertNil(r.due)
        XCTAssertEqual(r.title, "Just a thought")
    }
}
