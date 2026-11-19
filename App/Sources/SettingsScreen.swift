import SwiftUI
import UIKit
import UserNotifications
import AMSIcons
import ReminderCore

/// Settings: Done, the starting nudge, whether nudges are allowed, How it works, What's new, version.
struct SettingsScreen: View {
    @EnvironmentObject private var store: Store
    @AppStorage("defaultNudge") private var defaultNudge = 5
    @AppStorage(Nudger.pausedKey) private var pausedAll: Double = 0
    @State private var allowed: Bool?
    @State private var planned = ""

    var body: some View {
        let doneToday = store.list.doneToday(at: store.now).count
        NavigationStack {
            List {
                Section {
                } header: {
                    ScreenHeading(title: "Settings", colour: Theme.purple)
                }

                Section {
                    NavigationLink { DoneScreen() } label: {
                        HStack(spacing: 12) {
                            ControlMarkView(.ticked, size: 26, colour: Theme.green)
                            Text("Done")
                            Spacer()
                            Text("\(doneToday) today").foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityIdentifier("settings-done")
                } footer: {
                    Text("Everything you ticked off, and a way to bring one back.")
                }

                Section {
                    Picker(selection: $defaultNudge) {
                        ForEach(QuickTime.nudgeChoices, id: \.self) { Text("\($0) min").tag($0) }
                    } label: {
                        HStack(spacing: 12) {
                            AppMarkView(.bell, size: 24, colour: Theme.purple)
                            Text("Nudge me every")
                        }
                    }
                    // 0.4 (his ask): pause every nudge for a day, until a day, or switch them off.
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 12) {
                            ControlMarkView(.pause, size: 24, colour: Theme.purple)
                            Text("Pause all nudges")
                        }
                        PauseChoice(until: Binding(get: { pausedAll == 0 ? nil : Date(timeIntervalSinceReferenceDate: pausedAll) },
                                                   set: { pausedAll = $0?.timeIntervalSinceReferenceDate ?? 0; store.refresh() }),
                                    allowOff: true, id: "all-nudges")
                    }
                    if allowed == false {
                        HStack(spacing: 12) {
                            AppMarkView(.info, size: 24, colour: Theme.purple)
                            Text("Your iPhone does not allow nudges.").font(.subheadline)
                            Spacer()
                            Button("Turn on") {
                                if let url = URL(string: UIApplication.openNotificationSettingsURLString) { UIApplication.shared.open(url) }
                            }
                            .buttonStyle(.borderedProminent).tint(Theme.purple).controlSize(.small)
                            .accessibilityIdentifier("nudges-turn-on")
                        }
                    }
                } header: {
                    Text("Nudges").foregroundStyle(Theme.purple)
                } footer: {
                    Text("New reminders start with this. You can change it, and pause it, on each reminder.")
                }

                NudgeSettingsSection()

                Section {
                    NavigationLink { ShortcutPicker() } label: {
                        HStack(spacing: 12) {
                            ControlMarkView(.play, size: 24, colour: Theme.purple)
                            Text("Your shortcuts")
                            Spacer()
                            Text(store.shortcutNames.isEmpty ? "None yet" : "\(store.shortcutNames.count) loaded").foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityIdentifier("settings-shortcuts")
                } header: {
                    Text("Shortcuts").foregroundStyle(Theme.purple)
                } footer: {
                    Text("Load them once with the helper, then pick them on each reminder.")
                }

                SafetySettingsSection()

                Section {
                    NavigationLink { GuideView() } label: {
                        HStack(spacing: 12) { AppMarkView(.question, size: 24, colour: Theme.blue); Text("How it works") }
                    }
                    .accessibilityIdentifier("how-it-works")
                    NavigationLink { NewsView() } label: {
                        HStack(spacing: 12) { AppMarkView(.star, size: 24, colour: Theme.orange); Text("What's new") }
                    }
                    .accessibilityIdentifier("whats-new")
                } footer: {
                    Text("AMS Persistent Reminder \(Theme.version)")
                        .frame(maxWidth: .infinity).padding(.top, 14)
                        .accessibilityIdentifier("version")
                    if store.isTesting && store.nudgesOn {
                        Text(planned).font(.caption2).accessibilityIdentifier("planned")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .listSectionSpacing(.compact)
            .navigationTitle("Settings")
            .toolbar(.hidden, for: .navigationBar)
            .task(id: store.now) {
                _ = Nudger.allPausedUntil   // reads the 0.3.4 switch over, once
                allowed = (store.isTesting && !store.nudgesOn) ? true : await Nudger.isAllowed()
                if store.isTesting && store.nudgesOn {
                    let c = UNUserNotificationCenter.current()
                    let p = await c.pendingNotificationRequests()
                    let d = await c.deliveredNotifications()
                    let first = p.compactMap { ($0.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate() }.min()
                    planned = "planned \(p.count) delivered \(d.count) next \(first.map { Theme.time($0) + String(format: ":%02d", Calendar.current.component(.second, from: $0)) } ?? "none") now \(Theme.time(Date()))"
                }
            }
        }
    }
}

/// A main page's large heading in its part's colour (0.3.4, his ask; the system title cannot be coloured per page).
struct ScreenHeading: View {
    let title: String
    let colour: Color

    var body: some View {
        Text(title)
            .font(.largeTitle.bold())
            .foregroundStyle(colour)
            .lineLimit(1).minimumScaleFactor(0.7)
            .textCase(nil)
            .padding(.top, 6)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("heading")
    }
}

/// What you ticked off: a small celebration for today, then each day, newest first.
struct DoneScreen: View {
    @EnvironmentObject private var store: Store

    var body: some View {
        let now = store.now
        let counts = store.list.todayCounts(at: now)
        let total = counts.done + counts.toGo
        List {
            Section {
                HStack(spacing: 16) {
                    ZStack {
                        DoneRing(done: counts.done, total: total, lineWidth: 10)
                        Text("\(counts.done)/\(total)").font(.title3.bold()).monospacedDigit()
                    }
                    .frame(width: 92, height: 92)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(headline(counts)).font(.title3.bold()).foregroundStyle(Theme.green)
                        Text(subline(counts, now)).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)
                .accessibilityIdentifier("done-hero")
            }

            let days = store.list.doneByDay()
            if days.isEmpty {
                Section {
                    Text("Nothing ticked off yet. Your first tick is waiting!").foregroundStyle(.secondary)
                }
            }
            ForEach(days, id: \.day) { group in
                Section {
                    ForEach(group.entries) { e in
                        HStack(spacing: 11) {
                            ControlMarkView(.ticked, size: 26, colour: Theme.green)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(e.reminder.title)
                                Text(e.howText).font(.footnote).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(Theme.time(e.doneAt)).font(.callout.weight(.semibold)).monospacedDigit().foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("done-\(e.reminder.title)")
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button { withAnimation { store.bringBack(e.id) } } label: { Text("Bring back") }
                                .tint(Theme.orange)
                        }
                    }
                } header: {
                    Text(dayTitle(group.day, now)).foregroundStyle(Theme.green)
                }
            }

            if !days.isEmpty {
                Section {} footer: {
                    Text("Ticked something by mistake? Swipe it left to bring it back.")
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(.compact)
        .navigationTitle("Done")
    }

    private func headline(_ c: (done: Int, toGo: Int)) -> String {
        if c.done == 0 { return c.toGo == 0 ? "A free day" : "Let's begin" }
        return c.toGo == 0 ? "All done!" : "Nice work!"
    }

    private func subline(_ c: (done: Int, toGo: Int), _ now: Date) -> String {
        let total = c.done + c.toGo
        if total == 0 { return "Nothing planned for today." }
        if c.done == 0 { return "\(c.toGo) to go today. One tick at a time." }
        if c.toGo == 0 { return "Everything for today is ticked off." }
        if c.toGo == 1 {
            let s = store.list.sections(at: now)
            if let last = (s.waiting + s.today).first { return "\(c.done) of \(total) done today.\nOnly \(last.title) left." }
        }
        return "\(c.done) of \(total) done today.\n\(c.toGo) still to go."
    }

    private func dayTitle(_ day: Date, _ now: Date) -> String {
        let cal = Calendar.current
        if cal.isDate(day, inSameDayAs: now) { return "Ticked off today" }
        if let y = cal.date(byAdding: .day, value: -1, to: now), cal.isDate(day, inSameDayAs: y) { return "Yesterday" }
        return Theme.longDay(day)
    }
}

struct GuideView: View {
    var body: some View {
        List {
            ForEach(Guide.guide) { part in
                Section {
                    ForEach(part.text, id: \.self) { Text($0).font(.subheadline) }
                } header: {
                    Text(part.title).foregroundStyle(Theme.blue)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("How it works")
        .accessibilityIdentifier("guide")
    }
}

struct NewsView: View {
    var body: some View {
        List {
            ForEach(Guide.news) { release in
                Section {
                    ForEach(release.items, id: \.self) { Text($0).font(.subheadline) }
                } header: {
                    Text("\(release.version) · \(release.date)").foregroundStyle(Theme.orange)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("What's new")
        .accessibilityIdentifier("news")
    }
}
