# AMS Persistent Reminder — notes for Claude

iPhone-only SwiftUI app (iOS 17+, portrait): reminders that keep nudging until ticked off. Started 19 Nov 2026,
inspired by the Due app. Martin's rules (global CLAUDE.md) apply; he is not technical.

## Layout
- `project.yml` (XcodeGen; `xcodegen generate`). Version: MARKETING_VERSION + CURRENT_PROJECT_VERSION there only.
- `Core/` = ReminderCore, the rules (reminders, tick, repeat, bring back, quick times, nudge plan, words).
  `swift test --package-path Core` — one small test per rule. GitHub runs it on every push (`.github/workflows/tests.yml`).
- `App/Sources`: `App.swift` (theme, two-part bottom bar with large hand-drawn marks), `RemindersScreen.swift`,
  `EditReminderView.swift`, `SettingsScreen.swift` (Settings, Done, How it works, What's new), `Store.swift` (file +
  daily safety copies, 7 kept), `Nudger.swift` (plans up to 60 messages, answers their buttons), `Guide.swift`
  (How it works + What's new — every release adds an entry at the top of `news`).
- Icons: AMS-Icons package pinned by revision (bell = `AppMark.bell`). New marks go into AMS-Icons first.
- App icon: `python3 Tools/make-icon.py` (bell on a calm orange tile, RGB, no alpha).
- `Docs/SPEC.md` = the written specification; update every detail each release.

## Tests
- Rules: `swift test --package-path Core`.
- Screens: `UITests/ReminderUITests.swift` (by identifier). `-uiTesting` = list in memory, never saved, no nudges;
  `-sample` = made-up list; `-realNudges` = plan real nudges in a test. Pictures: run `testPictures` with
  `TEST_RUNNER_SHOTS=<folder> TEST_RUNNER_LOOK=light|dark`.

## Release
1. Bump MARKETING_VERSION + CURRENT_PROJECT_VERSION; What's new entry in `Guide.swift`; How it works; `Docs/SPEC.md`.
2. `swift test --package-path Core`; commit; push.
3. `Tools/release.sh <build>` (archive + upload with the ADMIN key), check buildUploads, add the build to the
   beta group "Martin", set What to Test.
