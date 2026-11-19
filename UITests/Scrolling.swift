import XCTest

extension XCUIApplication {
    /// Swipes up (at most 8 times) until the element is on screen; pages grew long in 0.5.
    @discardableResult
    func scrollTo(_ element: XCUIElement, max: Int = 8) -> Bool {
        var n = 0
        while !(element.exists && element.isHittable) && n < max {
            swipeUp()
            n += 1
        }
        return element.exists
    }
}
