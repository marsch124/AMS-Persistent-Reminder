# AMS Persistent Reminder: specification (0.2, build 3)

Name under the icon: AMS Reminder. Bundle id: com.schabbauer.AMSPersistentReminder. iPhone only, portrait, iOS 17+. Positive, calm, Apple look; Apple's standard text sizes; compact rows.

## 1. Idea
A reminder keeps nudging every N minutes from its due time until it is ticked off. All rules live in `Core/Sources/ReminderCore/Reminders.swift` and are tested with `swift test --package-path Core`.

## 2. Data
- Reminder: id, title, due (next time it is for), repeats (never / daily / weekly / monthly), nudgeMinutes (default 5), shortcut (optional text: the exact name of one Apple Shortcut; empty or missing = none; stored trimmed), created.
- Done entry: id, the reminder as it was when ticked, doneAt, nudges.
- List: format number (1), reminders, done entries.
- Tolerant reading: a missing or unreadable field gets a sensible value (new id, empty title, due now, Never, 5 minutes, no shortcut, now) instead of losing the reminder; a missing list reads as empty; a later version's extra fields are ignored.
- Stored as one data file on the iPhone only (no iCloud). A safety copy is kept each day; the last 7 days are kept.

## 3. Rules
- Waiting: a reminder is waiting when due <= now.
- Interval: nudgeMinutes, never less than 1 minute. Choices: 1, 5, 10, 15, 30, 60.
- Nudge counting: the first nudge comes at the due time. Nudges so far = floor((now - due) / interval) + 1 when due <= now, otherwise 0. The next nudge is due + (nudges so far) x interval; before the due time it is the due time.
- Tick: the entry goes to the top of Done with doneAt = now and nudges = nudges so far. A reminder with Never leaves the list. A repeating one moves its due to the next occurrence strictly after now, counted from its own due time: daily = +n days, weekly = +n weeks, monthly = +n months (a 31st stays on the last day of short months and returns to the 31st). Its nudge count then starts again.
- Done text: 1 nudge or fewer = "On time"; otherwise "After N nudges".
- Bring back: the reminder returns with the due time it had when ticked (a repeating one that still exists gets that earlier due back; otherwise it is added again) and the Done entry goes.
- Snooze (In 10 minutes, In 1 hour, This evening, Tomorrow morning): sets due to the new time; nudges count again from there.
- Shortcut: a reminder with a non-empty shortcut name can run it from the nudge or from its row. Running never ticks the reminder off, never moves its due time and never changes its nudge count; it keeps nudging until ticked off.
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
- Small line with a green ring: "2 done · 4 to go today" (done today; to go = waiting + the rest of today). Tap opens Done.
- Groups, each sorted by time, empty ones hidden: Waiting for you (orange; due <= now), Today (blue), Tomorrow, Later. Calm empty state when there is nothing.
- Row: round tick circle (tap = done, short happy buzz); title; small grey line: waiting = "Nudging every 5 min · 3rd nudge", repeating = "Every day" / "Every Thursday" / "Every month", otherwise "Nudge every 10 min"; time on the right. A row with a shortcut shows a small purple play mark just before the time.
- Tap a row = change it. Swipe left = delete. Swipe right = tick off. Press and hold (0.5 s) a row with a shortcut = short buzz (haptic), then the shortcut runs (see section 6a). Rows without a shortcut: nothing happens on press and hold.
- Big full-colour orange button "New reminder" at the bottom.

### New reminder / Change reminder
- Cancel and Save (Escape = Cancel where there is a keyboard). Save needs a title.
- A text field for what it is. WHEN: the four quick buttons, or day + hour grid + minutes. REPEAT: Never / Daily / Weekly / Monthly. NUDGE ME EVERY: 1 / 5 / 10 / 15 / 30 / 60 minutes (starts with the Settings choice). SHORTCUT (heading, under NUDGE ME EVERY): a text field "Name of a shortcut (optional)" (no auto-capitals, no auto-correct); under it a small line with a play mark: "Press and hold the nudge or the row to run it."; when a name is typed (not only spaces) a small "Try it" button next to the field runs the shortcut at once (section 6a).
- Changing an existing reminder also shows a Delete button.

### Done (from Settings, or by tapping the ring)
- Green ring "Nice work! 4 of 5 done today" (done today of done today + still to go today).
- Today and earlier days, newest first; each line the title, the time and "On time" / "After 3 nudges".
- Swipe left = Bring back. Entries older than 30 days are tidied away.

### Settings
- Done; Nudge me every (starting choice for new reminders, 5 min at first); Nudges allowed? (shows whether the iPhone allows it; a button opens the iPhone's settings when off); How it works; What's new (every version, newest first); the version number at the bottom.

## 6. The nudge
- A message at the due time, also on the lock screen, then every N minutes: "Since 08:00 · 3rd nudge".
- Press and hold for buttons: [Run: <shortcut name> (only when the reminder has a shortcut; always first)], Done, In 10 minutes, In 1 hour, This evening (late in the day: Tomorrow morning, 08:00). Done ticks it off without opening the app (including moving on a repeating one).
- Planning: the iPhone holds about 64 planned messages, so the app plans up to 60 nudges ahead, earliest first across all reminders. It tops them up every time it opens or the list changes. A reminder left for many hours may go quiet until the app is opened.
- Permission: if the iPhone does not allow nudges, Settings says so and offers a button to the iPhone's settings.

### 6a. Running a shortcut
- The name must match the shortcut's name in the Shortcuts app exactly (same capitals and spaces), e.g. "Call Andreas Bjurling". If it does not, the Shortcuts app says it cannot find it.
- Handover: the app opens the link `shortcuts://run-shortcut?name=<percent-encoded name>`. The Shortcuts app runs it; no result is waited for.
- From the nudge: the Run action has the option "open the app" (foreground), so pressing it opens AMS Reminder for a moment, which then makes the handover. The reminder stays on the list and keeps nudging until ticked off (the user ticks it off after the call).
- Notification categories: `nudge` (Done, In 10 minutes, In 1 hour, This evening) and `nudge-late` (the same with Tomorrow morning) for reminders without a shortcut. A reminder with a shortcut gets its own pair, `nudge-sc-<uuid>` and `nudge-late-sc-<uuid>` (uuid = the reminder id), whose first action is "Run: <name>" (opens the app); the other four actions are as before. The categories are registered together before nudges are planned and are rebuilt whenever the list changes; each planned nudge carries the category of its reminder.
- From the row: a long press of 0.5 s on a row with a shortcut gives a short haptic buzz and makes the same handover. A tap still opens the reminder; swipes are unchanged.
- From the edit screen: "Try it" makes the same handover.

## 7. Keeping data
- One data file on this iPhone; one safety copy per day, the last 7 days kept; never put in a public repository.
- No iCloud.
- The shortcut name is stored with the reminder as the field `shortcut`. Lists saved by 0.1 (no such field) open fine; the file format number stays 1.

## 8. Versions
0.1 (19 November 2026): the first version.
0.2, build 3 (19 Nov 2026): a reminder can hold the name of an Apple Shortcut; Shortcut field and "Try it" on the edit screen; "Run: <name>" first button on the nudge; purple play mark and press-and-hold on the row; field `shortcut` in the saved file (format still 1).
