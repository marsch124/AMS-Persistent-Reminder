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
    @AppStorage(Nudger.pausedKey) private var pausedAll: Double = 0
    @State private var pausing: Reminder?
    @State private var moving: Reminder?
    @StateObject private var voice = SpeechListener()
    @State private var noticeHide: Task<Void, Never>?

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
                } else if pausedAll != 0, Pause.isOn(Date(timeIntervalSinceReferenceDate: pausedAll), at: now) {
                    let until = Date(timeIntervalSinceReferenceDate: pausedAll)
                    Section {
                        HStack(spacing: 8) {
                            ControlMarkView(.pause, size: 18, colour: Theme.purple)
                            Text(until >= Pause.forever ? "Nudges are off." : "Nudges are paused \(Pause.text(until, at: now)).")
                                .font(.subheadline)
                                .accessibilityIdentifier("all-paused-line")
                            Spacer()
                            Button("Turn on") { pausedAll = 0; store.refresh() }
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
                group("At a place", s.atPlace, Theme.blue, place: true)
            }
            .listStyle(.insetGrouped)
            .listSectionSpacing(.compact)
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .bottom) {
              VStack(spacing: 8) {
              voicePanel
              if let offer = store.undoOffer {
                  UndoBar(offer: offer)
                      .id(offer.stamp)
                      .transition(.move(edge: .bottom).combined(with: .opacity))
              }
              HStack(spacing: 10) {
                // 0.3.4 (his ask): a round orange + at the bottom left instead of the wide bar.
                // 0.5: a short tap opens an empty New reminder page; press and hold = say the reminder.
                ZStack {
                    Circle().fill(voice.listening ? Theme.orange : Theme.orangeFill)
                    ControlMarkView(.add, size: 26, colour: .white)
                }
                .frame(width: 56, height: 56)
                .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                .scaleEffect(voice.listening ? 1.12 : 1)
                .animation(.spring(duration: 0.2), value: voice.listening)
                .contentShape(Circle())
                .onTapGesture { editing = .new }
                .gesture(
                    LongPressGesture(minimumDuration: 0.4)
                        .sequenced(before: DragGesture(minimumDistance: 0))
                        .onChanged { value in
                            if case .second(true, _) = value, !voice.listening {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                voice.start()
                            }
                        }
                        .onEnded { _ in letGo() }
                )
                .accessibilityElement(children: .ignore)
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel("New reminder")
                .accessibilityHint("Press and hold to speak a reminder")
                .accessibilityAction { editing = .new }
                .accessibilityIdentifier("new-reminder")
                Text("Hold to speak")
                    .font(.footnote).foregroundStyle(.secondary)
                    .accessibilityIdentifier("hold-to-speak-caption")
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
              }
              .padding(.horizontal, 16).padding(.bottom, 8)
              .animation(.default, value: store.undoOffer)
            }
            .sheet(item: $editing) { target in
                EditReminderView(target: target)
            }
            .confirmationDialog("Pause nudges for \(pausing?.title ?? "")", isPresented: Binding(get: { pausing != nil }, set: { if !$0 { pausing = nil } }), titleVisibility: .visible, presenting: pausing) { r in
                Button("Until tomorrow 08:00") { withAnimation { store.pause(r.id, until: Pause.tomorrow(after: Date())) } }
                Button("Pick a day…") { editing = .edit(r) }
                if r.isPaused(at: store.now) {
                    Button("Nudge again now") { withAnimation { store.pause(r.id, until: nil) } }
                }
            }
            .confirmationDialog("Move \(moving?.title ?? "") to", isPresented: Binding(get: { moving != nil }, set: { if !$0 { moving = nil } }), titleVisibility: .visible, presenting: moving) { r in
                let t = Date()
                Button("In 15 minutes") { moveTo(r, Calendar.current.dateInterval(of: .minute, for: t.addingTimeInterval(15 * 60))?.start ?? t.addingTimeInterval(900)) }
                Button("In 1 hour") { moveTo(r, QuickTime.inOneHour.date(from: t)) }
                Button(Calendar.current.component(.hour, from: t) >= QuickTime.eveningHour ? "Tomorrow evening" : "Tonight 19:00") { moveTo(r, QuickTime.evening.date(from: t)) }
                Button("Tomorrow 08:00") { moveTo(r, QuickTime.tomorrowMorning.date(from: t)) }
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
    private func group(_ title: String, _ items: [Reminder], _ colour: Color, mark: Bool = false, place: Bool = false) -> some View {
        if !items.isEmpty {
            Section {
                ForEach(items) { r in
                    // 0.3.3 (his ask): most of the row ticks it off; only the time and the small pencil on the right open it.
                    ReminderRow(reminder: r, now: store.now, allPausedUntil: pausedAll == 0 ? nil : Date(timeIntervalSinceReferenceDate: pausedAll), colour: colour, waiting: mark,
                                onTick: { store.tick(r.id) },
                                onEdit: { editing = .edit(r) },
                                onRun: { runShortcut(r) })
                    .listRowBackground(rowBackground(r, waiting: mark))
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button { tickWithJoy(r.id) } label: { Text("Done") }.tint(Theme.green)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) { store.delete(r.id) } label: { Text("Delete") }
                        Button { pausing = r } label: { Text("Pause") }.tint(Theme.purple)
                        Button { moving = r } label: { Text("Later") }.tint(Theme.blue)
                        // Skip is grey, so blue keeps meaning "Later" only (one colour, one meaning).
                        if r.repeats != .never {
                            Button { withAnimation { store.skip(r.id) } } label: { Text("Skip") }.tint(.gray)
                        }
                    }
                }
            } header: {
                HStack(spacing: 5) {
                    if mark { AppMarkView(.bell, size: 14) }
                    if place { AppMarkView(.map, size: 14, colour: Theme.blue) }
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

    private func moveTo(_ r: Reminder, _ date: Date) {
        withAnimation { store.snooze(r.id, to: date) }
    }

    /// The panel above the bottom buttons: what is heard while the + is held, or why nothing happened.
    @ViewBuilder
    private var voicePanel: some View {
        if voice.listening {
            HStack(alignment: .top, spacing: 10) {
                AppMarkView(.bell, size: 22, colour: Theme.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text(voice.heard.isEmpty ? "Listening…" : voice.heard)
                        .font(.body.weight(.medium))
                        .accessibilityIdentifier("voice-heard")
                    Text("Listening… let go when you're done")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.orange, lineWidth: 1.5))
            .accessibilityIdentifier("voice-panel")
        } else if let n = voice.notice {
            HStack(spacing: 10) {
                Text(n == .didntCatch ? "I didn't catch that" : "Speaking needs the microphone and speech recognition to be on.")
                    .font(.subheadline)
                    .accessibilityIdentifier("voice-notice")
                Spacer(minLength: 0)
                if n == .needsPermission {
                    Button("Turn on") { openAppSettings() }
                        .buttonStyle(.borderedProminent).tint(Theme.purple).controlSize(.small)
                        .accessibilityIdentifier("voice-turn-on")
                }
            }
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        }
    }

    /// The + was let go: the words become a New reminder page, or a short line says nothing was heard.
    private func letGo() {
        guard voice.listening else { return }
        Task {
            let said = await voice.finish()
            if voice.notice == .needsPermission { hideNoticeLater(never: true); return }
            guard !said.isEmpty else { voice.notice = .didntCatch; hideNoticeLater(); return }
            let parsed = Spoken.parse(said, now: Date())
            editing = .spoken(title: parsed.title, due: parsed.due)
        }
    }

    private func hideNoticeLater(never: Bool = false) {
        noticeHide?.cancel()
        guard !never else { return }
        noticeHide = Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if !Task.isCancelled { voice.notice = nil }
        }
    }

    private func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
    }

    private func tickWithJoy(_ id: UUID) {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation { store.tick(id) }
    }

    /// Press and hold a row: its shortcut runs, and it is ticked off when it is set to (rows without one stay still).
    private func runShortcut(_ r: Reminder) {
        if r.shortcutURL == nil {
            // 0.5: no shortcut — open its call or link instead.
            if let url = r.action?.url { UIApplication.shared.open(url) }
            return
        }
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
    let allPausedUntil: Date?
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

    private var paused: Bool { reminder.isPaused(at: now) || (waiting && Pause.isOn(allPausedUntil, at: now)) }

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
                    if paused { ControlMarkView(.pause, size: 12, colour: Theme.purple) }
                    else if waiting { AppMarkView(.bell, size: 12) }
                    else if reminder.isAtPlaceWaiting { AppMarkView(.map, size: 12, colour: Theme.blue) }
                    else if reminder.repeats != .never {
                        AppMarkView(.repeat, size: 12, colour: reminder.shownColour.map(Theme.row) ?? .secondary)
                    }
                    Text(Words.rowLine(reminder, at: now, allPausedUntil: allPausedUntil))
                }
                .font(.footnote)
                .foregroundStyle(waiting && !paused ? Theme.orange : Color.secondary)
                if let note = reminder.note, !note.isEmpty {
                    Text(note).font(.footnote).foregroundStyle(.secondary).lineLimit(1).truncationMode(.tail)
                        .accessibilityIdentifier("note-\(reminder.title)")
                }
            }
            Spacer(minLength: 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture(perform: tick)
        .onLongPressGesture(minimumDuration: 0.5, perform: onRun)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Tick off \(reminder.title)")
        .accessibilityValue(Words.rowLine(reminder, at: now, allPausedUntil: allPausedUntil))
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
        if reminder.isAtPlaceWaiting { return "" }
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
    /// 0.5: a new reminder filled from what was said (hold the round +); due nil = the usual next full hour.
    case spoken(title: String, due: Date?)
    var id: String {
        switch self {
        case .new: return "new"
        case .spoken: return "spoken"
        case .edit(let r): return r.id.uuidString
        }
    }
}

/// 0.5 (pick 27): "Ticked off: …" with Undo, just above the round buttons; goes by itself after 5 seconds.
struct UndoBar: View {
    @EnvironmentObject private var store: Store
    let offer: Store.UndoOffer

    var body: some View {
        HStack(spacing: 8) {
            ControlMarkView(.ticked, size: 22, colour: Theme.green)
            Text("Ticked off: \(offer.title)").font(.subheadline).lineLimit(1)
            Spacer(minLength: 4)
            Button { store.undoTick(offer) } label: {
                Text("Undo").font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 6)
                    .background(Theme.dynamic(0x24985D, 0x1F8A52), in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("undo")
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("undo-bar")
        .task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            if store.undoOffer == offer { store.undoOffer = nil }
        }
    }
}
