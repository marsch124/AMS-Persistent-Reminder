import Foundation

// The rules of AMS Persistent Reminder, with no screen in them. `swift test --package-path Core`
// runs their tests in seconds.

/// How often a reminder comes back after it has been ticked off.
public enum Repeat: String, Codable, CaseIterable, Sendable {
    case never, daily, weekly, monthly
    /// 0.5: on chosen days of the week (`Reminder.weekdays`), every few hours / every few days (`Reminder.every`).
    case weekdays, hours, days

    public var title: String {
        switch self {
        case .never: return "Never"
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .weekdays: return "On days"
        case .hours: return "Hours"
        case .days: return "Days"
        }
    }
}

/// 0.5 (pick 17): what pressing and holding a reminder (or the nudge's first button) opens — a phone call or a link.
public struct TapAction: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable { case call, link }
    public var kind: Kind
    /// A phone number for `.call`, a web address for `.link`.
    public var value: String
    /// What the button says after "Call" / "Open", e.g. the contact's name; may be empty.
    public var label: String
    public init(kind: Kind, value: String, label: String = "") {
        self.kind = kind; self.value = value; self.label = label
    }

    /// tel:<digits and +> for a call; for a link, the address with https:// added when it has no scheme. Nil when empty.
    public var url: URL? {
        let v = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !v.isEmpty else { return nil }
        switch kind {
        case .call:
            let digits = v.filter { $0.isNumber || $0 == "+" }
            return digits.isEmpty ? nil : URL(string: "tel:\(digits)")
        case .link:
            return URL(string: v.contains("://") ? v : "https://\(v)")
        }
    }

    /// The button's words: "Call Anna", "Call 070 123 45 67", "Open Weather", "Open link".
    public var buttonTitle: String {
        let name = label.trimmingCharacters(in: .whitespacesAndNewlines)
        switch kind {
        case .call: return "Call \(name.isEmpty ? value : name)"
        case .link: return "Open \(name.isEmpty ? "link" : name)"
        }
    }
}

/// 0.5 (pick 3): a reminder's own nudge sound. The files are bundled as `<rawValue>.caf`; nil on a reminder = the iPhone's own sound.
public enum NudgeSound: String, Codable, CaseIterable, Sendable {
    case chime, bell, marimba, pop, rise, knock
    public var title: String { rawValue.capitalized }
    public var fileName: String { "\(rawValue).caf" }
}

/// 0.5 (pick 11): a place where a reminder starts nudging, on arriving or on leaving.
public struct Place: Codable, Equatable, Sendable {
    /// The `due` of a place reminder that has not reached its place yet (it never nudges until then).
    public static let notYet = Date.distantFuture

    public var name: String
    public var latitude: Double
    public var longitude: Double
    /// Metres around the spot that count as being there.
    public var radius: Double
    /// true = when I arrive, false = when I leave.
    public var onArrive: Bool
    public init(name: String, latitude: Double, longitude: Double, radius: Double = 150, onArrive: Bool = true) {
        self.name = name; self.latitude = latitude; self.longitude = longitude; self.radius = radius; self.onArrive = onArrive
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
    /// 0.5 (Weekend pause): the pause starts at this time (nil = it started already). Lane "nudges" uses it.
    public var pausedFrom: Date?

    // 0.5 — each field belongs to one pick; all read tolerantly (missing = the value in init).
    /// Pick 16: a few extra words, shown on the row and in the nudge; nil = none.
    public var note: String?
    /// Pick 17: call someone or open a link.
    public var action: TapAction?
    /// Pick 3: its own nudge sound; nil = the iPhone's own.
    public var sound: NudgeSound?
    /// Pick 2: after 3 nudges it nudges twice as often (never under 1 min) with a stronger sound.
    public var louder: Bool
    /// Pick 5: stop nudging at this time of day (minutes after midnight) on the day it is for; nil = never stops.
    public var stopAt: Int?
    /// Pick 8: the N in "every N hours" / "every N days" (`Repeat.hours` / `.days`), at least 1.
    public var every: Int
    /// Pick 7: the days for `Repeat.weekdays`, Calendar weekday numbers (1 = Sunday … 7 = Saturday).
    public var weekdays: [Int]
    /// Pick 9: the next time is counted from when it was ticked off, not from when it was due.
    public var afterDone: Bool
    /// Pick 11: starts nudging when arriving at / leaving this place; nil = an ordinary timed reminder.
    public var place: Place?

    public init(id: UUID = UUID(), title: String, due: Date, repeats: Repeat = .never, nudgeMinutes: Int = 5, created: Date = Date(), shortcut: String? = nil, tickWhenRun: Bool = true, colour: RowColour? = nil, pausedUntil: Date? = nil,
                note: String? = nil, action: TapAction? = nil, sound: NudgeSound? = nil, louder: Bool = true, stopAt: Int? = nil, every: Int = 2, weekdays: [Int] = [], afterDone: Bool = false, place: Place? = nil) {
        self.pausedUntil = pausedUntil
        self.note = Reminder.cleanShortcut(note)
        self.action = action
        self.sound = sound
        self.louder = louder
        self.stopAt = stopAt
        self.every = max(1, every)
        self.weekdays = weekdays
        self.afterDone = afterDone
        self.place = place
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
    enum CodingKeys: String, CodingKey { case id, title, due, repeats, nudgeMinutes, created, shortcut, tickWhenRun, colour, pausedUntil
        case pausedFrom, note, action, sound, louder, stopAt, every, weekdays, afterDone, place }
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
        pausedFrom = try? c.decode(Date.self, forKey: .pausedFrom)
        note = Reminder.cleanShortcut(try? c.decode(String.self, forKey: .note))
        action = try? c.decode(TapAction.self, forKey: .action)
        sound = try? c.decode(NudgeSound.self, forKey: .sound)
        louder = (try? c.decode(Bool.self, forKey: .louder)) ?? true
        stopAt = try? c.decode(Int.self, forKey: .stopAt)
        every = max(1, (try? c.decode(Int.self, forKey: .every)) ?? 2)
        weekdays = (try? c.decode([Int].self, forKey: .weekdays)) ?? []
        afterDone = (try? c.decode(Bool.self, forKey: .afterDone)) ?? false
        place = try? c.decode(Place.self, forKey: .place)
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
        if repeats == .never { return nil }
        // 0.5 (pick 9): "count from when I tick it off" — the interval starts at `now`, not at the due time.
        if afterDone {
            switch repeats {
            case .never: return nil
            case .daily: return calendar.date(byAdding: .day, value: 1, to: now)
            case .weekly: return calendar.date(byAdding: .weekOfYear, value: 1, to: now)
            case .monthly: return calendar.date(byAdding: .month, value: 1, to: now)
            case .hours: return calendar.date(byAdding: .hour, value: max(1, every), to: now)
            case .days: return calendar.date(byAdding: .day, value: max(1, every), to: now)
            case .weekdays: return nextChosenDay(from: now, calendar: calendar, after: now)
            }
        }
        let unit: Calendar.Component
        var step = 1
        switch repeats {
        case .never: return nil
        case .daily: unit = .day
        case .weekly: unit = .weekOfYear
        case .monthly: unit = .month
        case .hours: unit = .hour; step = max(1, every)
        case .days: unit = .day; step = max(1, every)
        case .weekdays: return nextChosenDay(from: due, calendar: calendar, after: now)
        }
        var n = 1
        while n < 100_000 {
            if let d = calendar.date(byAdding: unit, value: n * step, to: due), d > now { return d }
            n += 1
        }
        return nil
    }

    /// The first chosen weekday after the day of `start`, at this reminder's own time of day, and later than `now`.
    private func nextChosenDay(from start: Date, calendar: Calendar, after now: Date) -> Date? {
        let chosen = Set(weekdays.filter { (1...7).contains($0) })
        let days = chosen.isEmpty ? [calendar.component(.weekday, from: due)] : Array(chosen)
        let time = calendar.dateComponents([.hour, .minute], from: due)
        let startDay = calendar.startOfDay(for: start)
        for n in 1...400 {
            guard let day = calendar.date(byAdding: .day, value: n, to: startDay),
                  days.contains(calendar.component(.weekday, from: day)),
                  let d = calendar.date(bySettingHour: time.hour ?? 0, minute: time.minute ?? 0, second: 0, of: day),
                  d > now else { continue }
            return d
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
    /// 0.5 (pick 12): this time was skipped, not done — never counted as late.
    public var skipped: Bool

    public init(id: UUID = UUID(), reminder: Reminder, doneAt: Date, nudges: Int, skipped: Bool = false) {
        self.skipped = skipped
        self.id = id
        self.reminder = reminder
        self.doneAt = doneAt
        self.nudges = nudges
    }

    enum CodingKeys: String, CodingKey { case id, reminder, doneAt, nudges, skipped }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
        reminder = try c.decode(Reminder.self, forKey: .reminder)
        doneAt = (try? c.decode(Date.self, forKey: .doneAt)) ?? Date()
        nudges = (try? c.decode(Int.self, forKey: .nudges)) ?? 0
        skipped = (try? c.decode(Bool.self, forKey: .skipped)) ?? false
    }

    /// "On time" or "After 3 nudges" — said kindly; "Skipped" for a skipped time (0.5).
    public var howText: String {
        if skipped { return "Skipped" }
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

    /// 0.5 (pick 12): a repeating reminder skips this time: it moves on to its next time (counted from now when it
    /// repeats after it is ticked) and the Done list gets a "Skipped" entry with no nudges. A one-off reminder is
    /// not changed and nothing is returned.
    @discardableResult
    public mutating func skip(_ id: UUID, at now: Date, calendar: Calendar = .current) -> DoneEntry? {
        guard let i = reminders.firstIndex(where: { $0.id == id }),
              let next = reminders[i].nextOccurrence(after: now, calendar: calendar) else { return nil }
        let entry = DoneEntry(reminder: reminders[i], doneAt: now, nudges: 0, skipped: true)
        done.insert(entry, at: 0)
        reminders[i].due = next
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
        // A skipped time is not a done one.
        return (doneToday(at: now, calendar: calendar).filter { !$0.skipped }.count, s.waiting.count + s.today.count)
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
