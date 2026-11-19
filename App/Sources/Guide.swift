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
            "The big orange title says Persistent Reminders. The tab at the bottom still says Reminders.",
            "Your reminders stand in groups. “Waiting for you” (orange) holds the ones whose time has come: they are nudging you now. Then come Today (blue), Tomorrow and Later.",
            "At the bottom left, the round orange button with a white plus makes a new reminder. At the bottom right, the round green button shows the green ring of today with the number you have done inside it. Tap it to open the list of what you ticked off.",
            "If you paused all nudges in Settings, a line “Nudges are paused until …” (or “Nudges are off.”) with a “Turn on” button stands at the top of the list.",
        ]),
        Part(title: "One row", text: [
            "Tap anywhere on the circle, the title or the small grey line, which is most of the row, and the reminder is done. You feel a short, happy buzz, and the circle turns into a green tick. The title is not struck through. Then the reminder leaves the list.",
            "In the middle are the title and a small grey line. A waiting reminder says, for example, “Nudging every 5 min · 3rd nudge”. Other ones say how they repeat (“Every day”, “Every Thursday”) or “Nudge every 10 min”. A paused reminder says “Paused until tomorrow 08:00” (or, for example, “Paused until Mon 23 Nov, 08:00”), with a small purple pause mark, two short upright lines, in place of the bell or the repeat mark. Ticking it off works as always.",
            "On the right is the time, with a small pencil under it. Tap the time or the pencil to change the reminder.",
            "A repeating reminder with a colour stands in a frame of that colour, with a faint tint of it inside. A thin bar in that colour sits at the left of the row, and its tick circle and its small repeat mark have the colour too. A one-off reminder never shows a colour.",
            "Swipe a row to the left to delete it, or to pause it: the purple “Pause” button offers “Until tomorrow 08:00” and “Pick a day…” (that opens the reminder’s page). A paused reminder offers “Nudge again now” there instead. Swipe a row to the right to tick it off.",
            "Press and hold a row that has a shortcut for half a second. You feel a short buzz, and its shortcut runs. If “Tick off when it runs” is on for that reminder, it is ticked off at the same moment. A row without a shortcut does nothing when you press and hold it.",
        ]),
        Part(title: "Making and changing a reminder", text: [
            "Press the round orange plus. Type what it is. Then choose when.",
            "Quick buttons: In 10 min, In 1 hour, This evening (19:00) and Tomorrow 8:00. If it is already past 19:00, “This evening” becomes “Tomorrow evening”.",
            "Or choose it yourself: the day (Today, Tomorrow, or Pick a day with a calendar), the hour from a grid (06:00 to 21:00), and the minutes (:00, :15, :30, :45).",
            "Repeat: Never, Daily, Weekly or Monthly. When it repeats, a row of colour dots appears under Repeat: “no colour” (a crossed circle) and Red, Orange, Yellow, Green, Teal, Blue, Purple and Pink. Tap one and it gets a ring. Nudge me every: 1, 5, 10, 15, 30 or 60 minutes.",
            "Shortcut: under “Nudge me every” you can type the name of one Apple Shortcut, or press the purple “Pick” button next to the field and choose it from a list. It is optional. Once you have typed a name, a small “Try it” button appears next to the field and runs the shortcut right away.",
            "Under the field is the switch “Tick off when it runs”. It is on at first. Under it a small line says “Press and hold the nudge or the row to run it.”",
            "Pause nudges: a choice row On, Tomorrow, Pick a day. Tomorrow means no nudges for this reminder until tomorrow at 08:00. Pick a day opens a calendar, and the nudges come back on that day at 08:00. A small line under it says when the nudges come back. Cancel drops the choice, Save keeps it.",
            "Cancel leaves without saving. Save keeps it. When you change an existing reminder, a Delete button is there too.",
        ]),
        Part(title: "How the nudging works", text: [
            "At the time you chose, your iPhone shows a message, also on the lock screen. The first nudge comes at that exact time. After that it nudges again every few minutes, as often as you chose, until you tick it off. The message says, for example, “Since 08:00 · 3rd nudge”.",
            "On the row, the nudge count grows by itself while you look at it.",
            "You can pause one reminder (see “Making and changing a reminder”) or all of them (see Settings). While it is paused it does not nudge you. Nothing is lost: a pause never moves a reminder or ticks it off, and when the pause ends the nudges simply start again, at 08:00 on the day you chose.",
        ]),
        Part(title: "Answering a nudge", text: [
            "Press and hold the message. Buttons appear: Done, In 10 minutes, In 1 hour and This evening. If the reminder has a shortcut, the first button is “Run: ” and the name of the shortcut, before all the others. Late in the day, “This evening” turns into “Tomorrow morning, 08:00”.",
            "Done ticks it off at once. You do not even have to open the app. “Run” also ticks it off when “Tick off when it runs” is on for that reminder. The other buttons move the reminder to a later time, and the nudges start again from there.",
        ]),
        Part(title: "Running a shortcut", text: [
            "Every reminder can hold the name of one Apple Shortcut. Example: you have a shortcut that calls Andreas Bjurling. Make a reminder “Call Andreas”, and in the Shortcut field type its name: Call Andreas Bjurling.",
            "The name must be the same as in the Shortcuts app, with the same capitals and the same spaces. If it is not, the Shortcuts app says it cannot find it. Press “Try it” once to check.",
            "When the reminder nudges you, press and hold the message and press “Run: Call Andreas Bjurling”. AMS Reminder opens for a moment and hands over to the Shortcuts app, which runs the shortcut. Here it starts the phone call.",
            "Or open the app and press and hold the row on the Reminders screen. You feel a short buzz, and the shortcut runs.",
            "“Tick off when it runs” is a switch on the edit screen, under the Shortcut field. It is on at first, also for reminders that already had a shortcut. While it is on, running the shortcut ticks the reminder off at the same moment, with the short happy buzz. It goes to Done (where “Bring back” undoes it), a repeating one moves on to its next time, and the nudges stop.",
            "Switch it off if you want the reminder to stay. Then the shortcut runs and the reminder keeps nudging you until you tick it off yourself, for example after the call.",
        ]),
        Part(title: "Shortcuts", text: [
            "You can type the name of a shortcut, or pick it from a list. Next to the Shortcut field is a purple “Pick” button. It opens “Your shortcuts”: the names of all your shortcuts, with a search field at the top. Tap one and it goes into the field.",
            "An iPhone app cannot look at your shortcuts by itself. So a small helper shortcut called “AMS Reminder List” does it for the app. You set it up once.",
            "The first time, the list page says so and shows two steps. Step 1, “Add the helper”: the iPhone's share list opens. Choose Shortcuts in it, then press “Add Shortcut”. If “AMS Reminder List” is already in your Shortcuts app (it comes over by itself from your Mac), skip this step. Step 2, “Load my shortcuts”: it runs the helper. The Shortcuts app flashes up for a moment and comes back with your list.",
            "The first time it runs, your iPhone may ask whether “AMS Reminder List” may open AMS Reminder. Answer Allow, or Always Allow.",
            "Your list is kept on the iPhone. After you make new shortcuts, press “Load again” at the bottom of the list page, or in Settings › Shortcuts › Your shortcuts. It runs the helper shortcut, the Shortcuts app flashes up for a moment, and it comes back with the new list. The helper itself does not show up in the list.",
        ]),
        Part(title: "Ticking off and repeating", text: [
            "A reminder with Repeat set to Never leaves the list when you tick it (and it shows no colour; if you switch a coloured reminder to Never, the colour is kept and comes back when it repeats again). A repeating one moves on to its next day, week or month, and starts nudging again then.",
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
            "Nudges is a choice row: On, Tomorrow, Pick a day, Off. Tomorrow and Pick a day pause the nudges of every reminder at once, and they come back by themselves at 08:00 on that day. Off means no nudges until you switch them On again. A small line under the row says when they come back. Your reminders stay in the list all the time. If your iPhone itself does not let the app nudge you, the row shows a “Turn on” button that opens the iPhone’s settings for the app. While all nudges are paused, the Reminders screen says so too, with a “Turn on” button.",
            "The Settings title is purple, like the Settings mark at the bottom right.",
            "Shortcuts (purple heading): “Your shortcuts” says how many are loaded, for example “37 loaded”, or “None yet”. It opens the list page, where you can load them or load them again.",
            "How it works is this guide. What’s new lists every version. The version number stands at the bottom.",
            "Your reminders stay on this iPhone only. Nothing goes to iCloud. Once a day the app keeps a safety copy of your list, and keeps the last 7 days.",
        ]),
        Part(title: "Signs in this app", text: [
            "Round orange button with a white plus: make a new reminder.",
            "Round green button with a green ring and a number: how many you have done today. Tap it to open Done.",
            "Empty circle at the left of a row: not done yet. Tap it and it turns into a green tick.",
            "Green tick: done. In a row it shows for a moment before the reminder leaves; in Done it marks what you ticked off.",
            "Orange: the time has come and the reminder is nudging you. The circle, the small bell and the grey line turn orange, and the group “Waiting for you” is orange. The title Persistent Reminders and the bell at the bottom are orange too.",
            "Small circling arrows beside the grey line: the reminder repeats.",
            "Small purple pause mark (two short upright lines) beside the grey line: this reminder is paused and does not nudge you until the time the line names. Purple is also the colour of the Pause button and of “Pause nudges”.",
            "A colour (frame, thin bar at the left, circle and repeat mark): the colour you gave a repeating reminder. A crossed circle in the colour row means no colour.",
            "Ring around a colour dot: the colour you chose.",
            "Small pencil under the time: tap the time or the pencil to change the reminder.",
            "Purple play mark: a shortcut. It stands beside the shortcut hint on the edit screen, in front of each name in “Your shortcuts” and at the Shortcuts row in Settings. Purple is also the colour of the Settings heading and the Settings mark at the bottom right. Purple also means nudges and pausing them: the pause mark, the Pause button and the Nudges row.",
            "Blue: the Today group.",
        ]),
    ]

    static let news: [Release] = [
        Release(version: "0.4", date: "19 Nov 2026", items: [
            "New: you can pause the nudges of one reminder. On the reminder’s page (tap the time or the pencil) there is a new part “Pause nudges” with a choice row: On, Tomorrow, Pick a day. Tomorrow means no nudges for this reminder until tomorrow at 08:00. Pick a day opens a calendar, and the nudges come back on that day at 08:00. A small line under the row says when they come back. Save keeps it, Cancel drops it.",
            "New: a quicker way. Swipe a reminder to the left and press the purple “Pause” button. Choose “Until tomorrow 08:00”, or “Pick a day…” (it opens the reminder’s page). When the reminder is already paused, the button offers “Nudge again now”.",
            "New: a paused reminder stays in the list. Its small grey line says “Paused until tomorrow 08:00” (or, for example, “Paused until Mon 23 Nov, 08:00”), with a small purple pause mark, two short upright lines, in place of the bell or the repeat mark. Ticking it off works as always.",
            "Changed: in Settings › Nudges, the on/off switch of 0.3.4 is now a choice row: On, Tomorrow, Pick a day, Off. Tomorrow and Pick a day pause all reminders at once, and the nudges come back by themselves at 08:00 on that day. Off means no nudges until you switch them On again. A small line under it says when they come back. If you had switched Nudges off in 0.3.4, it now reads Off.",
            "Changed: while all nudges are paused, the Reminders screen shows “Nudges are paused until …” (or “Nudges are off.”) with a “Turn on” button.",
            "Good to know: nothing is lost. Pausing never moves a reminder or ticks it off. When the pause ends, the nudges simply start again.",
            "Changed: “How it works” now tells about pausing in the parts One row, Making and changing a reminder, How the nudging works and Settings. “Signs in this app” has the purple pause mark, and says that purple means nudges and pausing them.",
        ]),
        Release(version: "0.3.4", date: "19 Nov 2026", items: [
            "Changed: when you tick off a reminder, its title is no longer struck through. The circle turns into a green tick, and then the reminder leaves the list.",
            "Removed: the small round purple play button on a row. It showed that a reminder has a shortcut. Press and hold still runs the shortcut, and the edit screen still shows which shortcut the reminder has.",
            "Removed: the day and date line at the top of the Reminders screen.",
            "Changed: the big title of the Reminders screen now says “Persistent Reminders”, in orange, the colour of the Reminders bell at the bottom. The tab at the bottom still says “Reminders”.",
            "Changed: the Settings title is now purple, the colour of the Settings mark at the bottom right.",
            "Changed: the wide “New reminder” bar is now a round orange button with a white plus, at the bottom left. The round green Done button stays at the bottom right.",
            "Changed: in Settings, “Nudges allowed”, which only said Yes and could not be changed, is now a switch “Nudges”. Off: the app pauses all nudges. None are planned, and your reminders stay in the list. On: they come back.",
            "New: if your iPhone itself does not let the app nudge you, the Nudges row shows a “Turn on” button that opens the iPhone’s settings for the app.",
            "New: when nudges are paused, the Reminders screen shows the line “Nudges are paused.” with a “Turn on” button.",
            "Changed: “How it works” now has a part “Signs in this app” (every mark and colour and what it means), and says how to load new shortcuts: Settings › Shortcuts › Your shortcuts › “Load again”.",
            "Fixed: the guide said the same sentence about the groups twice on the Reminders screen.",
        ]),
        Release(version: "0.3.3", date: "19 Nov 2026", items: [
            "Changed: ticking off is much easier. Before, only the small circle ticked a reminder off, and a tap anywhere else opened it. Now a tap on the circle, the title or the small grey line (most of the row) ticks it off.",
            "Changed: to change a reminder, tap the time on the right, or the small pencil under it.",
            "Fixed: the coloured frame now runs all the way round the row. Before, the corners of the list card cut off the frame's corners.",
            "Changed: the small purple play mark of a reminder with a shortcut is now a round purple play button, like the one in the Shortcuts app.",
        ]),
        Release(version: "0.3.2", date: "19 Nov 2026", items: [
            "Changed: a coloured reminder now stands in a frame of its colour, with a faint tint of that colour inside, so you see the colour at a glance. Before, only a thin bar, the circle and the repeat mark were coloured, which was too subtle. The bar, the circle and the repeat mark stay.",
        ]),
        Release(version: "0.3.1", date: "19 Nov 2026", items: [
            "Fixed: the app could close by itself when you pressed a button on a nudge (Done, In 10 minutes, In 1 hour, This evening, Run). The button still did its job, but the app crashed while answering. This was there since 0.1 and is now fixed.",
            "Fixed: “Add the helper” showed “Import Failed – the shortcut URL provided was invalid”, because Apple no longer lets an app add a shortcut by link. Now it opens the iPhone's share list: choose Shortcuts there, then “Add Shortcut”.",
            "Changed: the helper “AMS Reminder List” is already in your Shortcuts on the Mac and comes over to your iPhone by itself, so you can go straight to “Load my shortcuts”.",
            "Removed: the separate “Share the helper file” line, since “Add the helper” now does just that.",
        ]),
        Release(version: "0.3", date: "19 Nov 2026", items: [
            "Changed: the strip “2 done · 1 to go today” at the top of the Reminders screen is gone. Instead a small round button sits at the bottom right, beside the orange “New reminder” button: the green ring of today with the number done inside it. Tap it to open Done, as you did with the strip. The date of today still stands under the big title.",
            "New: repeating reminders can wear a colour. When Repeat is Daily, Weekly or Monthly, a row of colour dots appears under Repeat: “no colour” (a crossed circle) and Red, Orange, Yellow, Green, Teal, Blue, Purple and Pink. The one you choose gets a ring.",
            "New: a coloured reminder shows a thin colour bar at the left of its row, its tick circle in that colour and its small repeat mark in that colour. A one-off reminder never shows a colour. If you switch a coloured reminder to Never, the colour is kept but not shown, and it comes back when the reminder repeats again.",
            "New: a switch “Tick off when it runs” on the edit screen, under the Shortcut field. It is on at first, also for reminders that already had a shortcut.",
            "New: while it is on, running the shortcut ticks the reminder off at the same moment, whether you press and hold the row or press “Run” on a nudge. It goes to Done (“Bring back” undoes it), a repeating one moves on to its next time, and the nudges stop. You feel the short happy buzz of ticking off.",
            "Changed: before, a reminder kept nudging after its shortcut ran. Switch “Tick off when it runs” off and it works that way again. The small line under it still says “Press and hold the nudge or the row to run it.”",
            "New: a purple “Pick” button next to the Shortcut field opens “Your shortcuts”: a list of all your shortcuts with a search field at the top. Tap one and it goes into the field. You can still type a name instead.",
            "New: a small helper shortcut called “AMS Reminder List” reads your shortcut names for the app. The list page has two steps for the first time: “1. Add the helper” opens the Shortcuts app (press “Add Shortcut”), and “2. Load my shortcuts” runs it and brings your list back.",
            "New: the first time, iPhone may ask whether “AMS Reminder List” may open AMS Reminder. Answer Allow or Always Allow. If adding the helper does not open the Shortcuts app, “Share the helper file” offers it to the Shortcuts app instead.",
            "New: your list is kept on the iPhone. After you make new shortcuts, press “Load again” at the bottom of the list page. The helper itself does not show up in the list.",
            "New: Settings has a new part “Shortcuts” (purple heading) with the row “Your shortcuts”, which says how many are loaded (for example “37 loaded”, or “None yet”) and opens the same list. Under it: “Load them once with the helper, then pick them on each reminder.”",
            "Changed: the switch and the colour are saved with the reminder. Lists saved by older versions open without any trouble, and the switch reads as on. The file format number stays 1.",
            "Changed: How it works now has the new part “Shortcuts”, and the parts One row, Making and changing a reminder, Answering a nudge, Running a shortcut and Settings tell about the round Done button, the colours, the new switch, the Pick button and the shortcut list.",
        ]),
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
