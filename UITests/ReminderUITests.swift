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

    /// The heart of the app: a reminder whose time has come pops up as a nudge.
    func testANudgePopsUp() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-realNudges"]
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        app.launch()
        let allow = springboard.buttons["Allow"]
        if allow.waitForExistence(timeout: 5) { allow.tap() }
        app.buttons["new-reminder"].tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "title-field").firstMatch.waitForExistence(timeout: 5))
        app.typeText("Nudge test")
        app.buttons["Today"].firstMatch.tap()
        app.buttons["hour-6"].tap()          // early this morning: already passed, so it nudges right away
        app.buttons["save"].tap()
        let banner = springboard.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS 'Nudge test'")).firstMatch
        let seen = banner.waitForExistence(timeout: 20)
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
        app.typeText("Take vitamins")
        app.buttons["quick-tomorrowMorning"].tap()
        shot("2-new")
        app.buttons["cancel"].tap()
        app.buttons["tab-settings"].tap()
        XCTAssertTrue(app.buttons["settings-done"].waitForExistence(timeout: 5))
        shot("3-settings")
        app.buttons["settings-done"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["done-hero"].waitForExistence(timeout: 5))
        shot("4-done")
    }
}
