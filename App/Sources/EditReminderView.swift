import SwiftUI
import UIKit
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
    @State private var shortcut = ""
    @State private var tickWhenRun = true
    @State private var colour: RowColour?
    @State private var pausedUntil: Date?
    @State private var pausedFrom: Date?
    // 0.5 fields (each part's own file in Parts/ shows them).
    @State private var note = ""
    @State private var action: TapAction?
    @State private var sound: NudgeSound?
    @State private var louder = true
    @State private var stopAt: Int?
    @State private var every = 2
    @State private var weekdays: [Int] = []
    @State private var afterDone = false
    @State private var place: Place?
    @State private var noSpot = false
    @State private var filled = false
    @State private var picking = false
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

                    if place == nil {
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
                    }

                    PlaceSection(place: $place)

                    heading("Repeat")
                    RepeatSection(repeats: $repeats, every: $every, weekdays: $weekdays, afterDone: $afterDone, due: due)
                    if repeats != .never { colourDots }

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
                    NudgeMoreSection(sound: $sound, louder: $louder, stopAt: $stopAt)

                    heading("Pause nudges")
                    if filled { PauseChoice(until: $pausedUntil, from: $pausedFrom, allowOff: false) }

                    heading("Shortcut")
                    HStack(spacing: 8) {
                        TextField("Name of a shortcut (optional)", text: $shortcut)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .submitLabel(.done)
                            .accessibilityIdentifier("shortcut-field")
                        if let url = Reminder.shortcutURL(for: shortcut) {
                            Button("Try it") { UIApplication.shared.open(url) }
                                .buttonStyle(.bordered).tint(Theme.purple).controlSize(.small)
                                .accessibilityIdentifier("try-shortcut")
                        }
                        Button("Pick") { picking = true }
                            .buttonStyle(.borderedProminent).tint(Theme.purpleFill).controlSize(.small)
                            .accessibilityIdentifier("pick-shortcut")
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                    if Reminder.cleanShortcut(shortcut) != nil {
                        Toggle("Tick off when it runs", isOn: $tickWhenRun)
                            .tint(Theme.green)
                            .padding(.horizontal, 14).padding(.vertical, 6)
                            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                            .accessibilityIdentifier("tick-when-run")
                    }
                    HStack(spacing: 6) {
                        ControlMarkView(.play, size: 14, colour: Theme.purple)
                        Text("Press and hold the nudge or the row to run it.")
                    }
                    .font(.footnote).foregroundStyle(.secondary)

                    NoteLinkSection(note: $note, action: $action)

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
            .scrollDismissesKeyboard(.interactively)
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
            .sheet(isPresented: $picking) {
                NavigationStack {
                    ShortcutPicker { shortcut = $0 }
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") { picking = false }.accessibilityIdentifier("picker-cancel")
                            }
                        }
                }
            }
            .alert("Pick the place first", isPresented: $noSpot) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Tap “Use where I am now” while you are at the place, or switch “Start at a place” off.")
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

    private var isNew: Bool { if case .edit = target { return false } else { return true } }

    private func fill() {
        switch target {
        case .new:
            nudge = defaultNudge
            // The next full hour.
            let cal = Calendar.current
            let next = cal.date(byAdding: .hour, value: 1, to: Date())!
            due = at(hour: cal.component(.hour, from: next), minute: 0, on: next)
            titleFocused = true
        case .spoken(let said, let when):
            nudge = defaultNudge
            title = said
            let cal = Calendar.current
            let next = cal.date(byAdding: .hour, value: 1, to: Date())!
            due = when ?? at(hour: cal.component(.hour, from: next), minute: 0, on: next)
        case .edit(let r):
            title = r.title
            // A place reminder still waiting has no time: the When part starts from the next full hour.
            if r.due >= Place.notYet {
                let next = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
                due = at(hour: Calendar.current.component(.hour, from: next), minute: 0, on: next)
            } else { due = r.due }
            repeats = r.repeats
            nudge = r.nudgeMinutes
            shortcut = r.shortcut ?? ""
            tickWhenRun = r.tickWhenRun
            colour = r.colour
            pausedUntil = r.pausedUntil
            pausedFrom = r.pausedFrom
            note = r.note ?? ""
            action = r.action
            sound = r.sound
            louder = r.louder
            stopAt = r.stopAt
            every = r.every
            weekdays = r.weekdays
            afterDone = r.afterDone
            place = r.place
        }
        filled = true
        pickingDay = dayChoice == .other
    }

    private func save() {
        let text = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { titleFocused = true; return }
        // A place needs a spot: tell him instead of watching the middle of the sea.
        if let p = place, !p.hasSpot { noSpot = true; return }
        // A time that has already passed nudges right away (in a few seconds).
        var due = self.due < Date() ? Date().addingTimeInterval(5) : self.due
        // A place reminder waits for its place; an already reached one (place unchanged) keeps its time.
        if let p = place {
            if case .edit(let old) = target, old.place == p { due = old.due } else { due = Place.notYet }
            PlaceWatcher.shared.askForAlways()
        }
        switch target {
        case .new, .spoken:
            store.add(Reminder(title: text, due: due, repeats: repeats, nudgeMinutes: nudge, shortcut: shortcut, tickWhenRun: tickWhenRun, colour: colour, pausedUntil: pausedUntil,
                               note: note, action: action, sound: sound, louder: louder, stopAt: stopAt, every: every, weekdays: weekdays, afterDone: afterDone, place: place).pausing(from: pausedFrom))
        case .edit(var r):
            r.title = text
            r.due = due
            r.repeats = repeats
            r.nudgeMinutes = nudge
            r.shortcut = Reminder.cleanShortcut(shortcut)
            r.tickWhenRun = tickWhenRun
            r.colour = colour
            r.pausedUntil = pausedUntil
            r.pausedFrom = pausedUntil == nil ? nil : pausedFrom
            r.note = Reminder.cleanShortcut(note)
            r.action = action
            r.sound = sound
            r.louder = louder
            r.stopAt = stopAt
            r.every = max(1, every)
            r.weekdays = weekdays
            r.afterDone = afterDone
            r.place = place
            store.update(r)
        }
        dismiss()
    }

    /// A repeating reminder's colour: none, or one of eight.
    private var colourDots: some View {
        HStack(spacing: 0) {
            dot(nil)
            ForEach(RowColour.allCases, id: \.self) { dot($0) }
        }
        .padding(.horizontal, 6).padding(.vertical, 8)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private func dot(_ c: RowColour?) -> some View {
        let on = colour == c
        return Button { colour = c } label: {
            ZStack {
                if let c {
                    Circle().fill(Theme.row(c)).frame(width: 24, height: 24)
                } else {
                    Circle().stroke(Color(.tertiaryLabel), lineWidth: 1.9).frame(width: 22, height: 22)
                    Rectangle().fill(Color(.tertiaryLabel)).frame(width: 1.9, height: 22).rotationEffect(.degrees(45))
                }
                if on { Circle().stroke(Color.primary, lineWidth: 2).frame(width: 32, height: 32) }
            }
            .frame(maxWidth: .infinity, minHeight: 34)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(c?.title ?? "No colour")
        .accessibilityAddTraits(on ? .isSelected : [])
        .accessibilityIdentifier("colour-\(c?.rawValue ?? "none")")
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
