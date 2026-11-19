import SwiftUI
import AMSIcons
import ReminderCore

/// New reminder, or changing one: what, when (quick buttons, day, hour grid, minutes), repeat, nudge.
struct EditReminderView: View {
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss
    @AppStorage("defaultNudge") private var defaultNudge = 5

    let target: EditTarget
    @State private var title = ""
    @State private var due = Date()
    @State private var repeats: Repeat = .never
    @State private var nudge = 5
    @State private var pickingDay = false
    @State private var askDelete = false
    @FocusState private var titleFocused: Bool

    private enum DayChoice: Hashable { case today, tomorrow, other }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    TextField("What should I remind you of?", text: $title)
                        .font(.title3.weight(.medium))
                        .focused($titleFocused)
                        .submitLabel(.done)
                        .onSubmit { titleFocused = false }
                        .padding(.horizontal, 14).padding(.vertical, 12)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                        .accessibilityIdentifier("title-field")

                    heading("When")
                    quickButtons
                    Picker("Day", selection: dayBinding) {
                        Text("Today").tag(DayChoice.today)
                        Text("Tomorrow").tag(DayChoice.tomorrow)
                        Text(dayChoice == .other ? Theme.shortDay(due) : "Pick a day").tag(DayChoice.other)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("day-picker")
                    if pickingDay {
                        DatePicker("Day", selection: dayOnlyBinding, in: Calendar.current.startOfDay(for: Date())..., displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .tint(Theme.blue)
                            .padding(6)
                            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                    }
                    hourGrid
                    Picker("Minutes", selection: minuteBinding) {
                        ForEach(QuickTime.gridMinutes, id: \.self) { m in Text(String(format: ":%02d", m)).tag(m) }
                    }
                    .pickerStyle(.segmented)
                    Text(summary).font(.footnote).foregroundStyle(Theme.blue)
                        .accessibilityIdentifier("due-summary")

                    heading("Repeat")
                    Picker("Repeat", selection: $repeats) {
                        ForEach(Repeat.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    heading("Nudge me every")
                    Picker("Nudge me every", selection: $nudge) {
                        ForEach(QuickTime.nudgeChoices, id: \.self) { m in Text(m == 60 ? "60 min" : "\(m)").tag(m) }
                    }
                    .pickerStyle(.segmented)
                    HStack(spacing: 6) {
                        AppMarkView(.bell, size: 14, colour: Theme.purple)
                        Text("Keeps reminding you until you tick it off.")
                    }
                    .font(.footnote).foregroundStyle(.secondary)

                    if case .edit = target {
                        Button(role: .destructive) { askDelete = true } label: {
                            Text("Delete reminder").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .padding(.top, 8)
                        .accessibilityIdentifier("delete-reminder")
                    }
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(isNew ? "New reminder" : "Change reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.accessibilityIdentifier("cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: save) {
                        Text("Save").bold().foregroundStyle(.white)
                            .padding(.horizontal, 14).padding(.vertical, 5)
                            .background(Theme.blueFill, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("save")
                }
            }
            .confirmationDialog("Delete this reminder?", isPresented: $askDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if case .edit(let r) = target { store.delete(r.id) }
                    dismiss()
                }
            }
        }
        .onAppear(perform: fill)
    }

    private var isNew: Bool { if case .new = target { return true } else { return false } }

    private func fill() {
        switch target {
        case .new:
            nudge = defaultNudge
            // The next full hour.
            let cal = Calendar.current
            let next = cal.date(byAdding: .hour, value: 1, to: Date())!
            due = at(hour: cal.component(.hour, from: next), minute: 0, on: next)
            titleFocused = true
        case .edit(let r):
            title = r.title
            due = r.due
            repeats = r.repeats
            nudge = r.nudgeMinutes
        }
        pickingDay = dayChoice == .other
    }

    private func save() {
        let text = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { titleFocused = true; return }
        // A time that has already passed nudges right away (in a few seconds).
        let due = self.due < Date() ? Date().addingTimeInterval(5) : self.due
        switch target {
        case .new:
            store.add(Reminder(title: text, due: due, repeats: repeats, nudgeMinutes: nudge))
        case .edit(var r):
            r.title = text
            r.due = due
            r.repeats = repeats
            r.nudgeMinutes = nudge
            store.update(r)
        }
        dismiss()
    }

    // MARK: When

    private var quickButtons: some View {
        let now = Date()
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: 7) { ForEach(QuickTime.allCases, id: \.self) { chip($0, now) } }
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 7) { chip(.inTenMinutes, now); chip(.inOneHour, now); chip(.evening, now) }
                chip(.tomorrowMorning, now)
            }
        }
    }

    private func chip(_ q: QuickTime, _ now: Date) -> some View {
        let date = q.date(from: now)
        let on = abs(date.timeIntervalSince(due)) < 60
        return Button {
            due = date
            pickingDay = false
        } label: {
            Text(q.title(at: now))
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 12).padding(.vertical, 7)
                .foregroundStyle(on ? .white : .primary)
                .background(on ? Theme.blueFill : Color(.secondarySystemGroupedBackground), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("quick-\(q.rawValue)")
    }

    private var hourGrid: some View {
        let hour = Calendar.current.component(.hour, from: due)
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
            ForEach(QuickTime.gridHours, id: \.self) { h in
                Button {
                    due = at(hour: h, minute: Calendar.current.component(.minute, from: due), on: due)
                } label: {
                    Text(String(format: "%02d:00", h))
                        .font(.subheadline.weight(.medium)).monospacedDigit()
                        .frame(maxWidth: .infinity).padding(.vertical, 7)
                        .foregroundStyle(h == hour ? .white : .primary)
                        .background(h == hour ? Theme.blueFill : Color(.systemGroupedBackground), in: RoundedRectangle(cornerRadius: 9))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("hour-\(h)")
            }
        }
        .padding(8)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private var dayChoice: DayChoice {
        let cal = Calendar.current
        if cal.isDateInToday(due) { return .today }
        if cal.isDateInTomorrow(due) { return .tomorrow }
        return .other
    }

    private var dayBinding: Binding<DayChoice> {
        Binding(get: { pickingDay ? .other : dayChoice }, set: { new in
            let cal = Calendar.current
            switch new {
            case .today: moveDay(to: Date()); pickingDay = false
            case .tomorrow: moveDay(to: cal.date(byAdding: .day, value: 1, to: Date())!); pickingDay = false
            case .other: pickingDay = true
            }
        })
    }

    private var dayOnlyBinding: Binding<Date> {
        Binding(get: { due }, set: { moveDay(to: $0) })
    }

    private var minuteBinding: Binding<Int> {
        Binding(get: {
            let m = Calendar.current.component(.minute, from: due)
            return QuickTime.gridMinutes.contains(m) ? m : -1
        }, set: { m in
            due = at(hour: Calendar.current.component(.hour, from: due), minute: m, on: due)
        })
    }

    private func moveDay(to day: Date) {
        let cal = Calendar.current
        due = at(hour: cal.component(.hour, from: due), minute: cal.component(.minute, from: due), on: day)
    }

    private var summary: String {
        let cal = Calendar.current
        let day = cal.isDateInToday(due) ? "Today" : cal.isDateInTomorrow(due) ? "Tomorrow" : Theme.longDay(due)
        let past = due < Date() ? " — that time has passed, so it will nudge right away" : ""
        return "\(day) at \(Theme.time(due))\(past)"
    }

    private func heading(_ text: String) -> some View {
        Text(text.uppercased()).font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
            .padding(.top, 2)
    }
}
