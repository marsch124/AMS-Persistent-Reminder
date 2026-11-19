import Foundation
import UserNotifications
import UIKit
import ReminderCore

/// The nudges: plans the iPhone's messages, and answers their buttons (Done, In 10 minutes…).
enum Nudger {
    static let dayCategory = "nudge"
    static let lateCategory = "nudge-late"

    enum Action: String {
        case done, tenMinutes, oneHour, evening, tomorrowMorning
    }

    /// Asks once whether the app may nudge, and names the buttons on a nudge.
    static func setUp() {
        let c = UNUserNotificationCenter.current()
        let done = UNNotificationAction(identifier: Action.done.rawValue, title: "Done", options: [])
        let ten = UNNotificationAction(identifier: Action.tenMinutes.rawValue, title: "In 10 minutes", options: [])
        let hour = UNNotificationAction(identifier: Action.oneHour.rawValue, title: "In 1 hour", options: [])
        let evening = UNNotificationAction(identifier: Action.evening.rawValue, title: "This evening", options: [])
        let morning = UNNotificationAction(identifier: Action.tomorrowMorning.rawValue, title: "Tomorrow morning", options: [])
        c.setNotificationCategories([
            UNNotificationCategory(identifier: dayCategory, actions: [done, ten, hour, evening], intentIdentifiers: []),
            UNNotificationCategory(identifier: lateCategory, actions: [done, ten, hour, morning], intentIdentifiers: []),
        ])
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
        let now = Date()
        let cal = Calendar.current
        for p in NudgePlan.plan(reminders, from: now) {
            guard let r = reminders.first(where: { $0.id == p.reminderID }) else { continue }
            let content = UNMutableNotificationContent()
            content.title = r.title
            content.body = Words.nudgeBody(r, number: p.number)
            content.sound = .default
            content.threadIdentifier = r.id.uuidString
            content.userInfo = ["reminder": r.id.uuidString]
            content.categoryIdentifier = cal.component(.hour, from: p.date) >= QuickTime.eveningHour ? lateCategory : dayCategory
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
        case .tenMinutes?: store.snooze(reminder, to: QuickTime.inTenMinutes.date(from: now))
        case .oneHour?: store.snooze(reminder, to: QuickTime.inOneHour.date(from: now))
        case .evening?: store.snooze(reminder, to: QuickTime.evening.date(from: now))
        case .tomorrowMorning?: store.snooze(reminder, to: QuickTime.tomorrowMorning.date(from: now))
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

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard let text = response.notification.request.content.userInfo["reminder"] as? String,
              let id = UUID(uuidString: text) else { return }
        let action = response.actionIdentifier
        await MainActor.run { Nudger.answer(action, reminder: id) }
    }
}
