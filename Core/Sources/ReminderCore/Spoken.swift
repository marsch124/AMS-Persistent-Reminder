import Foundation

/// 0.5 (voice): turns what was said ("Remind me to call Anna tomorrow at 3") into a title and a time.
public enum Spoken {
    private static let weekdayNames = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]

    /// Removes the first match of `pattern` from `s` and returns the match's capture groups (lowercased).
    private static func take(_ pattern: String, from s: inout String) -> [String]? {
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let ns = s as NSString
        guard let m = re.firstMatch(in: s, range: NSRange(location: 0, length: ns.length)) else { return nil }
        var groups: [String] = []
        for i in 0..<m.numberOfRanges {
            let r = m.range(at: i)
            groups.append(r.location == NSNotFound ? "" : ns.substring(with: r).lowercased())
        }
        s = ns.replacingCharacters(in: m.range, with: " ")
        return groups
    }

    private static func number(_ w: String) -> Int? {
        if let n = Int(w) { return n }
        switch w {
        case "a", "an", "one": return 1
        case "two": return 2
        case "three": return 3
        case "four": return 4
        case "five": return 5
        case "ten": return 10
        case "fifteen": return 15
        case "twenty": return 20
        case "thirty": return 30
        default: return nil
        }
    }

    public static func parse(_ text: String, now: Date, calendar: Calendar = .current) -> (title: String, due: Date?) {
        var rest = text
        func finish(_ due: Date?) -> (title: String, due: Date?) { (clean(rest, fallback: text), due) }

        // 1. "in 20 minutes", "in 2 hours", "in an hour", "in half an hour"
        if take(#"\bin\s+half\s+an\s+hour\b"#, from: &rest) != nil {
            return finish(now.addingTimeInterval(30 * 60))
        }
        if let g = take(#"\bin\s+(\d+|an?|one|two|three|four|five|ten|fifteen|twenty|thirty)\s+(minutes?|mins?|hours?|hrs?)\b"#, from: &rest),
           let n = number(g[1]) {
            let hours = g[2].hasPrefix("h")
            return finish(now.addingTimeInterval(TimeInterval(n * (hours ? 3600 : 60))))
        }

        // 2. The day (and a part of the day).
        enum Part { case none, morning, evening }
        var dayOffset: Int?          // 1 = tomorrow
        var weekday: Int?            // 0 = Sunday
        var part = Part.none
        var named = false
        if take(#"\btomorrow\s+morning\b"#, from: &rest) != nil { dayOffset = 1; part = .morning; named = true }
        else if take(#"\btomorrow\s+(evening|night)\b"#, from: &rest) != nil { dayOffset = 1; part = .evening; named = true }
        else if take(#"\b(tonight|this\s+evening)\b"#, from: &rest) != nil { part = .evening; named = true }
        else if take(#"\btomorrow\b"#, from: &rest) != nil { dayOffset = 1; named = true }
        else if let g = take(#"\b(?:on\s+|next\s+|this\s+)*(sunday|monday|tuesday|wednesday|thursday|friday|saturday)\b"#, from: &rest) {
            weekday = weekdayNames.firstIndex(of: g[1]); named = true
        }

        // 3. The clock time.
        var hour: Int?
        var minute = 0
        if let g = take(#"\bat\s+half\s+past\s+(\d{1,2})\b"#, from: &rest), let h = Int(g[1]) {
            hour = h; minute = 30
            if (1...7).contains(h) { hour = h + 12 }
        } else if let g = take(#"\bat\s+(\d{1,2})(?:[:.](\d{2}))?\s*(am|pm|a\.m\.|p\.m\.)?(?!\w)"#, from: &rest), var h = Int(g[1]) {
            minute = Int(g[2]) ?? 0
            let ap = g[3].replacingOccurrences(of: ".", with: "")
            if ap == "pm" { if h < 12 { h += 12 } }
            else if ap == "am" { if h == 12 { h = 0 } }
            else if g[2].isEmpty || h <= 12 {
                if (1...7).contains(h) { h += 12 }
                else if part == .evening, (8...11).contains(h) { h += 12 }
            }
            hour = h
        }
        if let h = hour, h > 23 || minute > 59 { return (clean(text, fallback: text), nil) }

        guard named || hour != nil else { return (clean(text, fallback: text), nil) }

        let defaultHour: Int
        switch part {
        case .evening: defaultHour = QuickTime.eveningHour
        default: defaultHour = QuickTime.morningHour
        }
        let h = hour ?? defaultHour
        let m = hour == nil ? 0 : minute

        let today = calendar.startOfDay(for: now)
        func day(_ n: Int) -> Date { calendar.date(byAdding: .day, value: n, to: today)! }

        var due: Date
        if let wd = weekday {
            let current = calendar.component(.weekday, from: now) - 1
            var add = (wd - current + 7) % 7
            due = at(hour: h, minute: m, on: day(add), calendar: calendar)
            if due <= now { add += 7; due = at(hour: h, minute: m, on: day(add), calendar: calendar) }
        } else if let off = dayOffset {
            due = at(hour: h, minute: m, on: day(off), calendar: calendar)
        } else {
            due = at(hour: h, minute: m, on: today, calendar: calendar)
            if due <= now { due = at(hour: h, minute: m, on: day(1), calendar: calendar) }
        }
        return finish(due)
    }

    /// Takes away "remind me to" / "to", dangling little words and extra spaces, and capitalises the first letter.
    private static func clean(_ s: String, fallback: String) -> String {
        var t = s.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        for lead in ["remind me to ", "remind me ", "to "] where t.lowercased().hasPrefix(lead) {
            t = String(t.dropFirst(lead.count)); break
        }
        while let last = t.split(separator: " ").last, ["at", "on", "in", "by", "for"].contains(last.lowercased()) {
            t = t.split(separator: " ").dropLast().joined(separator: " ")
        }
        t = t.trimmingCharacters(in: CharacterSet(charactersIn: " ,.;:"))
        if t.isEmpty { t = fallback.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard let f = t.first else { return t }
        return f.uppercased() + t.dropFirst()
    }
}
