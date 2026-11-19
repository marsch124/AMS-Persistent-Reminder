import XCTest

/// Screen tests: they find things by their identifier.
final class ReminderUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// New reminder → it is on the list → tick it → it is on the Done page (Settings) → bring it back.
    func testAddTickAndBringBack() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["all-clear"].waitForExistence(timeout: 10))

        app.buttons["new-reminder"].tap()
        let field = app.descendants(matching: .any).matching(identifier: "title-field").firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        app.typeText("Test reminder")
        app.buttons["quick-inTenMinutes"].tap()
        app.buttons["save"].tap()

        let tick = app.buttons["tick-Test reminder"]
        XCTAssertTrue(tick.waitForExistence(timeout: 5))
        tick.tap()
        XCTAssertTrue(tick.waitForNonExistence(timeout: 5))

        app.buttons["tab-settings"].tap()
        XCTAssertTrue(app.staticTexts["version"].waitForExistence(timeout: 5))
        app.buttons["settings-done"].tap()
        let done = app.descendants(matching: .any)["done-Test reminder"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        done.swipeLeft()
        app.buttons["Bring back"].tap()
        XCTAssertTrue(done.waitForNonExistence(timeout: 5))

        app.buttons["tab-reminders"].tap()
        XCTAssertTrue(app.buttons["tick-Test reminder"].waitForExistence(timeout: 5))
    }

    /// 0.2: a reminder with a shortcut shows the play mark on its row.
    func testShortcutOnAReminder() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
        app.buttons["new-reminder"].tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "title-field").firstMatch.waitForExistence(timeout: 5))
        app.typeText("Call Andreas\n")
        let field = app.textFields["shortcut-field"]
        app.swipeUp()
        field.tap()
        field.typeText("Call Andreas Bjurling")
        XCTAssertTrue(app.buttons["try-shortcut"].waitForExistence(timeout: 5))
        app.buttons["save"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["shortcut-mark-Call Andreas"].waitForExistence(timeout: 5))
    }

    /// 0.3: pick the shortcut from the list; the "Tick off when it runs" switch shows up, on.
    func testPickAShortcutFromTheList() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-sample"]
        app.launch()
        app.buttons["new-reminder"].tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "title-field").firstMatch.waitForExistence(timeout: 5))
        app.typeText("Call Andreas\n")
        app.swipeUp()
        app.buttons["pick-shortcut"].tap()
        let option = app.buttons["shortcut-option-Call Andreas Bjurling"]
        XCTAssertTrue(option.waitForExistence(timeout: 5))
        option.tap()
        XCTAssertEqual(app.textFields["shortcut-field"].value as? String, "Call Andreas Bjurling")
        let toggle = app.switches["tick-when-run"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        XCTAssertEqual(toggle.value as? String, "1")
        app.swipeDown()
        app.buttons["Daily"].tap()
        app.buttons["colour-teal"].tap()
        app.buttons["save"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["shortcut-mark-Call Andreas"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["colour-bar-Call Andreas"].exists)
        // 0.3.3: the small area on the right (time + pencil) opens the reminder; the rest ticks it off.
        app.descendants(matching: .any)["edit-Call Andreas"].tap()
        XCTAssertTrue(app.buttons["cancel"].waitForExistence(timeout: 5))
        app.buttons["cancel"].tap()
        app.buttons["done-button"].tap()
        XCTAssertTrue(app.buttons["close-done"].waitForExistence(timeout: 5))
    }

    /// The heart of the app: a reminder whose time has come pops up as a nudge.
    /// Local only, on request (NUDGE_TEST=1): the simulator did not show the permission question on 19 Nov 2026.
    func testANudgePopsUp() throws {
        guard ProcessInfo.processInfo.environment["NUDGE_TEST"] != nil else { throw XCTSkip("nudge test only on request") }
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-realNudges"]
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        app.launch()
        let allow = springboard.buttons["Allow"]
        if let folder = ProcessInfo.processInfo.environment["SHOTS"] {
            sleep(3)
            try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(folder)/perm.png"))
            try? springboard.debugDescription.write(toFile: "\(folder)/perm-springboard.txt", atomically: true, encoding: .utf8)
        }
        if allow.waitForExistence(timeout: 10) { allow.tap() }
        // The iPhone must allow the nudges, or nothing can pop up.
        app.buttons["tab-settings"].tap()
        let yes = app.staticTexts["nudges-allowed-yes"]
        if !yes.waitForExistence(timeout: 5), let folder = ProcessInfo.processInfo.environment["SHOTS"] {
            try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(folder)/nudge-permission.png"))
            try? springboard.debugDescription.write(toFile: "\(folder)/springboard-start.txt", atomically: true, encoding: .utf8)
        }
        XCTAssertTrue(yes.exists, "nudges are not allowed")
        app.buttons["tab-reminders"].tap()
        app.buttons["new-reminder"].tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "title-field").firstMatch.waitForExistence(timeout: 5))
        app.typeText("Nudge test")
        app.buttons["Today"].firstMatch.tap()
        app.buttons["hour-6"].tap()          // early this morning: already passed, so it nudges right away
        app.buttons["save"].tap()
        XCUIDevice.shared.press(.home)      // like a phone in the pocket: the nudge comes from the iPhone itself
        if let folder = ProcessInfo.processInfo.environment["SHOTS"] {
            for i in 1...4 {
                sleep(3)
                try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(folder)/nudge-\(i).png"))
            }
        }
        let banner = springboard.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS 'Nudge test'")).firstMatch
        let seen = banner.waitForExistence(timeout: 20)
        if !seen {
            app.activate()
            app.buttons["tab-settings"].tap()
            let planned = app.staticTexts["planned"]
            if planned.waitForExistence(timeout: 5) { print("PLANNED-READOUT: \(planned.label)") }
        }
        if !seen, let folder = ProcessInfo.processInfo.environment["SHOTS"] {
            try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(folder)/nudge-fail.png"))
            try? springboard.debugDescription.write(toFile: "\(folder)/springboard.txt", atomically: true, encoding: .utf8)
        }
        XCTAssertTrue(seen)
    }

    /// Pictures for the guide and the overview (run by hand: TEST_RUNNER_SHOTS=<folder>).
    func testPictures() throws {
        guard let folder = ProcessInfo.processInfo.environment["SHOTS"] else { throw XCTSkip("pictures only on request") }
        let look = ProcessInfo.processInfo.environment["LOOK"] ?? "light"
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-sample"]
        app.launch()
        func shot(_ name: String) {
            sleep(1)
            let png = XCUIScreen.main.screenshot().pngRepresentation
            try? png.write(to: URL(fileURLWithPath: "\(folder)/\(name)-\(look).png"))
        }
        XCTAssertTrue(app.buttons["new-reminder"].waitForExistence(timeout: 10))
        shot("1-reminders")
        app.buttons["new-reminder"].tap()
        let field = app.descendants(matching: .any).matching(identifier: "title-field").firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        app.typeText("Take vitamins\n")
        app.buttons["quick-tomorrowMorning"].tap()
        app.buttons["Daily"].tap()
        app.buttons["colour-pink"].tap()
        shot("2-new")
        app.swipeUp()
        app.buttons["pick-shortcut"].tap()
        XCTAssertTrue(app.buttons["shortcut-option-Coffee timer"].waitForExistence(timeout: 5))
        shot("2b-picker")
        app.buttons["shortcut-option-Coffee timer"].tap()
        XCTAssertTrue(app.switches["tick-when-run"].waitForExistence(timeout: 5))
        shot("2c-switch")
        app.buttons["cancel"].tap()
        app.buttons["tab-settings"].tap()
        XCTAssertTrue(app.buttons["settings-done"].waitForExistence(timeout: 5))
        shot("3-settings")
        app.buttons["settings-done"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["done-hero"].waitForExistence(timeout: 5))
        shot("4-done")
    }
}
