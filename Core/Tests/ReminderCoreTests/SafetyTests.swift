import XCTest
@testable import ReminderCore

final class SafetyTests: XCTestCase {
    private func list(done: Int) -> ReminderList {
        var l = ReminderList(reminders: [Reminder(title: "Keep", due: Date(timeIntervalSince1970: 1_800_000_000))])
        l.done = (0..<done).map { i in
            DoneEntry(reminder: Reminder(title: "Old \(i)", due: Date(timeIntervalSince1970: 1_700_000_000)),
                      doneAt: Date(timeIntervalSince1970: 1_700_000_000 + Double(i)), nudges: 1)
        }
        return l
    }

    func testCloudCopyDropsTheOldestDoneFirstAndKeepsReminders() throws {
        let l = list(done: 400)
        let data = try XCTUnwrap(l.trimmedForCloud(maxBytes: 20_000))
        XCTAssertLessThanOrEqual(data.count, 20_000)
        let back = try XCTUnwrap(ReminderList.readCopy(data))
        XCTAssertEqual(back.reminders.count, 1)
        XCTAssertLessThan(back.done.count, 400)
        XCTAssertEqual(back.done.first?.reminder.title, "Old 0")   // newest kept
        XCTAssertEqual(l.done.count, 400)                          // the list itself is untouched
    }

    func testCopyCountsAndEmptyCopyIsRefused() {
        XCTAssertEqual(list(done: 30).countsText, "1 reminder, 30 done")
        XCTAssertNil(ReminderList.readCopy(Data("{}".utf8)))
        XCTAssertNil(ReminderList.readCopy(Data("not json".utf8)))
    }
}
