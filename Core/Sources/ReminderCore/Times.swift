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

    /// "until tomorrow 08:00", "until Mon 23 Nov, 08:00", "until today 08:00", "until you turn them on".
    public static func text(_ until: Date, at now: Date, calendar: Calendar = .current) -> String {
        if until >= forever { return "until you turn them on" }
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
    public init(reminderID: UUID, date: Date, number: Int) {
        self.reminderID = reminderID
        self.date = date
        self.number = number
    }
}

/// The iPhone holds at most 64 planned messages per app, so the app plans the earliest ones across
/// all reminders and tops them up whenever it opens or a nudge's button is pressed.
public enum NudgePlan {
    public static let limit = 60

    /// `allPausedUntil`: every nudge is paused until then (0.4, Settings); nudges are planned only from its end.
    public static func plan(_ reminders: [Reminder], from realNow: Date, allPausedUntil: Date? = nil, limit: Int = NudgePlan.limit) -> [PlannedNudge] {
        var all: [PlannedNudge] = []
        let start = Pause.isOn(allPausedUntil, at: realNow) ? allPausedUntil! : realNow
        if start >= Pause.forever { return [] }
        for r in reminders {
            // A paused reminder starts again where its own pause ends (0.4).
            let now = Pause.isOn(r.pausedUntil, at: start) ? r.pausedUntil! : start
            if now >= Pause.forever { continue }
            // The first nudge still to come, and its number.
            var number = r.due > now ? 1 : r.nudgesSoFar(at: now) + 1
            var date = r.due.addingTimeInterval(Double(number - 1) * r.interval)
            // When a pause ends on a reminder whose time has come, it nudges right at that moment.
            if now > realNow && r.due < now {
                all.append(PlannedNudge(reminderID: r.id, date: now, number: number - 1))
            }
            // No more than `limit` per reminder is ever needed.
            for _ in 0..<limit {
                all.append(PlannedNudge(reminderID: r.id, date: date, number: number))
                number += 1
                date = date.addingTimeInterval(r.interval)
            }
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
        }
    }

    /// The small grey line under a reminder on the main screen.
    /// While all nudges are paused (`allPausedUntil`), a waiting one says so instead of "Nudging every …".
    public static func rowLine(_ r: Reminder, at now: Date, allPausedUntil: Date? = nil, calendar: Calendar = .current) -> String {
        let own = r.isPaused(at: now) ? r.pausedUntil : nil
        let all = Pause.isOn(allPausedUntil, at: now) ? allPausedUntil : nil
        if let until = [own, all].compactMap({ $0 }).max(), own != nil || r.isWaiting(at: now) {
            return "Paused \(Pause.text(until, at: now, calendar: calendar))"
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
        if number <= 1 { return "It's time. I'll nudge you again in \(r.nudgeMinutes) min until you tick it off." }
        return "Since \(f.string(from: r.due)) · \(ordinal(number)) nudge. Next one in \(r.nudgeMinutes) min."
    }
}
