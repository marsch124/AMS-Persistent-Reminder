import Foundation

// The rules of AMS Persistent Reminder, with no screen in them. `swift test --package-path Core`
// runs their tests in seconds.

/// How often a reminder comes back after it has been ticked off.
public enum Repeat: String, Codable, CaseIterable, Sendable {
    case never, daily, weekly, monthly

    public var title: String {
        switch self {
        case .never: return "Never"
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        }
    }
}

/// One reminder. `due` is the next time it is for; once that time has passed it nudges every
/// `nudgeMinutes` until it is ticked off.
public struct Reminder: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var due: Date
    public var repeats: Repeat
    public var nudgeMinutes: Int
    public var created: Date
    /// The name of an Apple Shortcut to run from this reminder (press and hold its nudge or its row), or nil.
    public var shortcut: String?

    public init(id: UUID = UUID(), title: String, due: Date, repeats: Repeat = .never, nudgeMinutes: Int = 5, created: Date = Date(), shortcut: String? = nil) {
        self.shortcut = Reminder.cleanShortcut(shortcut)
        self.id = id
        self.title = title
        self.due = due
        self.repeats = repeats
        self.nudgeMinutes = nudgeMinutes
        self.created = created
    }

    // Tolerant reading: a field a later version adds never makes an older file unreadable, and a
    // missing field gets a sensible value instead of losing the reminder.
    enum CodingKeys: String, CodingKey { case id, title, due, repeats, nudgeMinutes, created, shortcut }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
        title = (try? c.decode(String.self, forKey: .title)) ?? ""
        due = (try? c.decode(Date.self, forKey: .due)) ?? Date()
        repeats = (try? c.decode(Repeat.self, forKey: .repeats)) ?? .never
        nudgeMinutes = (try? c.decode(Int.self, forKey: .nudgeMinutes)) ?? 5
        created = (try? c.decode(Date.self, forKey: .created)) ?? Date()
        shortcut = Reminder.cleanShortcut(try? c.decode(String.self, forKey: .shortcut))
    }

    /// A shortcut name without spaces around it; an empty one means none.
    public static func cleanShortcut(_ name: String?) -> String? {
        let t = (name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    /// The link that makes the Shortcuts app run this reminder's shortcut, or nil when it has none.
    public var shortcutURL: URL? { shortcut.flatMap(Reminder.shortcutURL(for:)) }

    public static func shortcutURL(for name: String) -> URL? {
        guard let clean = cleanShortcut(name) else { return nil }
        var parts = URLComponents()
        parts.scheme = "shortcuts"
        parts.host = "run-shortcut"
        parts.queryItems = [URLQueryItem(name: "name", value: clean)]
        // URLComponents leaves "&" and "+" as they are inside a value; the Shortcuts app needs them encoded.
        parts.percentEncodedQuery = parts.percentEncodedQuery?
            .replacingOccurrences(of: "+", with: "%2B")
            .replacingOccurrences(of: "&", with: "%26")
        return parts.url
    }

    /// Minutes between two nudges, never less than one.
    public var interval: TimeInterval { TimeInterval(max(1, nudgeMinutes) * 60) }

    /// Has its time come?
    public func isWaiting(at now: Date) -> Bool { due <= now }

    /// How many nudges it has given so far (the first one comes at the due time).
    public func nudgesSoFar(at now: Date) -> Int {
        guard due <= now else { return 0 }
        return Int(now.timeIntervalSince(due) / interval) + 1
    }

    /// When the next nudge comes.
    public func nextNudge(after now: Date) -> Date {
        guard due <= now else { return due }
        return due.addingTimeInterval(Double(nudgesSoFar(at: now)) * interval)
    }

    /// The next time a repeating reminder is for, strictly after `now`, counted from its own due
    /// time (so a monthly one on the 31st stays on the last day of short months and comes back to the 31st).
    public func nextOccurrence(after now: Date, calendar: Calendar = .current) -> Date? {
        let unit: Calendar.Component
        switch repeats {
        case .never: return nil
        case .daily: unit = .day
        case .weekly: unit = .weekOfYear
        case .monthly: unit = .month
        }
        var n = 1
        while n < 100_000 {
            if let d = calendar.date(byAdding: unit, value: n, to: due), d > now { return d }
            n += 1
        }
        return nil
    }
}

/// A reminder that was ticked off, kept for the Done page. `reminder` is the reminder as it was
/// when ticked, so "Bring back" can put it back exactly.
public struct DoneEntry: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var reminder: Reminder
    public var doneAt: Date
    public var nudges: Int

    public init(id: UUID = UUID(), reminder: Reminder, doneAt: Date, nudges: Int) {
        self.id = id
        self.reminder = reminder
        self.doneAt = doneAt
        self.nudges = nudges
    }

    /// "On time" or "After 3 nudges" — said kindly.
    public var howText: String {
        switch nudges {
        case ...1: return "On time"
        default: return "After \(nudges) nudges"
        }
    }
}

/// Everything the app keeps: the reminders still to do and the ones ticked off.
public struct ReminderList: Codable, Equatable, Sendable {
    /// Raised when the file changes in a way an older version could not read.
    public static let currentFormat = 1

    public var format: Int
    public var reminders: [Reminder]
    public var done: [DoneEntry]

    public init(reminders: [Reminder] = [], done: [DoneEntry] = []) {
        self.format = ReminderList.currentFormat
        self.reminders = reminders
        self.done = done
    }

    enum CodingKeys: String, CodingKey { case format, reminders, done }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        format = (try? c.decode(Int.self, forKey: .format)) ?? 1
        reminders = (try? c.decode([Reminder].self, forKey: .reminders)) ?? []
        done = (try? c.decode([DoneEntry].self, forKey: .done)) ?? []
    }

    // MARK: Changes

    public mutating func add(_ r: Reminder) { reminders.append(r) }

    public mutating func update(_ r: Reminder) {
        if let i = reminders.firstIndex(where: { $0.id == r.id }) { reminders[i] = r }
    }

    public mutating func delete(_ id: UUID) { reminders.removeAll { $0.id == id } }

    /// Ticks a reminder off: it goes onto the Done list; a repeating one moves on to its next time,
    /// any other one leaves the list. Returns the Done entry.
    @discardableResult
    public mutating func tick(_ id: UUID, at now: Date, calendar: Calendar = .current) -> DoneEntry? {
        guard let i = reminders.firstIndex(where: { $0.id == id }) else { return nil }
        let r = reminders[i]
        let entry = DoneEntry(reminder: r, doneAt: now, nudges: r.nudgesSoFar(at: now))
        done.insert(entry, at: 0)
        if let next = r.nextOccurrence(after: now, calendar: calendar) {
            reminders[i].due = next
        } else {
            reminders.remove(at: i)
        }
        return entry
    }

    /// Undoes a tick: the reminder comes back with the time it had, and the Done entry goes.
    public mutating func bringBack(_ entryID: UUID) {
        guard let e = done.first(where: { $0.id == entryID }) else { return }
        if let i = reminders.firstIndex(where: { $0.id == e.reminder.id }) {
            reminders[i].due = e.reminder.due
        } else {
            reminders.append(e.reminder)
        }
        done.removeAll { $0.id == entryID }
    }

    /// Moves a reminder to a later time ("In 10 minutes" on a nudge). Its nudges start again from there.
    public mutating func snooze(_ id: UUID, to date: Date) {
        if let i = reminders.firstIndex(where: { $0.id == id }) { reminders[i].due = date }
    }

    // MARK: What the screens show

    public func reminder(_ id: UUID) -> Reminder? { reminders.first { $0.id == id } }

    /// The main screen's groups, each sorted by time: waiting (time has come), today, tomorrow, later.
    public func sections(at now: Date, calendar: Calendar = .current) -> Sections {
        var s = Sections()
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        for r in reminders.sorted(by: { $0.due < $1.due }) {
            if r.due <= now { s.waiting.append(r) }
            else if calendar.isDate(r.due, inSameDayAs: now) { s.today.append(r) }
            else if calendar.isDate(r.due, inSameDayAs: tomorrow) { s.tomorrow.append(r) }
            else { s.later.append(r) }
        }
        return s
    }

    /// Ticked off today, newest first.
    public func doneToday(at now: Date, calendar: Calendar = .current) -> [DoneEntry] {
        done.filter { calendar.isDate($0.doneAt, inSameDayAs: now) }.sorted { $0.doneAt > $1.doneAt }
    }

    /// The Done list by day, newest day first; today is the first group when there is anything today.
    public func doneByDay(calendar: Calendar = .current) -> [(day: Date, entries: [DoneEntry])] {
        let groups = Dictionary(grouping: done) { calendar.startOfDay(for: $0.doneAt) }
        return groups.keys.sorted(by: >).map { day in
            (day, groups[day]!.sorted { $0.doneAt > $1.doneAt })
        }
    }

    /// "2 done · 4 to go today": done today, and still to do today (waiting + rest of today).
    public func todayCounts(at now: Date, calendar: Calendar = .current) -> (done: Int, toGo: Int) {
        let s = sections(at: now, calendar: calendar)
        return (doneToday(at: now, calendar: calendar).count, s.waiting.count + s.today.count)
    }

    /// Drops Done entries older than `days` days, so the file stays small.
    public mutating func forgetDone(olderThan days: Int, at now: Date, calendar: Calendar = .current) {
        guard let limit = calendar.date(byAdding: .day, value: -days, to: calendar.startOfDay(for: now)) else { return }
        done.removeAll { $0.doneAt < limit }
    }
}

public struct Sections: Equatable, Sendable {
    public var waiting: [Reminder] = []
    public var today: [Reminder] = []
    public var tomorrow: [Reminder] = []
    public var later: [Reminder] = []
    public init() {}
    public var isEmpty: Bool { waiting.isEmpty && today.isEmpty && tomorrow.isEmpty && later.isEmpty }
}
