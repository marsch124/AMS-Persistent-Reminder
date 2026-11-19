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
                    Button { showDone = true } label: {
                        HStack(spacing: 10) {
                            DoneRing(done: counts.done, total: counts.done + counts.toGo, lineWidth: 4)
                                .frame(width: 24, height: 24)
                            (Text("\(counts.done) done").bold() + Text(" · \(counts.toGo) to go today"))
                                .font(.subheadline)
                            Spacer()
                            ControlMarkView(.chevron, size: 14, colour: .secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("today-pill")
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
                .padding(.horizontal, 16).padding(.bottom, 8)
                .accessibilityIdentifier("new-reminder")
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
                    .listRowBackground(mark ? Theme.waitingRow : Color(.secondarySystemGroupedBackground))
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

    private func tickWithJoy(_ id: UUID) {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation { store.tick(id) }
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
                        ControlMarkView(.circle, size: 28, colour: waiting ? Theme.orange : Color(.tertiaryLabel))
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
                    else if reminder.repeats != .never { AppMarkView(.repeat, size: 12) }
                    Text(Words.rowLine(reminder, at: now))
                }
                .font(.footnote)
                .foregroundStyle(waiting ? Theme.orange : Color.secondary)
            }
            Spacer(minLength: 6)
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
