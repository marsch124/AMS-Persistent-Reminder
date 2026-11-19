import XCTest

/// 0.5 voice lane: the note and "Call or open" part of the reminder page, and the hold caption.
final class VoiceUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    func testNoteAndLinkOnReminderPage() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
        XCTAssertTrue(app.staticTexts["hold-to-speak-caption"].waitForExistence(timeout: 10))

        app.buttons["new-reminder"].tap()
        let title = app.descendants(matching: .any).matching(identifier: "title-field").firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        app.typeText("Call the dentist")

        let note = app.descendants(matching: .any).matching(identifier: "note-field").firstMatch
        for _ in 0..<6 where !note.isHittable { app.swipeUp() }
        note.tap()
        app.typeText("Ask about the bill")

        app.buttons["Link"].tap()
        let address = app.descendants(matching: .any).matching(identifier: "link-address").firstMatch
        XCTAssertTrue(address.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["try-action"].exists)
        XCTAssertFalse(app.buttons["try-action"].isEnabled)
        address.tap()
        app.typeText("example.com")
        XCTAssertTrue(app.buttons["try-action"].isEnabled)
        app.buttons["Call"].tap()
        XCTAssertTrue(app.buttons["pick-contact"].waitForExistence(timeout: 5))

        app.buttons["quick-inTenMinutes"].tap()
        app.buttons["save"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["note-Call the dentist"].waitForExistence(timeout: 5))
    }
}
