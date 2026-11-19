import SwiftUI
import AMSIcons
import ReminderCore

/// Pause nudges (0.4, his ask): On · Tomorrow · Weekend · Pick a day (· Off for all nudges). A pause ends at 08:00 of its day.
/// 0.5: "Weekend" = no nudges on Saturday and Sunday, from Saturday 00:00 until Monday 08:00; it also sets `from`.
struct PauseChoice: View {
    @Binding var until: Date?
    var from: Binding<Date?> = .constant(nil)
    let allowOff: Bool
    var id = "pause"

    private enum Mode: Hashable { case on, tomorrow, weekend, day, off }
    @State private var mode: Mode = .on
    @State private var day = Date()

    var body: some View {
        let now = Date()
        VStack(alignment: .leading, spacing: 8) {
            // 0.5: chips instead of a segmented bar — five choices did not fit ("Tomorr…", "Pick a d…").
            // Filled purple = the one chosen (purple = nudges and pausing).
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 6) { ForEach(modes, id: \.self) { chip($0, now) } }
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) { ForEach(modes.prefix(3), id: \.self) { chip($0, now) } }
                    HStack(spacing: 6) { ForEach(modes.dropFirst(3), id: \.self) { chip($0, now) } }
                }
            }
            .accessibilityElement(children: .contain)
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
                    Text("No nudges \(Pause.text(until!, at: now, from: from.wrappedValue)). Then they start again by themselves.")
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

    private var modes: [Mode] { allowOff ? [.on, .tomorrow, .weekend, .day, .off] : [.on, .tomorrow, .weekend, .day] }

    private func title(_ m: Mode) -> String {
        switch m {
        case .on: return "On"
        case .tomorrow: return "Tomorrow"
        case .weekend: return "Weekend"
        case .day: return "Pick a day"
        case .off: return "Off"
        }
    }

    private func chip(_ m: Mode, _ now: Date) -> some View {
        let on = mode == m
        return Button { choose(m, now) } label: {
            Text(title(m))
                .font(.subheadline.weight(.medium)).lineLimit(1).fixedSize()
                .padding(.horizontal, 12).padding(.vertical, 7)
                .foregroundStyle(on ? Color.white : Color.primary)
                .background(on ? Theme.purpleFill : Color(.tertiarySystemFill), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title(m))
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private func firstDay(_ now: Date) -> Date {
        Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: 1, to: now)!)
    }

    private func read(_ now: Date) {
        guard let u = until, Pause.isOn(u, at: now) else { mode = .on; day = firstDay(now); return }
        if u >= Pause.forever { mode = .off; day = firstDay(now) }
        else if from.wrappedValue != nil { mode = .weekend; day = firstDay(now) }
        else if u == Pause.tomorrow(after: now) { mode = .tomorrow; day = u }
        else { mode = .day; day = u }
    }

    private func choose(_ m: Mode, _ now: Date) {
        mode = m
        if m != .weekend { from.wrappedValue = nil }
        switch m {
        case .on: until = nil
        case .weekend:
            let w = Pause.weekend(after: now)
            from.wrappedValue = w.from
            until = w.until
        case .tomorrow: until = Pause.tomorrow(after: now)
        case .day:
            if Calendar.current.startOfDay(for: day) <= firstDay(now) { day = Calendar.current.date(byAdding: .day, value: 1, to: firstDay(now))! }
            until = Pause.morning(of: day)
        case .off: until = Pause.forever
        }
    }
}
