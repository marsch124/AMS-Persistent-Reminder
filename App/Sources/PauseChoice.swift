import SwiftUI
import AMSIcons
import ReminderCore

/// Pause nudges (0.4, his ask): On · Tomorrow · Pick a day (· Off for all nudges). A pause ends at 08:00 of its day.
struct PauseChoice: View {
    @Binding var until: Date?
    let allowOff: Bool
    var id = "pause"

    private enum Mode: Hashable { case on, tomorrow, day, off }
    @State private var mode: Mode = .on
    @State private var day = Date()

    var body: some View {
        let now = Date()
        VStack(alignment: .leading, spacing: 8) {
            Picker("Pause nudges", selection: Binding(get: { mode }, set: { choose($0, now) })) {
                Text("On").tag(Mode.on)
                Text("Tomorrow").tag(Mode.tomorrow)
                Text("Pick a day").tag(Mode.day)
                if allowOff { Text("Off").tag(Mode.off) }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("\(id)-choice")
            if mode == .day {
                DatePicker("Day", selection: Binding(get: { day }, set: { day = $0; until = Pause.morning(of: $0) }),
                           in: firstDay(now)..., displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .tint(Theme.purple)
                    .accessibilityIdentifier("\(id)-calendar")
            }
            HStack(spacing: 6) {
                if Pause.isOn(until, at: now) {
                    ControlMarkView(.pause, size: 14, colour: Theme.purple)
                    Text("No nudges \(Pause.text(until!, at: now)). Then they start again by themselves.")
                } else {
                    AppMarkView(.bell, size: 14, colour: Theme.purple)
                    Text("Nudging as usual.")
                }
            }
            .font(.footnote).foregroundStyle(.secondary)
            .accessibilityIdentifier("\(id)-summary")
        }
        .onAppear { read(now) }
    }

    private func firstDay(_ now: Date) -> Date {
        Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: 1, to: now)!)
    }

    private func read(_ now: Date) {
        guard let u = until, Pause.isOn(u, at: now) else { mode = .on; day = firstDay(now); return }
        if u >= Pause.forever { mode = .off; day = firstDay(now) }
        else if u == Pause.tomorrow(after: now) { mode = .tomorrow; day = u }
        else { mode = .day; day = u }
    }

    private func choose(_ m: Mode, _ now: Date) {
        mode = m
        switch m {
        case .on: until = nil
        case .tomorrow: until = Pause.tomorrow(after: now)
        case .day:
            if Calendar.current.startOfDay(for: day) <= firstDay(now) { day = Calendar.current.date(byAdding: .day, value: 1, to: firstDay(now))! }
            until = Pause.morning(of: day)
        case .off: until = Pause.forever
        }
    }
}
