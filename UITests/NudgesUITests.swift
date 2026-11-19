import XCTest

/// 0.5 lane "nudges": the new parts of Settings (not run by the lane; Apple's run is the check).
final class NudgesUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    func testQuietHoursAndLaterButtonsInSettings() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
        app.buttons["tab-settings"].tap()

        let quiet = app.switches["quiet-switch"]
        XCTAssertTrue(quiet.waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["quiet-from"].exists)
        quiet.tap()
        XCTAssertTrue(app.descendants(matching: .any)["quiet-from"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.descendants(matching: .any)["quiet-to"].exists)

        // The later buttons: the usual three are chosen; tapping another swaps it in.
        let twoHours = app.buttons["later-twoHours"]
        XCTAssertTrue(twoHours.waitForExistence(timeout: 3))
        XCTAssertFalse(twoHours.isSelected)
        twoHours.tap()
        XCTAssertTrue(twoHours.isSelected)
        XCTAssertFalse(app.buttons["later-tenMinutes"].isSelected)
    }
}
