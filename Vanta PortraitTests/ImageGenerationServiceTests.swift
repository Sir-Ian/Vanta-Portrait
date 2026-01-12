import XCTest
@testable import Vanta_Portrait

@MainActor
final class ImageGenerationServiceTests: XCTestCase {
    private let endpoint = "https://aistudio-foundry-east-us-2.cognitiveservices.azure.com"
    private let deployment = "gpt-image-1.5"
    private let apiVersion = "2024-02-01"

    func testRequestShape() async throws {
        let protocolClass = StubURLProtocol.self
        let session = URLSession(configuration: .ephemeral)
        session.configuration.protocolClasses = [protocolClass]

        let service = ImageGenerationService(
            config: AzureImageConfig(apiKey: "TEST_KEY", endpoint: endpoint, deployment: deployment, apiVersion: apiVersion),
            session: session
        )

        let expectation = expectation(description: "request captured")
        protocolClass.requestHandler = { request in
            XCTAssertEqual(request.url?.absoluteString, "\(self.endpoint)/openai/deployments/\(self.deployment)/images/generations?api-version=\(self.apiVersion)")
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
            XCTAssertEqual(request.value(forHTTPHeaderField: "api-key"), "TEST_KEY")

            if let body = request.httpBody,
               let json = try? JSONSerialization.jsonObject(with: body, options: []) as? [String: Any] {
                XCTAssertEqual(json["size"] as? String, "1024x1024")
                XCTAssertEqual(json["response_format"] as? String, "base64_json")
                XCTAssertNotNil(json["prompt"] as? String)
                if let images = json["image"] as? [String] {
                    XCTAssertEqual(images.count, 1)
                    XCTAssertFalse(images[0].isEmpty)
                } else {
                    XCTFail("image array missing")
                }
            } else {
                XCTFail("Missing body")
            }

            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let payload = ["data": [["b64_json": Self.sampleBase64()]]]
            let data = try! JSONSerialization.data(withJSONObject: payload, options: [])
            expectation.fulfill()
            return (response, data)
        }

        _ = try await service.generatePortrait(from: Self.samplePlatformImage())
        await fulfillment(of: [expectation], timeout: 2)
    }

    func testSuccessDecodesImage() async throws {
        let (service, expectation) = try makeServiceReturning(status: 200, body: ["data": [["b64_json": Self.sampleBase64()]]])
        let image = try await service.generatePortrait(from: Self.samplePlatformImage())
        XCTAssertNotNil(image)
        await fulfillment(of: [expectation], timeout: 2)
    }

    func testUnauthorizedMaps() async {
        let (service, expectation) = try! makeServiceReturning(status: 401, body: ["error": ["message": "nope"]])
        await XCTAssertThrowsErrorAsync {
            _ = try await service.generatePortrait(from: Self.samplePlatformImage())
        } errorHandler: { error in
            print("Unauthorized test error: \(error)")
            defer { expectation.fulfill() }
            guard case ImageGenerationError.unauthorizedOrForbidden = error else {
                XCTFail("Expected unauthorized, got \(error)")
                return
            }
        }
        await fulfillment(of: [expectation], timeout: 2)
    }

    func testDecodeFailure() async {
        let (service, expectation) = try! makeServiceReturning(status: 200, body: ["data": [["b64_json": "%%%"]]])
        await XCTAssertThrowsErrorAsync {
            _ = try await service.generatePortrait(from: Self.samplePlatformImage())
        } errorHandler: { error in
            print("Decode failure error: \(error)")
            defer { expectation.fulfill() }
            guard case ImageGenerationError.decodeFailed = error else {
                XCTFail("Expected decodeFailed, got \(error)")
                return
            }
        }
        await fulfillment(of: [expectation], timeout: 2)
    }

    // MARK: - Helpers

    private func makeServiceReturning(status: Int, body: [String: Any]) throws -> (ImageGenerationService, XCTestExpectation) {
        let protocolClass = StubURLProtocol.self
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [protocolClass]
        let session = URLSession(configuration: configuration)

        let expectation = expectation(description: "request handled")
        protocolClass.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
            let data = try! JSONSerialization.data(withJSONObject: body, options: [])
            expectation.fulfill()
            return (response, data)
        }

        let service = ImageGenerationService(
            config: AzureImageConfig(apiKey: "TEST_KEY", endpoint: endpoint, deployment: deployment, apiVersion: apiVersion),
            session: session
        )
        return (service, expectation)
    }

    private static func sampleBase64() -> String {
        return "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Y1YVxkAAAAASUVORK5CYII="
    }

    private static func samplePlatformImage() -> PlatformImage {
        #if os(macOS)
        let size = NSSize(width: 10, height: 10)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.red.setFill()
        NSRect(origin: .zero, size: size).fill()
        image.unlockFocus()
        return image
        #else
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10))
        return renderer.image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 10, height: 10))
        }
        #endif
    }
}

final class StubURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = StubURLProtocol.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

extension XCTestCase {
    func XCTAssertThrowsErrorAsync<T>(_ expression: @escaping () async throws -> T, errorHandler: @escaping (Error) -> Void) async {
        do {
            _ = try await expression()
            XCTFail("Expected throw")
        } catch {
            errorHandler(error)
        }
    }
}
