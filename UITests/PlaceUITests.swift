import XCTest

/// 0.5 pick 11: the place part of the reminder page (written, not run by the lane).
final class PlaceUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    func testPlaceSwitchReplacesTheWhenPart() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
        app.buttons["new-reminder"].tap()
        XCTAssertTrue(app.buttons["hour-9"].waitForExistence(timeout: 5))

        let sw = app.switches["place-switch"]
        XCTAssertTrue(sw.waitForExistence(timeout: 5))
        sw.tap()
        XCTAssertTrue(app.textFields["place-name"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["place-use-here"].exists)
        XCTAssertTrue(app.buttons["place-radius-200"].exists)
        XCTAssertTrue(app.segmentedControls["place-when"].exists)
        XCTAssertFalse(app.buttons["hour-9"].exists)

        sw.tap()
        XCTAssertTrue(app.buttons["hour-9"].waitForExistence(timeout: 5))
    }
}
