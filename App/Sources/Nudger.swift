import Foundation
import UserNotifications
import UIKit
import ReminderCore

/// The nudges: plans the iPhone's messages, and answers their buttons (Done, In 10 minutes…).
enum Nudger {
    static let dayCategory = "nudge"
    static let lateCategory = "nudge-late"

    enum Action: String {
        case done, tenMinutes, oneHour, evening, tomorrowMorning, shortcut
        // 0.5: the other "later" buttons (LaterChoice) and the button that opens a reminder's call / link.
        case fiveMinutes, fifteenMinutes, thirtyMinutes, twoHours, openAction
    }

    /// A shortcut a nudge's Run button asked for, opened once the app is in front.
    @MainActor static var pendingShortcut: URL?

    /// Asks once whether the app may nudge, and names the buttons on a nudge.
    static func setUp() { setCategories([]) }

    /// The buttons on a nudge: Done and the three "later" buttons he picked in Settings (0.5). A reminder with a
    /// shortcut gets "Run: <name>" first, one with a call or link gets "Call …" / "Open …" (both open the app, which hands over).
    /// After 19:00 "This evening" says "Tomorrow morning" (the "late" categories).
    static func setCategories(_ reminders: [Reminder]) {
        let c = UNUserNotificationCenter.current()
        let done = UNNotificationAction(identifier: Action.done.rawValue, title: "Done", options: [])
        let later = laterChoices.sorted { $0.order < $1.order }
        func laterButtons(late: Bool) -> [UNNotificationAction] {
            later.map { choice in
                if late && choice == .evening {
                    return UNNotificationAction(identifier: Action.tomorrowMorning.rawValue, title: "Tomorrow morning", options: [])
                }
                return UNNotificationAction(identifier: choice.rawValue, title: choice.buttonTitle, options: [])
            }
        }
        var all: Set<UNNotificationCategory> = [
            UNNotificationCategory(identifier: dayCategory, actions: [done] + laterButtons(late: false), intentIdentifiers: []),
            UNNotificationCategory(identifier: lateCategory, actions: [done] + laterButtons(late: true), intentIdentifiers: []),
        ]
        for r in reminders {
            var first: [UNNotificationAction] = []
            if let name = r.shortcut {
                first.append(UNNotificationAction(identifier: Action.shortcut.rawValue, title: "Run: \(name)", options: [.foreground]))
            }
            if let a = r.action, a.url != nil {
                first.append(UNNotificationAction(identifier: Action.openAction.rawValue, title: a.buttonTitle, options: [.foreground]))
            }
            guard !first.isEmpty else { continue }
            all.insert(UNNotificationCategory(identifier: category(dayCategory, r), actions: first + [done] + laterButtons(late: false), intentIdentifiers: []))
            all.insert(UNNotificationCategory(identifier: category(lateCategory, r), actions: first + [done] + laterButtons(late: true), intentIdentifiers: []))
        }
        c.setNotificationCategories(all)
    }

    /// "nudge" for a plain reminder, "nudge-sc-<id>" for one with a shortcut or a call / link button.
    static func category(_ base: String, _ r: Reminder) -> String {
        (r.shortcut == nil && r.action?.url == nil) ? base : "\(base)-sc-\(r.id.uuidString)"
    }

    // MARK: Settings kept on the phone (0.5)

    /// Quiet hours (pick 4): on/off and the two times, minutes after midnight.
    static let quietOnKey = "quietHoursOn"
    static let quietFromKey = "quietHoursFrom"
    static let quietToKey = "quietHoursTo"
    /// The three "later" buttons (pick 6), saved as `LaterChoice.save`.
    static let laterKey = "laterButtons"
    /// Weekend pause of all nudges (his ask): the pause starts at this time (seconds since 2001; 0 = it started already).
    static let pausedFromKey = "nudgesPausedFrom"

    /// The quiet window, or nil while quiet hours are off.
    static var quiet: QuietHours? {
        let d = UserDefaults.standard
        guard d.bool(forKey: quietOnKey) else { return nil }
        return QuietHours(from: d.object(forKey: quietFromKey) as? Int ?? QuietHours.defaultFrom,
                          to: d.object(forKey: quietToKey) as? Int ?? QuietHours.defaultTo)
    }

    static var laterChoices: [LaterChoice] { LaterChoice.parse(UserDefaults.standard.string(forKey: laterKey)) }

    /// When the pause of all nudges starts (the weekend), or nil = it started already.
    static var allPausedFrom: Date? {
        let t = UserDefaults.standard.double(forKey: pausedFromKey)
        return t == 0 ? nil : Date(timeIntervalSinceReferenceDate: t)
    }

    /// Hands the shortcut over to the Shortcuts app as soon as the app is in front.
    @MainActor
    static func openPendingShortcut() {
        guard let url = pendingShortcut, UIApplication.shared.applicationState == .active else { return }
        pendingShortcut = nil
        UIApplication.shared.open(url)
    }

    /// Settings → Nudges (0.4): every nudge paused until this time (seconds since 2001; 0 = not paused).
    static let pausedKey = "nudgesPausedUntil"

    /// The pause of all nudges, or nil. The 0.3.4 switch "off" reads as Off.
    static var allPausedUntil: Date? {
        let d = UserDefaults.standard
        if d.bool(forKey: "nudgesPaused") {
            d.set(Pause.forever.timeIntervalSinceReferenceDate, forKey: pausedKey)
            d.removeObject(forKey: "nudgesPaused")
        }
        let t = d.double(forKey: pausedKey)
        return t == 0 ? nil : Date(timeIntervalSinceReferenceDate: t)
    }

    static func askPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func isAllowed() async -> Bool {
        let s = await UNUserNotificationCenter.current().notificationSettings()
        return s.authorizationStatus == .authorized || s.authorizationStatus == .provisional
    }

    /// Replaces every planned nudge with the earliest ones from the list as it is now.
    static func plan(_ reminders: [Reminder]) {
        guard Store.shared.nudgesOn else { return }
        let c = UNUserNotificationCenter.current()
        c.removeAllPendingNotificationRequests()
        setCategories(reminders)
        let now = Date()
        let cal = Calendar.current
        for p in NudgePlan.plan(reminders, from: now, allPausedUntil: allPausedUntil, allPausedFrom: allPausedFrom, quiet: quiet) {
            guard let r = reminders.first(where: { $0.id == p.reminderID }) else { continue }
            let content = UNMutableNotificationContent()
            content.title = r.title
            content.body = Words.nudgeBody(r, number: p.number)
            // A louder nudge (pick 2) has its own strong sound; otherwise the reminder's own (pick 3) or the iPhone's.
            if p.louder { content.sound = UNNotificationSound(named: UNNotificationSoundName("louder.caf")) }
            else if let own = r.sound { content.sound = UNNotificationSound(named: UNNotificationSoundName(own.fileName)) }
            else { content.sound = .default }
            content.threadIdentifier = r.id.uuidString
            content.userInfo = ["reminder": r.id.uuidString]
            content.categoryIdentifier = category(cal.component(.hour, from: p.date) >= QuickTime.eveningHour ? lateCategory : dayCategory, r)
            let parts = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: max(p.date, now.addingTimeInterval(1)))
            let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
            c.add(UNNotificationRequest(identifier: "\(r.id.uuidString).\(p.number)", content: content, trigger: trigger))
        }
    }

    /// Takes a ticked-off reminder's nudges off the lock screen.
    static func clearDelivered(for id: UUID) {
        let c = UNUserNotificationCenter.current()
        c.getDeliveredNotifications { list in
            let ids = list.map(\.request.identifier).filter { $0.hasPrefix(id.uuidString) }
            c.removeDeliveredNotifications(withIdentifiers: ids)
        }
    }

    /// A button on a nudge was pressed (the app may have been woken in the background for it).
    @MainActor
    static func answer(_ actionID: String, reminder: UUID) {
        let store = Store.shared
        let now = Date()
        switch Action(rawValue: actionID) {
        case .done?:
            store.tick(reminder)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .tenMinutes?: store.snooze(reminder, to: LaterChoice.tenMinutes.date(from: now))
        case .fiveMinutes?: store.snooze(reminder, to: LaterChoice.fiveMinutes.date(from: now))
        case .fifteenMinutes?: store.snooze(reminder, to: LaterChoice.fifteenMinutes.date(from: now))
        case .thirtyMinutes?: store.snooze(reminder, to: LaterChoice.thirtyMinutes.date(from: now))
        case .oneHour?: store.snooze(reminder, to: LaterChoice.oneHour.date(from: now))
        case .twoHours?: store.snooze(reminder, to: LaterChoice.twoHours.date(from: now))
        case .evening?: store.snooze(reminder, to: LaterChoice.evening.date(from: now))
        case .tomorrowMorning?: store.snooze(reminder, to: QuickTime.tomorrowMorning.date(from: now))
        case .openAction?:
            // A call or a link: the app hands over as soon as it is in front (the same way as the shortcut).
            pendingShortcut = store.list.reminder(reminder)?.action?.url
            openPendingShortcut()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { openPendingShortcut() }
            return
        case .shortcut?:
            // Ticks it off when it is set to (0.3), then the app hands over to the Shortcuts app.
            pendingShortcut = store.runShortcut(reminder)
            openPendingShortcut()
            // Launched from a closed state, the app may not be in front yet; try again shortly.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { openPendingShortcut() }
            return
        case nil:
            // The message itself was tapped: the app opens on the list; top the nudges up.
            store.refresh()
        }
        if actionID != Action.done.rawValue, Action(rawValue: actionID) != nil {
            clearDelivered(for: reminder)
        }
    }
}

/// Receives the nudge buttons, and shows a nudge even while the app is open.
final class NudgeDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NudgeDelegate()

    // The completion-handler forms, answered on the main thread. The async forms (used up to 0.3) let iOS
    // finish the answer on a background thread, which UIKit stops with a crash (TestFlight crash reports
    // of 0.1 and 0.3, 19 Nov 2026: NudgeDelegate.userNotificationCenter(_:didReceive:) → abort).
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let text = response.notification.request.content.userInfo["reminder"] as? String
        let action = response.actionIdentifier
        DispatchQueue.main.async {
            if let text, let id = UUID(uuidString: text) {
                MainActor.assumeIsolated { Nudger.answer(action, reminder: id) }
            }
            completionHandler()
        }
    }
}
