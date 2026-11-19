import Foundation

// 0.5, lane "nudges": louder nudges, stop at a time, quiet hours, the choosable "later" buttons.

extension Reminder {
    /// Pick 2: the nudge from which a "louder" reminder nudges twice as often, with a stronger sound.
    public static let louderFrom = 4

    /// The gap between nudges once it is louder: half the usual one, never under 1 minute.
    public var louderInterval: TimeInterval { max(60, interval / 2) }

    /// Is nudge number `n` a louder one?
    public func isLouder(_ n: Int) -> Bool { louder && n >= Reminder.louderFrom }

    /// When nudge number `n` (1 = at its time) comes.
    public func nudgeDate(_ n: Int) -> Date {
        let steady = min(n, louder ? Reminder.louderFrom : n)
        let extra = louder ? max(0, n - Reminder.louderFrom) : 0
        return due.addingTimeInterval(Double(steady - 1) * interval + Double(extra) * louderInterval)
    }

    /// Pick 5: the moment after which it nudges no more (on the day it is for), or nil.
    public func stopTime(calendar: Calendar = .current) -> Date? {
        guard let s = stopAt else { return nil }
        return at(hour: s / 60, minute: s % 60, on: due, calendar: calendar)
    }

    /// A copy whose pause starts at `from` (the weekend pause); it keeps no start when it is not paused.
    public func pausing(from: Date?) -> Reminder {
        var r = self
        r.pausedFrom = pausedUntil == nil ? nil : from
        return r
    }

    /// Has it been waiting past its stop time, so nudging has stopped?
    public func hasStopped(at now: Date, calendar: Calendar = .current) -> Bool {
        guard isWaiting(at: now), let t = stopTime(calendar: calendar) else { return false }
        return now > t
    }
}

/// Pick 4: a daily window with no nudges. Minutes after midnight; `to` may be before `from` (it crosses midnight).
public struct QuietHours: Equatable, Sendable {
    public static let defaultFrom = 22 * 60
    public static let defaultTo = 7 * 60
    public var from: Int
    public var to: Int
    public init(from: Int = QuietHours.defaultFrom, to: Int = QuietHours.defaultTo) { self.from = from; self.to = to }

    /// When the quiet window that holds `date` ends, or nil when `date` is not inside one.
    public func endIfInside(_ date: Date, calendar: Calendar = .current) -> Date? {
        guard from != to else { return nil }
        let m = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
        let inside = from < to ? (m >= from && m < to) : (m >= from || m < to)
        guard inside else { return nil }
        var day = date
        if from > to && m >= from { day = calendar.date(byAdding: .day, value: 1, to: date) ?? date }
        return at(hour: to / 60, minute: to % 60, on: day, calendar: calendar)
    }
}

/// Pick 6: the three "later" buttons on a nudge. The raw values are the buttons' identifiers.
public enum LaterChoice: String, CaseIterable, Sendable {
    case fiveMinutes, tenMinutes, fifteenMinutes, thirtyMinutes, oneHour, twoHours, evening

    public static let defaults: [LaterChoice] = [.tenMinutes, .oneHour, .evening]
    public static let count = 3

    /// The chip's words in Settings.
    public var chipTitle: String {
        switch self {
        case .fiveMinutes: return "5 min"
        case .tenMinutes: return "10 min"
        case .fifteenMinutes: return "15 min"
        case .thirtyMinutes: return "30 min"
        case .oneHour: return "1 hour"
        case .twoHours: return "2 hours"
        case .evening: return "This evening"
        }
    }

    /// The button's words on a nudge.
    public var buttonTitle: String {
        switch self {
        case .fiveMinutes: return "In 5 minutes"
        case .tenMinutes: return "In 10 minutes"
        case .fifteenMinutes: return "In 15 minutes"
        case .thirtyMinutes: return "In 30 minutes"
        case .oneHour: return "In 1 hour"
        case .twoHours: return "In 2 hours"
        case .evening: return "This evening"
        }
    }

    /// The time this button moves the reminder to.
    public func date(from now: Date, calendar: Calendar = .current) -> Date {
        let minutes: Int
        switch self {
        case .fiveMinutes: minutes = 5
        case .tenMinutes: minutes = 10
        case .fifteenMinutes: minutes = 15
        case .thirtyMinutes: minutes = 30
        case .oneHour: minutes = 60
        case .twoHours: minutes = 120
        case .evening: return QuickTime.evening.date(from: now, calendar: calendar)
        }
        let later = now.addingTimeInterval(Double(minutes) * 60)
        return calendar.dateInterval(of: .minute, for: later)?.start ?? later
    }

    /// Exactly three, shortest first, from what was saved ("tenMinutes,oneHour,evening"); anything wrong or missing
    /// is filled from the usual three.
    public static func parse(_ saved: String?) -> [LaterChoice] {
        var chosen: [LaterChoice] = []
        for part in (saved ?? "").split(separator: ",") {
            if let c = LaterChoice(rawValue: String(part)), !chosen.contains(c) { chosen.append(c) }
        }
        for d in defaults + allCases where chosen.count < count && !chosen.contains(d) { chosen.append(d) }
        return Array(chosen.prefix(count))
    }

    public static func save(_ choices: [LaterChoice]) -> String { choices.map(\.rawValue).joined(separator: ",") }

    /// Tapping a chip: a new one comes in, the one picked longest ago goes out; a chosen one stays (always three).
    public static func picking(_ c: LaterChoice, in current: [LaterChoice]) -> [LaterChoice] {
        var list = parse(save(current))
        guard !list.contains(c) else { return list }
        list.append(c)
        return Array(list.suffix(count))
    }

    /// The order they stand in on a nudge: by the clock.
    public var order: Int { LaterChoice.allCases.firstIndex(of: self) ?? 0 }
}

extension ReminderList {
    /// Pauses a reminder from a start time (0.5, the weekend) until a time. `from` nil = starts now.
    public mutating func pause(_ id: UUID, from: Date?, until: Date?) {
        if let i = reminders.firstIndex(where: { $0.id == id }) { reminders[i].pausedUntil = until; reminders[i].pausedFrom = until == nil ? nil : from }
    }
}
