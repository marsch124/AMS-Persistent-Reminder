# AMS Persistent Reminder: specification (0.3, build 4)

Name under the icon: AMS Reminder. Bundle id: com.schabbauer.AMSPersistentReminder. iPhone only, portrait, iOS 17+. Positive, calm, Apple look; Apple's standard text sizes; compact rows.

## 1. Idea
A reminder keeps nudging every N minutes from its due time until it is ticked off. All rules live in `Core/Sources/ReminderCore/Reminders.swift` and are tested with `swift test --package-path Core`.

## 2. Data
- Reminder: id, title, due (next time it is for), repeats (never / daily / weekly / monthly), nudgeMinutes (default 5), shortcut (optional text: the exact name of one Apple Shortcut; empty or missing = none; stored trimmed), tickWhenRun (true/false, default true; read as true when missing), colour (red, orange, yellow, green, teal, blue, purple, pink or none; default none; an unknown colour reads as none), created.
- Done entry: id, the reminder as it was when ticked, doneAt, nudges.
- List: format number (1), reminders, done entries.
- Tolerant reading: a missing or unreadable field gets a sensible value (new id, empty title, due now, Never, 5 minutes, no shortcut, tick when run on, now) instead of losing the reminder; a missing list reads as empty; a later version's extra fields are ignored.
- Stored as one data file on the iPhone only (no iCloud). A safety copy is kept each day; the last 7 days are kept.

## 3. Rules
- Waiting: a reminder is waiting when due <= now.
- Interval: nudgeMinutes, never less than 1 minute. Choices: 1, 5, 10, 15, 30, 60.
- Nudge counting: the first nudge comes at the due time. Nudges so far = floor((now - due) / interval) + 1 when due <= now, otherwise 0. The next nudge is due + (nudges so far) x interval; before the due time it is the due time.
- Tick: the entry goes to the top of Done with doneAt = now and nudges = nudges so far. A reminder with Never leaves the list. A repeating one moves its due to the next occurrence strictly after now, counted from its own due time: daily = +n days, weekly = +n weeks, monthly = +n months (a 31st stays on the last day of short months and returns to the 31st). Its nudge count then starts again.
- Done text: 1 nudge or fewer = "On time"; otherwise "After N nudges".
- Bring back: the reminder returns with the due time it had when ticked (a repeating one that still exists gets that earlier due back; otherwise it is added again) and the Done entry goes.
- Snooze (In 10 minutes, In 1 hour, This evening, Tomorrow morning): sets due to the new time; nudges count again from there.
- Shortcut: a reminder with a non-empty shortcut name can run it from the nudge or from its row.
- Tick when run: with tickWhenRun on (the default, also for reminders saved before 0.3), running the shortcut from the row or from the nudge's Run button ticks the reminder off at the same moment by the normal Tick rule (Done entry, a repeating one moves on, nudges stop; Bring back undoes it). With it off, running never ticks the reminder off, never moves its due time and never changes its nudge count; it keeps nudging until ticked off (as in 0.2). "Try it" on the edit screen never ticks.
- Shortcut list: the names of the user's shortcuts, kept in the app's settings on the iPhone, sorted A-Z, without "AMS Reminder List" itself (the helper). Empty until loaded.
- Colour: only shown when the reminder repeats. Switching a coloured reminder to Never keeps the colour in the data but does not show it; it shows again if the reminder repeats again.
- Forgetting: Done entries older than 30 days (counted from the start of today) are dropped.

## 4. Quick times
- In 10 min: now + 10 minutes. In 1 hour: now + 1 hour.
- This evening: today 19:00. After 19:00 the button reads "Tomorrow evening" and means tomorrow 19:00.
- Tomorrow 8:00: tomorrow at 08:00.
- On a nudge: "This evening" the same way; late in the day (after 19:00) it reads "Tomorrow morning" and means 08:00 the next day.
- By hand: day (Today / Tomorrow / Pick a day with a calendar), hour from a grid 06:00-21:00, minutes :00 :15 :30 :45.

## 5. Screens
### Tab bar
Two tabs with large hand-drawn icons: Reminders (orange bell) and Settings (gear).

### Reminders
- Big title "Reminders"; today's date under it.
- No strip under the date (the old "2 done · 4 to go today" line and its `today-pill` are removed). Instead a small round button `done-button` at the bottom right, beside the "New reminder" button: the green ring of today (done today of done today + still to go today) with the number done today inside it. Tap opens Done.
- Groups, each sorted by time, empty ones hidden: Waiting for you (orange; due <= now), Today (blue), Tomorrow, Later. Calm empty state when there is nothing.
- Row: round tick circle (tap = done, short happy buzz); title; small grey line: waiting = "Nudging every 5 min · 3rd nudge", repeating = "Every day" / "Every Thursday" / "Every month", otherwise "Nudge every 10 min"; time on the right. A row with a shortcut shows a small purple play mark just before the time. A repeating reminder with a colour shows a thin colour bar (`colour-bar-<title>`) at the left of the row, its tick circle in that colour and its small repeat mark in that colour. A reminder with Repeat Never never shows a colour.
- Tap a row = change it. Swipe left = delete. Swipe right = tick off. Press and hold (0.5 s) a row with a shortcut = short buzz (haptic), then the shortcut runs (see section 6a) and, if tickWhenRun is on, the reminder is ticked off. Rows without a shortcut: nothing happens on press and hold.
- Big full-colour orange button "New reminder" at the bottom.

### New reminder / Change reminder
- Cancel and Save (Escape = Cancel where there is a keyboard). Save needs a title.
- A text field for what it is. WHEN: the four quick buttons, or day + hour grid + minutes. REPEAT: Never / Daily / Weekly / Monthly; when Daily, Weekly or Monthly, a row of colour dots right under it: `colour-none` (a crossed circle) and `colour-<name>` for red, orange, yellow, green, teal, blue, purple, pink; the chosen one has a ring. NUDGE ME EVERY: 1 / 5 / 10 / 15 / 30 / 60 minutes (starts with the Settings choice). SHORTCUT (heading, under NUDGE ME EVERY): a text field "Name of a shortcut (optional)" (no auto-capitals, no auto-correct); under it a small line with a play mark: "Press and hold the nudge or the row to run it."; when a name is typed (not only spaces) a small "Try it" button next to the field runs the shortcut at once (section 6a). Next to the field a purple "Pick" button (`pick-shortcut`) opens "Your shortcuts" (section 6b); the chosen name goes into the field. Under the field a switch "Tick off when it runs" (`tick-when-run`, on by default) sets tickWhenRun; the small line under it reads "Press and hold the nudge or the row to run it." When the switch is on, running the shortcut also gives the short happy buzz of ticking off.
- Changing an existing reminder also shows a Delete button.

### Done (from Settings, or by tapping the round button)
- Green ring "Nice work! 4 of 5 done today" (done today of done today + still to go today).
- Today and earlier days, newest first; each line the title, the time and "On time" / "After 3 nudges".
- Swipe left = Bring back. Entries older than 30 days are tidied away.

### Settings
- Done; Shortcuts part (purple heading; row `settings-shortcuts` "Your shortcuts" showing "37 loaded" or "None yet", opens the list page of section 6b; footer: "Load them once with the helper, then pick them on each reminder."; a "Load again" action); Nudge me every (starting choice for new reminders, 5 min at first); Nudges allowed? (shows whether the iPhone allows it; a button opens the iPhone's settings when off); How it works; What's new (every version, newest first); the version number at the bottom.

## 6. The nudge
- A message at the due time, also on the lock screen, then every N minutes: "Since 08:00 · 3rd nudge".
- Press and hold for buttons: [Run: <shortcut name> (only when the reminder has a shortcut; always first)], Done, In 10 minutes, In 1 hour, This evening (late in the day: Tomorrow morning, 08:00). Done ticks it off without opening the app (including moving on a repeating one).
- Planning: the iPhone holds about 64 planned messages, so the app plans up to 60 nudges ahead, earliest first across all reminders. It tops them up every time it opens or the list changes. A reminder left for many hours may go quiet until the app is opened.
- Permission: if the iPhone does not allow nudges, Settings says so and offers a button to the iPhone's settings.

### 6a. Running a shortcut
- The name must match the shortcut's name in the Shortcuts app exactly (same capitals and spaces), e.g. "Call Andreas Bjurling". If it does not, the Shortcuts app says it cannot find it.
- Handover: the app opens the link `shortcuts://run-shortcut?name=<percent-encoded name>`. The Shortcuts app runs it; no result is waited for.
- From the nudge: the Run action has the option "open the app" (foreground), so pressing it opens AMS Reminder for a moment, which then makes the handover. With tickWhenRun on, the reminder is ticked off at the same moment (the handover still happens); with it off it stays on the list and keeps nudging until ticked off.
- Notification categories: `nudge` (Done, In 10 minutes, In 1 hour, This evening) and `nudge-late` (the same with Tomorrow morning) for reminders without a shortcut. A reminder with a shortcut gets its own pair, `nudge-sc-<uuid>` and `nudge-late-sc-<uuid>` (uuid = the reminder id), whose first action is "Run: <name>" (opens the app); the other four actions are as before. The categories are registered together before nudges are planned and are rebuilt whenever the list changes; each planned nudge carries the category of its reminder.
- From the row: a long press of 0.5 s on a row with a shortcut gives a short haptic buzz and makes the same handover and, with tickWhenRun on, ticks the reminder off with the happy buzz. A tap still opens the reminder; swipes are unchanged.
- From the edit screen: "Try it" makes the same handover and never ticks.

### 6b. Your shortcuts (the list page)
- Opened by the Pick button on the edit screen (`pick-shortcut`) or the Settings row (`settings-shortcuts`). A list (`shortcut-picker`) of the stored names with a search field at the top; each row `shortcut-option-<name>`; tapping one puts the name into the Shortcut field and closes the page. A name can still be typed by hand.
- An iPhone app cannot read the user's shortcuts, so a helper shortcut "AMS Reminder List" does it. First time (empty list) the page says so and shows two steps: "1. Add the helper" (`add-helper`) and "2. Load my shortcuts" (`load-shortcuts`). Later "Load again" (bottom of the page, and in Settings) runs the helper again.
- Add the helper: the app opens `shortcuts://import-shortcut` with the helper file from the public GitHub repository (https://raw.githubusercontent.com/marsch124/AMS-Persistent-Reminder/main/App/Resources/AMS%20Reminder%20List.shortcut); the Shortcuts app asks the user to press "Add Shortcut". Fallback if it does not open: "Share the helper file" (`share-helper`) offers the bundled file to the Shortcuts app through the share sheet.
- Load: the app runs the helper by `shortcuts://run-shortcut?name=AMS%20Reminder%20List`. The Shortcuts app flashes up, collects the names and opens the link back `amsreminder://shortcuts?names=<one name per line, encoded>`. The app stores them sorted A-Z, without "AMS Reminder List", and shows the list. The first time, iOS may ask whether "AMS Reminder List" may open AMS Reminder (Allow / Always Allow).
- The helper file `App/Resources/AMS Reminder List.shortcut` is built and signed by `python3 Tools/make-helper-shortcut.py`.

## 7. Keeping data
- One data file on this iPhone; one safety copy per day, the last 7 days kept; never put in a public repository.
- No iCloud.
- The shortcut name is stored with the reminder as the field `shortcut`. Lists saved by 0.1 (no such field) open fine. The colour is stored as `colour`; a missing or unknown value reads as none. The switch is stored as `tickWhenRun`; a missing field reads as true. The file format number stays 1.
- The shortcut list is kept in the app's settings on the iPhone (not in the reminders file) and is not part of the safety copy.

## 8. Versions
0.1 (19 November 2026): the first version.
0.2, build 3 (19 Nov 2026): a reminder can hold the name of an Apple Shortcut; Shortcut field and "Try it" on the edit screen; "Run: <name>" first button on the nudge; purple play mark and press-and-hold on the row; field `shortcut` in the saved file (format still 1).
0.3, build 4 (19 Nov 2026): switch "Tick off when it runs" (`tickWhenRun`, default on, also for old reminders) ticks the reminder off when its shortcut runs from the row or the nudge; "Pick" button and "Your shortcuts" list page filled by the helper shortcut "AMS Reminder List" (link back `amsreminder://shortcuts`); Settings "Shortcuts" part; file format still 1.
0.3 also: the "done · to go" strip is replaced by a round `done-button` (green ring with the number done) at the bottom right; repeating reminders can wear one of eight colours (`colour`, bar, tick circle and repeat mark), format still 1.
