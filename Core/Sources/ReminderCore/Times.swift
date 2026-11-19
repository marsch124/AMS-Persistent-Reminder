import Foundation

/// The quick times on the New reminder page and on a nudge's buttons.
public enum QuickTime: String, CaseIterable, Sendable {
    case inTenMinutes, inOneHour, evening, tomorrowMorning

    /// The evening hour and the morning hour.
    public static let eveningHour = 19
    public static let morningHour = 8

    /// The hours offered in the grid on the New reminder page: 06:00 to 21:00.
    public static let gridHours = Array(6...21)
    public static let gridMinutes = [0, 15, 30, 45]
    public static let nudgeChoices = [1, 5, 10, 15, 30, 60]

    /// The button's words at this moment ("This evening" turns into "Tomorrow evening" after 19:00).
    public func title(at now: Date, calendar: Calendar = .current) -> String {
        switch self {
        case .inTenMinutes: return "In 10 min"
        case .inOneHour: return "In 1 hour"
        case .evening:
            return calendar.component(.hour, from: now) >= QuickTime.eveningHour ? "Tomorrow evening" : "This evening"
        case .tomorrowMorning: return "Tomorrow \(QuickTime.morningHour):00"
        }
    }

    /// The time this quick choice stands for, to the whole minute.
    public func date(from now: Date, calendar: Calendar = .current) -> Date {
        switch self {
        case .inTenMinutes: return wholeMinute(now.addingTimeInterval(10 * 60), calendar)
        case .inOneHour: return wholeMinute(now.addingTimeInterval(60 * 60), calendar)
        case .evening:
            let today = at(hour: QuickTime.eveningHour, minute: 0, on: now, calendar: calendar)
            return today > now ? today : calendar.date(byAdding: .day, value: 1, to: today)!
        case .tomorrowMorning:
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)!
            return at(hour: QuickTime.morningHour, minute: 0, on: tomorrow, calendar: calendar)
        }
    }

    private func wholeMinute(_ d: Date, _ calendar: Calendar) -> Date {
        calendar.dateInterval(of: .minute, for: d)?.start ?? d
    }
}

/// A time of day on a given day.
public func at(hour: Int, minute: Int, on day: Date, calendar: Calendar = .current) -> Date {
    calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
}

/// Pausing nudges (0.4): for one reminder or for all. A pause ends at the morning hour of a day.
public enum Pause {
    /// "Off" in Settings: no nudges until switched on again.
    public static let forever = Date.distantFuture

    public static func isOn(_ until: Date?, at now: Date) -> Bool {
        guard let until else { return false }
        return until > now
    }

    /// Tomorrow at 08:00.
    public static func tomorrow(after now: Date, calendar: Calendar = .current) -> Date {
        QuickTime.tomorrowMorning.date(from: now, calendar: calendar)
    }

    /// The chosen day at 08:00.
    public static func morning(of day: Date, calendar: Calendar = .current) -> Date {
        at(hour: QuickTime.morningHour, minute: 0, on: day, calendar: calendar)
    }

    /// 0.5 (Weekend): no nudges on Saturday and Sunday. From Saturday 00:00 (from now, when it is already the weekend)
    /// until Monday 08:00. `from` is always set: a weekend pause is told apart from "Pick a day" by having it.
    public static func weekend(after now: Date, calendar: Calendar = .current) -> (from: Date?, until: Date) {
        let weekday = calendar.component(.weekday, from: now)   // 1 = Sunday … 7 = Saturday
        let today = calendar.startOfDay(for: now)
        let from: Date
        let monday: Date
        if weekday == 7 || weekday == 1 {
            from = now
            monday = calendar.date(byAdding: .day, value: weekday == 7 ? 2 : 1, to: today) ?? today
        } else {
            let saturday = calendar.date(byAdding: .day, value: 7 - weekday, to: today) ?? today
            from = saturday
            monday = calendar.date(byAdding: .day, value: 2, to: saturday) ?? saturday
        }
        return (from, morning(of: monday, calendar: calendar))
    }

    /// "until tomorrow 08:00", "until Mon 23 Nov, 08:00", "until today 08:00", "until you turn them on";
    /// with a start (the weekend pause) "for the weekend".
    public static func text(_ until: Date, at now: Date, from: Date? = nil, calendar: Calendar = .current) -> String {
        if until >= forever { return "until you turn them on" }
        if from != nil { return "for the weekend" }
        let f = DateFormatter()
        f.calendar = calendar
        f.locale = Locale(identifier: "en_GB")
        f.timeZone = calendar.timeZone
        f.dateFormat = "HH:mm"
        let time = f.string(from: until)
        if calendar.isDate(until, inSameDayAs: now) { return "until today \(time)" }
        if let t = calendar.date(byAdding: .day, value: 1, to: now), calendar.isDate(until, inSameDayAs: t) { return "until tomorrow \(time)" }
        f.dateFormat = "EEE d MMM"
        return "until \(f.string(from: until)), \(time)"
    }
}

/// One planned nudge: which reminder, when, and which nudge it is (1 = at its time).
public struct PlannedNudge: Equatable, Sendable {
    public let reminderID: UUID
    public let date: Date
    public let number: Int
    /// 0.5 (pick 2): this one is a louder one (stronger sound).
    public let louder: Bool
    public init(reminderID: UUID, date: Date, number: Int, louder: Bool = false) {
        self.reminderID = reminderID
        self.date = date
        self.number = number
        self.louder = louder
    }
}

/// The iPhone holds at most 64 planned messages per app, so the app plans the earliest ones across
/// all reminders and tops them up whenever it opens or a nudge's button is pressed.
public enum NudgePlan {
    public static let limit = 60

    /// A time with no nudges: a pause (`from` nil = already started) or quiet hours.
    /// `allPausedUntil` / `allPausedFrom`: every nudge is paused (0.4, Settings; 0.5 weekend); `quiet`: the daily quiet window.
    /// A nudge that falls inside one is dropped, and a reminder whose nudges were held back nudges once when it ends.
    public static func plan(_ reminders: [Reminder], from realNow: Date, allPausedUntil: Date? = nil, allPausedFrom: Date? = nil,
                            quiet: QuietHours? = nil, limit: Int = NudgePlan.limit, calendar: Calendar = .current) -> [PlannedNudge] {
        var all: [PlannedNudge] = []
        for r in reminders {
            var windows: [(from: Date, until: Date)] = []
            if let u = allPausedUntil, u > realNow { windows.append((allPausedFrom ?? .distantPast, u)) }
            if let u = r.pausedUntil, u > realNow { windows.append((r.pausedFrom ?? .distantPast, u)) }

            /// Where the nudges are held back at `date` until, or nil when `date` is free (chains one window into the next).
            func blockEnd(_ date: Date) -> Date? {
                var d = date
                var end: Date?
                for _ in 0..<12 {
                    var e: Date?
                    for w in windows where w.from <= d && d < w.until { e = max(e ?? w.until, w.until) }
                    if let q = quiet?.endIfInside(d, calendar: calendar) { e = max(e ?? q, q) }
                    guard let next = e, next > d else { break }
                    end = next
                    if next >= Pause.forever { break }
                    d = next
                }
                return end
            }

            let stop = r.stopTime(calendar: calendar)
            var owed: [Date: Int] = [:]
            if let e = blockEnd(realNow), e < Pause.forever, r.due < e { owed[e] = max(1, r.nudgesSoFar(at: e)) }
            var number = r.due > realNow ? 1 : r.nudgesSoFar(at: realNow) + 1
            var planned: [PlannedNudge] = []
            var steps = 0
            while planned.count < limit && steps < 5000 {
                steps += 1
                let date = r.nudgeDate(number)
                if let stop, date > stop { break }
                if let e = blockEnd(date) {
                    if e >= Pause.forever { owed.removeAll(); break }
                    owed[e] = max(1, r.nudgesSoFar(at: e))
                    let k = r.nudgesSoFar(at: e)
                    number = max(number + 1, r.nudgeDate(k) == e ? k : k + 1)
                    continue
                }
                planned.append(PlannedNudge(reminderID: r.id, date: date, number: number, louder: r.isLouder(number)))
                number += 1
            }
            for (e, n) in owed where e <= (stop ?? .distantFuture) && !planned.contains(where: { $0.date == e }) {
                planned.append(PlannedNudge(reminderID: r.id, date: e, number: n, louder: r.isLouder(n)))
            }
            all.append(contentsOf: planned)
        }
        return Array(all.sorted { ($0.date, $0.number) < ($1.date, $1.number) }.prefix(limit))
    }
}

/// Words the screens and nudges share.
public enum Words {
    /// "1st", "2nd", "3rd", "4th", "11th", "21st"…
    public static func ordinal(_ n: Int) -> String {
        let tens = (n / 10) % 10, ones = n % 10
        let suffix: String
        if tens == 1 { suffix = "th" } else {
            switch ones { case 1: suffix = "st"; case 2: suffix = "nd"; case 3: suffix = "rd"; default: suffix = "th" }
        }
        return "\(n)\(suffix)"
    }

    /// "Every day", "Every Thursday", "Every month on the 19th", or nil for a one-off.
    public static func repeatText(_ r: Reminder, calendar: Calendar = .current) -> String? {
        switch r.repeats {
        case .never: return nil
        case .daily: return "Every day"
        case .weekly:
            let f = DateFormatter()
            f.calendar = calendar
            f.locale = Locale(identifier: "en_GB")
            f.timeZone = calendar.timeZone
            f.dateFormat = "EEEE"
            return "Every \(f.string(from: r.due))"
        case .monthly: return "Every month on the \(ordinal(calendar.component(.day, from: r.due)))"
        // 0.5 stubs — lane "repeats" writes the real words.
        case .weekdays, .hours, .days: return "Repeats"
        }
    }

    /// The small grey line under a reminder on the main screen.
    /// While all nudges are paused (`allPausedUntil`), a waiting one says so instead of "Nudging every …".
    public static func rowLine(_ r: Reminder, at now: Date, allPausedUntil: Date? = nil, calendar: Calendar = .current) -> String {
        // A weekend pause already set but not begun (`pausedFrom` ahead) shows too.
        let own = Pause.isOn(r.pausedUntil, at: now) ? r.pausedUntil : nil
        let all = Pause.isOn(allPausedUntil, at: now) ? allPausedUntil : nil
        if let until = [own, all].compactMap({ $0 }).max(), own != nil || r.isWaiting(at: now) {
            return "Paused \(Pause.text(until, at: now, from: until == own ? r.pausedFrom : nil, calendar: calendar))"
        }
        if r.hasStopped(at: now, calendar: calendar), let s = r.stopAt {
            return "Stopped nudging at \(String(format: "%02d:%02d", s / 60, s % 60))"
        }
        if r.isWaiting(at: now) {
            return "Nudging every \(r.nudgeMinutes) min · \(ordinal(r.nudgesSoFar(at: now))) nudge"
        }
        return repeatText(r, calendar: calendar) ?? "Nudge every \(r.nudgeMinutes) min"
    }

    /// The text of a nudge message.
    public static func nudgeBody(_ r: Reminder, number: Int, calendar: Calendar = .current) -> String {
        let f = DateFormatter()
        f.calendar = calendar
        f.timeZone = calendar.timeZone
        f.dateFormat = "HH:mm"
        var body: String
        if number <= 1 {
            body = "It's time. I'll nudge you again in \(r.nudgeMinutes) min until you tick it off."
        } else if r.isLouder(number) {
            let m = r.louderInterval / 60
            let every = m == m.rounded() ? "\(Int(m))" : "\(Int(m))½"
            body = "Since \(f.string(from: r.due)) · \(ordinal(number)) nudge. I'll keep at it every \(every) min."
        } else {
            body = "Since \(f.string(from: r.due)) · \(ordinal(number)) nudge. Next one in \(r.nudgeMinutes) min."
        }
        // 0.5 (pick 16): the reminder's own few words close the nudge.
        if let note = r.note, !note.isEmpty { body += "\n\(note)" }
        return body
    }
}
