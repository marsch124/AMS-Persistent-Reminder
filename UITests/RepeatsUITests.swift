import XCTest

/// 0.5 lane "repeats": the Repeat chips, the day buttons and the hours/days stepper.
final class RepeatsUITests: XCTestCase {
    func testRepeatChipsDaysAndStepper() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
        app.buttons["new-reminder"].tap()
        let title = app.textFields.firstMatch
        title.tap()
        title.typeText("Gym\n")

        app.buttons["repeat-weekdays"].tap()
        app.scrollTo(app.buttons["day-2"])
        XCTAssertTrue(app.buttons["day-2"].waitForExistence(timeout: 3))
        app.buttons["days-weekdays"].tap()
        XCTAssertTrue(app.buttons["day-2"].isSelected)
        XCTAssertFalse(app.buttons["day-7"].isSelected)

        app.buttons["repeat-hours"].tap()
        XCTAssertTrue(app.buttons["every-plus"].waitForExistence(timeout: 3))
        app.buttons["every-plus"].tap()
        app.buttons["every-minus"].tap()
        XCTAssertTrue(app.switches["after-done"].exists)
    }
}
