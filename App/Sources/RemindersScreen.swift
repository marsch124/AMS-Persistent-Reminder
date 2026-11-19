import SwiftUI
import UIKit
import AMSIcons
import ReminderCore

/// The main screen: what is waiting, today, tomorrow and later, and the New reminder button.
struct RemindersScreen: View {
    @EnvironmentObject private var store: Store
    @State private var editing: EditTarget?
    @State private var showDone = false
    @State private var nudgesOff = false

    var body: some View {
        let now = store.now
        let s = store.list.sections(at: now)
        let counts = store.list.todayCounts(at: now)
        NavigationStack {
            List {
                Section {
                } header: {
                    Text(Theme.longDay(now)).font(.subheadline).foregroundStyle(.secondary).textCase(nil)
                }

                if nudgesOff {
                    Section {
                        HStack {
                            Text("Nudges are off, so nothing can remind you.").font(.subheadline)
                            Spacer()
                            Button("Turn on") { openNotificationSettings() }
                                .buttonStyle(.borderedProminent).tint(Theme.purple).controlSize(.small)
                        }
                    }
                }

                if s.isEmpty {
                    Section {
                        VStack(spacing: 10) {
                            AppMarkView(.bell, size: 44, colour: Theme.orange)
                            Text("All clear").font(.title3.bold())
                            Text("Nothing is waiting for you. Add a reminder and it will keep nudging you until it's done.")
                                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 24)
                        .listRowBackground(Color.clear)
                        .accessibilityIdentifier("all-clear")
                    }
                }

                group("Waiting for you", s.waiting, Theme.orange, mark: true)
                group("Today", s.today, Theme.blue)
                group("Tomorrow", s.tomorrow, .secondary)
                group("Later", s.later, .secondary)
            }
            .listStyle(.insetGrouped)
            .listSectionSpacing(.compact)
            .navigationTitle("Reminders")
            .safeAreaInset(edge: .bottom) {
              HStack(spacing: 10) {
                Button { editing = .new } label: {
                    HStack(spacing: 8) {
                        ControlMarkView(.add, size: 20)
                        Text("New reminder").font(.headline)
                    }
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .foregroundStyle(.white)
                    .background(Theme.orangeFill, in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("new-reminder")
                // Done is a small round button at the bottom right (his pick, 0.3): the green ring of today
                // with the number done inside. It opens the Done list.
                Button { showDone = true } label: {
                    ZStack {
                        Circle().fill(Color(.secondarySystemGroupedBackground))
                        DoneRing(done: counts.done, total: counts.done + counts.toGo, lineWidth: 4)
                            .padding(5)
                        Text("\(counts.done)").font(.subheadline.weight(.bold)).monospacedDigit()
                            .foregroundStyle(Theme.green)
                    }
                    .frame(width: 50, height: 50)
                    .shadow(color: .black.opacity(0.08), radius: 3, y: 1)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Done: \(counts.done) done, \(counts.toGo) to go today")
                .accessibilityIdentifier("done-button")
              }
              .padding(.horizontal, 16).padding(.bottom, 8)
            }
            .sheet(item: $editing) { target in
                EditReminderView(target: target)
            }
            .sheet(isPresented: $showDone) {
                NavigationStack {
                    DoneScreen()
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") { showDone = false }.bold().accessibilityIdentifier("close-done")
                            }
                        }
                }
            }
            .task(id: store.now) { nudgesOff = store.isTesting ? false : !(await Nudger.isAllowed()) }
        }
    }

    @ViewBuilder
    private func group(_ title: String, _ items: [Reminder], _ colour: Color, mark: Bool = false) -> some View {
        if !items.isEmpty {
            Section {
                ForEach(items) { r in
                    ReminderRow(reminder: r, now: store.now, colour: colour, waiting: mark) {
                        store.tick(r.id)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { editing = .edit(r) }
                    .onLongPressGesture(minimumDuration: 0.5) { runShortcut(r) }
                    .listRowBackground(rowBackground(r, waiting: mark))
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button { tickWithJoy(r.id) } label: { Text("Done") }.tint(Theme.green)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) { store.delete(r.id) } label: { Text("Delete") }
                    }
                }
            } header: {
                HStack(spacing: 5) {
                    if mark { AppMarkView(.bell, size: 14) }
                    Text(title)
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(colour)
            }
        }
    }

    /// A coloured reminder gets a frame in its colour and a faint tint inside (0.3.2, his ask: the bar alone was too subtle).
    @ViewBuilder
    private func rowBackground(_ r: Reminder, waiting: Bool) -> some View {
        let base = waiting ? Theme.waitingRow : Color(.secondarySystemGroupedBackground)
        if let c = r.shownColour {
            base.overlay {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Theme.row(c).opacity(0.10))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.row(c), lineWidth: 2))
                    .padding(2)
            }
            .accessibilityIdentifier("colour-frame-\(r.title)")
        } else {
            base
        }
    }

    private func tickWithJoy(_ id: UUID) {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation { store.tick(id) }
    }

    /// Press and hold a row: its shortcut runs, and it is ticked off when it is set to (rows without one stay still).
    private func runShortcut(_ r: Reminder) {
        var url: URL?
        withAnimation { url = store.runShortcut(r.id) }
        if let url { UIApplication.shared.open(url) }
    }

    private func openNotificationSettings() {
        if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

/// One reminder: tick circle, title, small line, time.
struct ReminderRow: View {
    let reminder: Reminder
    let now: Date
    let colour: Color
    let waiting: Bool
    let onTick: () -> Void
    @State private var ticked = false

    var body: some View {
        HStack(spacing: 11) {
            if let c = reminder.shownColour {
                Capsule().fill(Theme.row(c)).frame(width: 4, height: 30)
                    .padding(.trailing, -4)
                    .accessibilityIdentifier("colour-bar-\(reminder.title)")
            }
            Button {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                withAnimation(.spring(duration: 0.25)) { ticked = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    withAnimation { onTick() }
                    ticked = false
                }
            } label: {
                Group {
                    if ticked {
                        ControlMarkView(.ticked, size: 28, colour: Theme.green)
                    } else {
                        ControlMarkView(.circle, size: 28, colour: waiting ? Theme.orange : reminder.shownColour.map(Theme.row) ?? Color(.tertiaryLabel))
                    }
                }
                .frame(width: 34, height: 34)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Tick off \(reminder.title)")
            .accessibilityIdentifier("tick-\(reminder.title)")

            VStack(alignment: .leading, spacing: 1) {
                Text(reminder.title).font(.body)
                    .strikethrough(ticked, color: .secondary)
                HStack(spacing: 4) {
                    if waiting { AppMarkView(.bell, size: 12) }
                    else if reminder.repeats != .never {
                        AppMarkView(.repeat, size: 12, colour: reminder.shownColour.map(Theme.row) ?? .secondary)
                    }
                    Text(Words.rowLine(reminder, at: now))
                }
                .font(.footnote)
                .foregroundStyle(waiting ? Theme.orange : Color.secondary)
            }
            Spacer(minLength: 6)
            if reminder.shortcut != nil {
                ControlMarkView(.play, size: 14, colour: Theme.purple)
                    .accessibilityLabel("Press and hold to run \(reminder.shortcut ?? "")")
                    .accessibilityIdentifier("shortcut-mark-\(reminder.title)")
            }
            Text(timeText)
                .font(.callout.weight(.semibold)).monospacedDigit()
                .foregroundStyle(colour)
        }
        .padding(.vertical, 1)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("row-\(reminder.title)")
    }

    private var timeText: String {
        let cal = Calendar.current
        let tomorrow = cal.date(byAdding: .day, value: 1, to: now)!
        let yesterday = cal.date(byAdding: .day, value: -1, to: now)!
        if cal.isDate(reminder.due, inSameDayAs: now) || cal.isDate(reminder.due, inSameDayAs: tomorrow) {
            return Theme.time(reminder.due)
        }
        if cal.isDate(reminder.due, inSameDayAs: yesterday) { return "Yesterday \(Theme.time(reminder.due))" }
        return "\(Theme.shortDay(reminder.due)) · \(Theme.time(reminder.due))"
    }
}

enum EditTarget: Identifiable {
    case new
    case edit(Reminder)
    var id: String {
        switch self {
        case .new: return "new"
        case .edit(let r): return r.id.uuidString
        }
    }
}
