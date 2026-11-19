import Foundation
import SwiftUI
import UIKit
import ReminderCore

/// Keeps the list, reads and writes it on this iPhone, and tells the nudges when anything changes.
@MainActor
final class Store: ObservableObject {
    static let shared = Store()

    @Published private(set) var list = ReminderList()
    /// The clock the screens use; moves on every 10 seconds while the app is open.
    @Published var now = Date()

    /// UI tests and pictures: a list in memory only, never saved, no messages planned.
    let isTesting: Bool
    /// Plans real nudges: always in use, and in the one UI test that checks a nudge pops up.
    let nudgesOn: Bool
    private let fileURL: URL
    private let backupFolder: URL

    init() {
        let args = ProcessInfo.processInfo.arguments
        isTesting = args.contains("-uiTesting")
        nudgesOn = !isTesting || args.contains("-realNudges")
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AMSPersistentReminder", isDirectory: true)
        fileURL = base.appendingPathComponent("reminders.json")
        backupFolder = base.appendingPathComponent("Safety copies", isDirectory: true)
        if isTesting {
            list = args.contains("-sample") ? Sample.list(now: now) : ReminderList()
            shortcutNames = args.contains("-sample") ? ["Call Andreas Bjurling", "Coffee timer", "Play morning music", "Weather today"] : []
        } else {
            try? FileManager.default.createDirectory(at: backupFolder, withIntermediateDirectories: true)
            load()
        }
    }

    // MARK: Changes — each one saves and re-plans the nudges

    func add(_ r: Reminder) { change { $0.add(r) } }
    func update(_ r: Reminder) { change { $0.update(r) } }
    func delete(_ id: UUID) { change { $0.delete(id) } }
    func snooze(_ id: UUID, to date: Date) { change { $0.snooze(id, to: date) } }
    func bringBack(_ entryID: UUID) { change { $0.bringBack(entryID) } }

    /// Its shortcut runs: ticks it off when it is set to (with the happy buzz), and returns the link
    /// for the Shortcuts app.
    func runShortcut(_ id: UUID) -> URL? {
        guard let r = list.reminder(id), r.shortcutURL != nil else { return nil }
        var url: URL?
        let t = Date()
        change { url = $0.runShortcut(id, at: t) }
        if r.ticksWhenRun {
            Nudger.clearDelivered(for: id)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } else {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        return url
    }

    // MARK: His shortcuts (sent back by the helper shortcut, kept for the picker)

    @Published private(set) var shortcutNames: [String] = UserDefaults.standard.stringArray(forKey: "shortcutNames") ?? []

    /// A link opened the app: the helper's list of shortcut names.
    func open(_ url: URL) {
        guard let names = ShortcutNames.read(url) else { return }
        shortcutNames = names
        if !isTesting { UserDefaults.standard.set(names, forKey: "shortcutNames") }
    }

    func tick(_ id: UUID) {
        let t = Date()
        change { $0.tick(id, at: t) }
        Nudger.clearDelivered(for: id)
    }

    private func change(_ edit: (inout ReminderList) -> Void) {
        now = Date()
        var copy = list
        edit(&copy)
        list = copy
        save()
        Nudger.plan(list.reminders)
    }

    /// Called when the app comes to the front: the clock, the tidy-up and the nudge plan.
    func refresh() {
        now = Date()
        if !isTesting {
            load()
            var copy = list
            copy.forgetDone(olderThan: 30, at: now)
            if copy != list { list = copy; save() }
        }
        Nudger.plan(list.reminders)
    }

    // MARK: The file

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        if let read = try? JSONDecoder.reminders.decode(ReminderList.self, from: data) {
            list = read
        } else {
            // Never overwrite a file we could not read: put it aside first.
            let aside = fileURL.deletingLastPathComponent()
                .appendingPathComponent("reminders-unreadable-\(Int(Date().timeIntervalSince1970)).json")
            try? FileManager.default.copyItem(at: fileURL, to: aside)
        }
    }

    private func save() {
        guard !isTesting else { return }
        guard let data = try? JSONEncoder.reminders.encode(list) else { return }
        try? data.write(to: fileURL, options: .atomic)
        keepSafetyCopy(data)
    }

    /// One safety copy a day, the last 7 days kept.
    private func keepSafetyCopy(_ data: Data) {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        let today = backupFolder.appendingPathComponent("reminders \(f.string(from: Date())).json")
        try? data.write(to: today, options: .atomic)
        let copies = (try? FileManager.default.contentsOfDirectory(at: backupFolder, includingPropertiesForKeys: nil)) ?? []
        let old = copies.filter { $0.lastPathComponent.hasPrefix("reminders ") }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }.dropFirst(7)
        old.forEach { try? FileManager.default.removeItem(at: $0) }
    }
}

extension JSONEncoder {
    static let reminders: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()
}

extension JSONDecoder {
    static let reminders: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}

/// The made-up list for UI tests and pictures (never his real data).
enum Sample {
    static func list(now: Date) -> ReminderList {
        let cal = Calendar.current
        let tomorrow = cal.date(byAdding: .day, value: 1, to: now)!
        var l = ReminderList(reminders: [
            Reminder(title: "Take vitamins", due: now.addingTimeInterval(-12 * 60), repeats: .daily, nudgeMinutes: 5, colour: .green),
            Reminder(title: "Call the dentist", due: now.addingTimeInterval(2 * 3600), nudgeMinutes: 10, shortcut: "Call dentist"),
            Reminder(title: "Water the plants", due: now.addingTimeInterval(5 * 3600), repeats: .weekly, nudgeMinutes: 15, colour: .teal),
            Reminder(title: "Pay the parking", due: at(hour: 9, minute: 0, on: tomorrow), nudgeMinutes: 15),
        ])
        l.done = [
            DoneEntry(reminder: Reminder(title: "Book the car service", due: now.addingTimeInterval(-3 * 3600)), doneAt: now.addingTimeInterval(-3 * 3600 + 60), nudges: 1),
            DoneEntry(reminder: Reminder(title: "Morning walk", due: now.addingTimeInterval(-2 * 3600)), doneAt: now.addingTimeInterval(-2 * 3600 + 11 * 60), nudges: 3),
        ]
        return l
    }
}
