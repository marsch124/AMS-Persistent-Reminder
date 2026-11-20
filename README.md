# AMS Persistent Reminder

An iPhone app (iOS 17+, portrait only) for reminders that keep nudging you until you tick them off, in the spirit of the Due app. Calm, positive, Apple look. Name under the icon: "Persistent". Bundle id: `com.schabbauer.AMSPersistentReminder`. Data stays on the iPhone.

## How it is built

- `project.yml` is the XcodeGen project; the Xcode project is generated from it.
- `Core/` is a Swift package (`ReminderCore`) with all the rules and no screens. Its tests run in seconds: `swift test --package-path Core`.
- `App/` holds the screens, resources and config. `UITests/` holds the screen tests.
- `Tools/release.sh` builds and ships a version to TestFlight.

## Where the words live

- Guide ("How it works" and "What's new"): `App/Sources/Guide.swift`
- Written specification: `Docs/SPEC.md`

Every new version updates What's new, How it works and the specification.
