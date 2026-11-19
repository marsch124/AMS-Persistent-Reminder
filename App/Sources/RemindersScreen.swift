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
    @AppStorage(Nudger.pausedKey) private var nudgesPaused = false

    var body: some View {
        let now = store.now
        let s = store.list.sections(at: now)
        let counts = store.list.todayCounts(at: now)
        NavigationStack {
            List {
                // 0.3.4 (his ask): the heading in the Reminders orange, no day-and-date line under it.
                Section {
                } header: {
                    ScreenHeading(title: "Persistent Reminders", colour: Theme.orange)
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
                } else if nudgesPaused {
                    Section {
                        HStack {
                            Text("Nudges are paused.").font(.subheadline)
                            Spacer()
                            Button("Turn on") { nudgesPaused = false; store.refresh() }
                                .buttonStyle(.borderedProminent).tint(Theme.purple).controlSize(.small)
                                .accessibilityIdentifier("unpause-nudges")
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
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .bottom) {
              HStack(spacing: 10) {
                // 0.3.4 (his ask): a round orange + at the bottom left instead of the wide bar.
                Button { editing = .new } label: {
                    ZStack {
                        Circle().fill(Theme.orangeFill)
                        ControlMarkView(.add, size: 26, colour: .white)
                    }
                    .frame(width: 56, height: 56)
                    .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("New reminder")
                .accessibilityIdentifier("new-reminder")
                Spacer()
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
                    .frame(width: 56, height: 56)
                    .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
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
                    // 0.3.3 (his ask): most of the row ticks it off; only the time and the small pencil on the right open it.
                    ReminderRow(reminder: r, now: store.now, colour: colour, waiting: mark,
                                onTick: { store.tick(r.id) },
                                onEdit: { editing = .edit(r) },
                                onRun: { runShortcut(r) })
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
            // Round the frame like the card itself and keep it just inside, so the card never cuts its corners
            // (0.3.2 used a smaller curve, and the card clipped the frame's corners — his screenshot, 19 Nov).
            base.overlay {
                RoundedRectangle(cornerRadius: Theme.frameRadius, style: .continuous)
                    .fill(Theme.row(c).opacity(0.10))
                    .overlay(RoundedRectangle(cornerRadius: Theme.frameRadius, style: .continuous).strokeBorder(Theme.row(c), lineWidth: 2.5))
                    .padding(3)
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

/// One reminder. Left (circle, title, small line — most of the row): tap = tick off. Right (time and a small
/// pencil): tap = change it. Press and hold anywhere = run its shortcut.
struct ReminderRow: View {
    let reminder: Reminder
    let now: Date
    let colour: Color
    let waiting: Bool
    let onTick: () -> Void
    let onEdit: () -> Void
    let onRun: () -> Void
    @State private var ticked = false

    var body: some View {
        HStack(spacing: 8) {
            if let c = reminder.shownColour {
                Capsule().fill(Theme.row(c)).frame(width: 4, height: 30)
                    .accessibilityIdentifier("colour-bar-\(reminder.title)")
            }
            tickArea
            editArea
        }
        .padding(.vertical, 1)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("row-\(reminder.title)")
    }

    private var tickArea: some View {
        HStack(spacing: 11) {
            Group {
                if ticked {
                    ControlMarkView(.ticked, size: 28, colour: Theme.green)
                } else {
                    ControlMarkView(.circle, size: 28, colour: waiting ? Theme.orange : reminder.shownColour.map(Theme.row) ?? Color(.tertiaryLabel))
                }
            }
            .frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 1) {
                Text(reminder.title).font(.body)
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
            Spacer(minLength: 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture(perform: tick)
        .onLongPressGesture(minimumDuration: 0.5, perform: onRun)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Tick off \(reminder.title)")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { tick() }
        .accessibilityIdentifier("tick-\(reminder.title)")
    }

    private var editArea: some View {
        HStack(spacing: 7) {
            VStack(alignment: .trailing, spacing: 2) {
                Text(timeText)
                    .font(.callout.weight(.semibold)).monospacedDigit()
                    .foregroundStyle(colour)
                    .multilineTextAlignment(.trailing)
                ControlMarkView(.edit, size: 13, colour: .secondary)
            }
        }
        .padding(.leading, 4)
        .contentShape(Rectangle())
        .onTapGesture(perform: onEdit)
        .onLongPressGesture(minimumDuration: 0.5, perform: onRun)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: "Change") { onEdit() }
        .accessibilityIdentifier("edit-\(reminder.title)")
    }

    private func tick() {
        guard !ticked else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(.spring(duration: 0.25)) { ticked = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            withAnimation { onTick() }
            ticked = false
        }
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
