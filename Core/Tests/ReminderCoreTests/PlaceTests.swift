import XCTest
@testable import ReminderCore

/// 0.5 pick 11: reminders that start nudging at a place.
final class PlaceTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    func make(_ repeats: Repeat = .never, arrive: Bool = true) -> Reminder {
        Reminder(title: "Bins", due: Place.notYet, repeats: repeats,
                 place: Place(name: "Home", latitude: 58.59, longitude: 16.18, radius: 200, onArrive: arrive))
    }

    func testReachingThePlaceStartsNudging() {
        var l = ReminderList(reminders: [make()])
        let id = l.reminders[0].id
        l.reachedPlace(id, at: now)
        XCTAssertEqual(l.reminders[0].due, now)
        // Already reached: a second event changes nothing.
        l.reachedPlace(id, at: now.addingTimeInterval(500))
        XCTAssertEqual(l.reminders[0].due, now)
    }

    func testTickingOneOffLeavesAndRepeatingWaitsAgain() {
        var l = ReminderList(reminders: [make(), make(.daily)])
        let (a, b) = (l.reminders[0].id, l.reminders[1].id)
        l.reachedPlace(a, at: now); l.reachedPlace(b, at: now)
        l.tick(a, at: now); l.tick(b, at: now)
        XCTAssertNil(l.reminder(a))
        XCTAssertEqual(l.reminder(b)?.due, Place.notYet)
        XCTAssertEqual(l.done.count, 2)
    }

    func testWaitingForPlaceHasItsOwnGroupAndNoNudges() {
        let l = ReminderList(reminders: [make()])
        let s = l.sections(at: now)
        XCTAssertEqual(s.atPlace.count, 1)
        XCTAssertTrue(s.later.isEmpty)
        XCTAssertFalse(s.isEmpty)
        XCTAssertTrue(NudgePlan.plan(l.reminders, from: now).isEmpty)
    }

    func testRowLineSaysWhenYouArriveOrLeave() {
        XCTAssertEqual(Words.rowLine(make(), at: now), "When you arrive at Home")
        XCTAssertEqual(Words.rowLine(make(arrive: false), at: now), "When you leave Home")
    }

    func testSkippingAPlaceReminderWaitsForThePlaceAgain() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        var r = Reminder(title: "Water plants", due: now.addingTimeInterval(-60), repeats: .daily)
        r.place = Place(name: "Home", latitude: 59.6, longitude: 16.2)
        var list = ReminderList(reminders: [r])
        XCTAssertNotNil(list.skip(r.id, at: now))
        XCTAssertEqual(list.reminders.first?.due, Place.notYet)
    }
}
