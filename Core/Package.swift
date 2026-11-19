// swift-tools-version: 5.9
import PackageDescription

// The rules of AMS Persistent Reminder, with no screen in them: reminders, ticking off, repeating,
// quick times and the nudge plan. `swift test` runs them in seconds.
let package = Package(
    name: "ReminderCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "ReminderCore", targets: ["ReminderCore"])],
    targets: [
        .target(name: "ReminderCore"),
        .testTarget(name: "ReminderCoreTests", dependencies: ["ReminderCore"]),
    ]
)
