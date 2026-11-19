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

/// The colours a repeating reminder can wear (0.3).
public enum RowColour: String, Codable, CaseIterable, Sendable {
    case red, orange, yellow, green, teal, blue, purple, pink

    public var title: String { rawValue.capitalized }
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
    /// Running the shortcut ticks the reminder off at the same moment (0.3; on unless switched off).
    public var tickWhenRun: Bool
    /// The colour a repeating reminder wears on its row (0.3), one of `RowColour`, or nil for none.
    public var colour: RowColour?
    /// No nudges for this reminder before this time (0.4, "Pause nudges"); nil = not paused.
    public var pausedUntil: Date?

    public init(id: UUID = UUID(), title: String, due: Date, repeats: Repeat = .never, nudgeMinutes: Int = 5, created: Date = Date(), shortcut: String? = nil, tickWhenRun: Bool = true, colour: RowColour? = nil, pausedUntil: Date? = nil) {
        self.pausedUntil = pausedUntil
        self.shortcut = Reminder.cleanShortcut(shortcut)
        self.tickWhenRun = tickWhenRun
        self.colour = colour
        self.id = id
        self.title = title
        self.due = due
        self.repeats = repeats
        self.nudgeMinutes = nudgeMinutes
        self.created = created
    }

    // Tolerant reading: a field a later version adds never makes an older file unreadable, and a
    // missing field gets a sensible value instead of losing the reminder.
    enum CodingKeys: String, CodingKey { case id, title, due, repeats, nudgeMinutes, created, shortcut, tickWhenRun, colour, pausedUntil }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
        title = (try? c.decode(String.self, forKey: .title)) ?? ""
        due = (try? c.decode(Date.self, forKey: .due)) ?? Date()
        repeats = (try? c.decode(Repeat.self, forKey: .repeats)) ?? .never
        nudgeMinutes = (try? c.decode(Int.self, forKey: .nudgeMinutes)) ?? 5
        created = (try? c.decode(Date.self, forKey: .created)) ?? Date()
        shortcut = Reminder.cleanShortcut(try? c.decode(String.self, forKey: .shortcut))
        tickWhenRun = (try? c.decode(Bool.self, forKey: .tickWhenRun)) ?? true
        // A colour an older or newer version does not know reads as none, never as a broken reminder.
        colour = try? c.decode(RowColour.self, forKey: .colour)
        pausedUntil = try? c.decode(Date.self, forKey: .pausedUntil)
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

    /// The colour its row shows: only a repeating reminder wears one.
    public var shownColour: RowColour? { repeats == .never ? nil : colour }

    /// Does running its shortcut tick it off?
    public var ticksWhenRun: Bool { shortcut != nil && tickWhenRun }

    /// Minutes between two nudges, never less than one.
    public var interval: TimeInterval { TimeInterval(max(1, nudgeMinutes) * 60) }

    /// Are its nudges paused right now?
    public func isPaused(at now: Date) -> Bool { Pause.isOn(pausedUntil, at: now) }

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

    /// Its shortcut was run: ticks it off when it is set to, and returns the link to hand to the
    /// Shortcuts app (nil when it has no shortcut, so nothing happens).
    @discardableResult
    public mutating func runShortcut(_ id: UUID, at now: Date, calendar: Calendar = .current) -> URL? {
        guard let r = reminder(id), let url = r.shortcutURL else { return nil }
        if r.ticksWhenRun { tick(id, at: now, calendar: calendar) }
        return url
    }

    /// Pauses a reminder's nudges until a time, or ends the pause (nil). The reminder itself stays as it is.
    public mutating func pause(_ id: UUID, until date: Date?) {
        if let i = reminders.firstIndex(where: { $0.id == id }) { reminders[i].pausedUntil = date }
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

/// The names of his shortcuts, sent back by the helper shortcut "AMS Reminder List".
public enum ShortcutNames {
    public static let helperName = "AMS Reminder List"
    public static let scheme = "amsreminder"

    /// Reads amsreminder://shortcuts?names=<one per line>: A–Z, no doubles, no empty ones, without the helper.
    /// Nil when the link is not that one.
    public static func read(_ url: URL) -> [String]? {
        guard url.scheme == scheme, url.host == "shortcuts",
              let parts = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        let raw = parts.queryItems?.first(where: { $0.name == "names" })?.value ?? ""
        return clean(raw.components(separatedBy: .newlines))
    }

    public static func clean(_ names: [String]) -> [String] {
        var seen = Set<String>()
        return names
            .compactMap(Reminder.cleanShortcut)
            .filter { $0 != helperName && seen.insert($0).inserted }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    /// The names that hold every word typed in the search field.
    public static func filter(_ names: [String], _ search: String) -> [String] {
        let words = search.split(separator: " ").map(String.init)
        guard !words.isEmpty else { return names }
        return names.filter { n in words.allSatisfy { n.localizedCaseInsensitiveContains($0) } }
    }
}
