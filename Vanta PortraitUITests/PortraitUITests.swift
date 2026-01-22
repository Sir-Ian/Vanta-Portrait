import XCTest

final class PortraitUITests: XCTestCase {
    func testProcessingSuccessShowsResult() {
        let filename = statusFilename()
        let statusURL = containerCachesURL(for: filename)
        let app = XCUIApplication()
        app.launchArguments += ["-UITestMode", "-MockAzureSuccess"]
        app.launchEnvironment["UITestStatusFile"] = filename
        app.launch()

        XCTAssertNotNil(waitForStatus(at: statusURL, timeout: 2) { $0.note == "processing" })

        let finalStatus = waitForStatus(at: statusURL, timeout: 5) {
            $0.note == "processed" && $0.imageTag == "processed" && $0.processingStatus == nil && $0.isProcessing == false
        }
        XCTAssertNotNil(finalStatus, "Processed status not observed")
    }

    func testProcessingFailureShowsFallbackMessage() {
        let filename = statusFilename()
        let statusURL = containerCachesURL(for: filename)
        let app = XCUIApplication()
        app.launchArguments += ["-UITestMode", "-MockAzureFailure"]
        app.launchEnvironment["UITestStatusFile"] = filename
        app.launch()

        XCTAssertNotNil(waitForStatus(at: statusURL, timeout: 2) { $0.note == "processing" })

        let fallbackStatus = waitForStatus(at: statusURL, timeout: 5) {
            $0.note == "fallback" && $0.imageTag == "original" && $0.processingStatus == "Couldn’t reach the portrait service. Using the original photo."
        }
        XCTAssertNotNil(fallbackStatus, "Fallback status not observed")
    }

    // MARK: - Helpers

    private func waitForStatus(at url: URL, timeout: TimeInterval, predicate: (UITestStatusPayload) -> Bool) -> UITestStatusPayload? {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let data = try? Data(contentsOf: url),
               let status = try? JSONDecoder().decode(UITestStatusPayload.self, from: data),
               predicate(status) {
                return status
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        return nil
    }

    private func statusFilename() -> String {
        "uitest-status-\(UUID().uuidString).json"
    }

    private func containerCachesURL(for filename: String) -> URL {
        let base = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Containers/com.Pro.Vanta-Portrait/Data")
        return base.appendingPathComponent(filename)
    }
}

private struct UITestStatusPayload: Codable {
    let note: String
    let processingStatus: String?
    let isProcessing: Bool
    let imageTag: String?
}
