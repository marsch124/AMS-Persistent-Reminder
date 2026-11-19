import Foundation

/// The words of "How it works" and "What's new". Every release adds its entry at the top of `news`
/// and changes the parts of `guide` that it touched.
enum Guide {
    struct Part: Identifiable {
        let title: String
        let text: [String]
        var id: String { title }
    }

    struct Release: Identifiable {
        let version: String
        let date: String
        let items: [String]
        var id: String { version }
    }

    static let guide: [Part] = [
        Part(title: "What this app is", text: [
            "AMS Reminder is for the things you must not forget. A normal reminder tells you once and is gone. This one keeps nudging you, again and again, until you tick it off.",
            "It is made for the iPhone, held upright. Everything stays on your iPhone.",
        ]),
        Part(title: "The Reminders screen", text: [
            "The big title says Reminders, and the date of today stands under it. Below that, a small green ring says how your day is going, for example “2 done · 4 to go today”. Tap it to open the list of what you ticked off.",
            "Your reminders stand in groups. “Waiting for you” (orange) holds the ones whose time has come: they are nudging you now. Then come Today (blue), Tomorrow and Later.",
            "At the bottom, the big orange button “New reminder” makes a new one.",
        ]),
        Part(title: "One row", text: [
            "On the left is a round circle. Tap it and the reminder is done. You feel a short, happy buzz.",
            "In the middle are the title and a small grey line. A waiting reminder says, for example, “Nudging every 5 min · 3rd nudge”. Other ones say how they repeat (“Every day”, “Every Thursday”) or “Nudge every 10 min”.",
            "On the right is the time.",
            "If the reminder has a shortcut, a small purple play mark stands just before the time.",
            "Tap a row to change it. Swipe it to the left to delete it. Swipe it to the right to tick it off.",
            "Press and hold a row with a play mark for half a second. You feel a short buzz, and its shortcut runs. A row without a shortcut does nothing when you press and hold it.",
        ]),
        Part(title: "Making and changing a reminder", text: [
            "Press “New reminder”. Type what it is. Then choose when.",
            "Quick buttons: In 10 min, In 1 hour, This evening (19:00) and Tomorrow 8:00. If it is already past 19:00, “This evening” becomes “Tomorrow evening”.",
            "Or choose it yourself: the day (Today, Tomorrow, or Pick a day with a calendar), the hour from a grid (06:00 to 21:00), and the minutes (:00, :15, :30, :45).",
            "Repeat: Never, Daily, Weekly or Monthly. Nudge me every: 1, 5, 10, 15, 30 or 60 minutes.",
            "Shortcut: under “Nudge me every” you can type the name of one Apple Shortcut. It is optional. Under the field a small line says “Press and hold the nudge or the row to run it.” Once you have typed a name, a small “Try it” button appears next to the field and runs the shortcut right away.",
            "Cancel leaves without saving. Save keeps it. When you change an existing reminder, a Delete button is there too.",
        ]),
        Part(title: "How the nudging works", text: [
            "At the time you chose, your iPhone shows a message, also on the lock screen. The first nudge comes at that exact time. After that it nudges again every few minutes, as often as you chose, until you tick it off. The message says, for example, “Since 08:00 · 3rd nudge”.",
            "On the row, the nudge count grows by itself while you look at it.",
        ]),
        Part(title: "Answering a nudge", text: [
            "Press and hold the message. Buttons appear: Done, In 10 minutes, In 1 hour and This evening. If the reminder has a shortcut, the first button is “Run: ” and the name of the shortcut, before all the others. Late in the day, “This evening” turns into “Tomorrow morning, 08:00”.",
            "Done ticks it off at once. You do not even have to open the app. The other buttons move the reminder to a later time, and the nudges start again from there.",
        ]),
        Part(title: "Running a shortcut", text: [
            "Every reminder can hold the name of one Apple Shortcut. Example: you have a shortcut that calls Andreas Bjurling. Make a reminder “Call Andreas”, and in the Shortcut field type its name: Call Andreas Bjurling.",
            "The name must be the same as in the Shortcuts app, with the same capitals and the same spaces. If it is not, the Shortcuts app says it cannot find it. Press “Try it” once to check.",
            "When the reminder nudges you, press and hold the message and press “Run: Call Andreas Bjurling”. AMS Reminder opens for a moment and hands over to the Shortcuts app, which runs the shortcut. Here it starts the phone call.",
            "Or open the app and press and hold the row on the Reminders screen. You feel a short buzz, and the shortcut runs.",
            "Running a shortcut does not tick the reminder off. It stays on the list and keeps nudging you until you tick it off. So tick it off after the call.",
        ]),
        Part(title: "Ticking off and repeating", text: [
            "A reminder with Repeat set to Never leaves the list when you tick it. A repeating one moves on to its next day, week or month, and starts nudging again then.",
            "A monthly reminder on the 31st goes to the last day of a short month, and then comes back to the 31st.",
        ]),
        Part(title: "A gentle limit", text: [
            "Your iPhone lets an app plan only about 60 nudges ahead. The app plans the earliest ones first, across all your reminders, and opens each time you use it to top them up.",
            "So if a reminder has been left for many hours, it may go quiet until you open the app again. Opening the app wakes it up. Ticking things off keeps this simple.",
        ]),
        Part(title: "Done", text: [
            "Settings › Done lists what you ticked off. At the top a green ring says, for example, “Nice work! 4 of 5 done today”.",
            "Below you find today and earlier days. Each line says “On time” or, for example, “After 3 nudges”.",
            "Ticked something by mistake? Swipe it to the left and press “Bring back”. It returns with the time it had.",
            "Lines older than 30 days are tidied away by themselves.",
        ]),
        Part(title: "Settings, and your data", text: [
            "Nudge me every: the choice that a new reminder starts with. At first it is 5 minutes. Each reminder can still have its own.",
            "Nudges allowed? shows whether your iPhone lets the app nudge you. When it does not, a button opens the iPhone’s settings, where you can switch it on. Without it, the app cannot nudge.",
            "How it works is this guide. What’s new lists every version. The version number stands at the bottom.",
            "Your reminders stay on this iPhone only. Nothing goes to iCloud. Once a day the app keeps a safety copy of your list, and keeps the last 7 days.",
        ]),
    ]

    static let news: [Release] = [
        Release(version: "0.2", date: "19 Nov 2026", items: [
            "New: every reminder can hold the name of one Apple Shortcut. It is optional. You can start the shortcut from the nudge or from the row, for example a shortcut that calls Andreas Bjurling.",
            "New: on the page New reminder / Change reminder there is a new heading SHORTCUT under “Nudge me every”, with a text field “Name of a shortcut (optional)”.",
            "New: under the field a small line with a play mark says “Press and hold the nudge or the row to run it.”",
            "New: once you have typed a name, a small “Try it” button next to the field runs the shortcut right away, so you can check the name.",
            "New: the name must be exactly the same as in the Shortcuts app, with the same capitals and spaces, for example “Call Andreas Bjurling”. If it is not, the Shortcuts app says it cannot find it.",
            "New: press and hold a nudge message and the first button is now “Run: ” and the name of the shortcut. It comes before Done, In 10 minutes, In 1 hour and This evening (or Tomorrow morning).",
            "New: pressing “Run” opens AMS Reminder for a moment. It hands over to the Shortcuts app, which runs the shortcut, for example it starts the phone call.",
            "New: the reminder stays on the list and keeps nudging you until you tick it off. Tick it off after the call.",
            "New: on the Reminders screen, a row with a shortcut shows a small purple play mark just before its time.",
            "New: press and hold a row for half a second. You feel a short buzz, and the shortcut runs.",
            "Unchanged: a tap on a row still opens the reminder to change it, and the swipes still tick it off or delete it. A row without a shortcut does nothing when you press and hold it.",
            "New: the name of the shortcut is kept with the reminder in your saved list. Lists saved by version 0.1 open without any trouble. The file format number stays 1.",
            "Changed: How it works now has the new part “Running a shortcut”, and the parts One row, Making and changing a reminder and Answering a nudge tell about the play mark, the Shortcut field and the Run button.",
        ]),
        Release(version: "0.1", date: "19 November 2026", items: [
            "New: the first version of AMS Reminder. Reminders that keep nudging you until you tick them off. For the iPhone, held upright.",
            "New: two tabs at the bottom with large hand-drawn icons: Reminders (an orange bell) and Settings (a gear).",
            "New: the Reminders screen with a big title, today’s date and a small green ring such as “2 done · 4 to go today”. Tap the ring to open Done.",
            "New: groups “Waiting for you” (orange), Today (blue), Tomorrow and Later.",
            "New: each row has a round circle to tick it off with a short happy buzz, the title, a small grey line (“Nudging every 5 min · 3rd nudge”, “Every day”, “Every Thursday” or “Nudge every 10 min”) and the time.",
            "New: tap a row to change it, swipe left to delete it, swipe right to tick it off.",
            "New: the big orange button “New reminder”, and a page with Cancel and Save.",
            "New: quick times In 10 min, In 1 hour, This evening (19:00, after 19:00 it becomes Tomorrow evening) and Tomorrow 8:00. Or choose the day (Today, Tomorrow, or a day from a calendar), the hour (06:00 to 21:00) and the minutes (:00, :15, :30, :45).",
            "New: Repeat: Never, Daily, Weekly or Monthly. A repeating reminder moves on to its next time when you tick it off.",
            "New: Nudge me every 1, 5, 10, 15, 30 or 60 minutes. The first nudge comes at the time itself.",
            "New: the nudge shows on the lock screen too, with the words “Since 08:00 · 3rd nudge”.",
            "New: press and hold a nudge for the buttons Done, In 10 minutes, In 1 hour and This evening (late in the day: Tomorrow morning, 08:00). Done ticks it off without opening the app.",
            "New: up to about 60 nudges are planned ahead, the earliest first across all reminders. Opening the app tops them up. A reminder left for many hours may go quiet until you open the app.",
            "New: Done in Settings, with a green ring “Nice work! 4 of 5 done today”, today and earlier days, and “On time” or “After 3 nudges” on each line. Swipe left to bring one back if you ticked it by mistake. Lines older than 30 days are tidied away.",
            "New: Settings has Nudge me every (what new reminders start with, 5 minutes at first) and Nudges allowed?, with a button to the iPhone’s settings when nudges are off.",
            "New: How it works, What’s new and the version number in Settings.",
            "New: your reminders stay on this iPhone only. A safety copy of the list is kept every day, for the last 7 days.",
        ]),
    ]
}
