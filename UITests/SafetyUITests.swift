import XCTest

/// The "Keep it safe" part of Settings and the Undo bar (0.5, lane safety). Written, not run by the lane.
final class SafetyUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    func testKeepItSafePartIsThere() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
        app.buttons["tab-settings"].tap()
        let sw = app.switches["cloud-switch"]
        XCTAssertTrue(sw.waitForExistence(timeout: 5) || app.descendants(matching: .any)["cloud-switch"].exists)
        XCTAssertTrue(app.staticTexts["cloud-saved-line"].exists)
        XCTAssertEqual(app.staticTexts["cloud-saved-line"].label, "Not saved yet")
        XCTAssertTrue(app.buttons["cloud-bring-back"].exists)
        XCTAssertTrue(app.buttons["copy-save"].exists)
        XCTAssertTrue(app.buttons["copy-bring-back"].exists)
    }

    func testUndoBarBringsTheReminderBack() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-sample"]
        app.launch()
        let tick = app.buttons["tick-Call the dentist"]
        XCTAssertTrue(tick.waitForExistence(timeout: 10))
        tick.tap()
        XCTAssertTrue(app.descendants(matching: .any)["undo-bar"].waitForExistence(timeout: 5))
        app.buttons["undo"].tap()
        XCTAssertTrue(app.buttons["tick-Call the dentist"].waitForExistence(timeout: 5))
    }
}
