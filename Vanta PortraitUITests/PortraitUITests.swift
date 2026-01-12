import XCTest

@MainActor
final class PortraitUITests: XCTestCase {
    func testProcessingSuccessShowsResult() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-UITestMode", "-MockAzureSuccess"]
        app.launch()

        let processing = app.staticTexts["Processing portrait…"]
        XCTAssertTrue(processing.waitForExistence(timeout: 2))

        // After mock completes, processing message should clear
        let cleared = processing.waitForDisappearance(timeout: 5)
        XCTAssertTrue(cleared, "Processing message did not clear")
    }

    func testProcessingFailureShowsFallbackMessage() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-UITestMode", "-MockAzureFailure"]
        app.launch()

        let processing = app.staticTexts["Processing portrait…"]
        XCTAssertTrue(processing.waitForExistence(timeout: 2))

        let fallback = app.staticTexts["Couldn’t reach the portrait service. Using the original photo."]
        XCTAssertTrue(fallback.waitForExistence(timeout: 5))
    }
}

private extension XCUIElement {
    func waitForDisappearance(timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }
}
