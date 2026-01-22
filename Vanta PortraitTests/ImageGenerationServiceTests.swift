import XCTest
@testable import Vanta_Portrait

@MainActor
final class ImageGenerationServiceTests: XCTestCase {
    private let endpoint = "https://aistudio-foundry-east-us-2.cognitiveservices.azure.com"
    private let deployment = "gpt-image-1.5"
    private let apiVersion = "2024-02-01"

    func testRequestShape() async throws {
        var handled = false
        let service = ImageGenerationService(
            config: AzureImageConfig(apiKey: "TEST_KEY", endpoint: endpoint, deployment: deployment, apiVersion: apiVersion),
            session: MockSession { request in
                handled = true
                XCTAssertEqual(request.url?.absoluteString, "\(self.endpoint)/openai/deployments/\(self.deployment)/images/generations?api-version=\(self.apiVersion)")
                XCTAssertEqual(request.httpMethod, "POST")
                XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
                XCTAssertEqual(request.value(forHTTPHeaderField: "api-key"), "TEST_KEY")

                if let body = request.vp_bodyData(),
                   let json = try? JSONSerialization.jsonObject(with: body, options: []) as? [String: Any] {
                    XCTAssertEqual(json["size"] as? String, "1024x1024")
                    XCTAssertNil(json["response_format"], "response_format should not be sent to Azure")
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
                return (data, response)
            }
        )

        _ = try await service.generatePortrait(from: Self.samplePlatformImage())
        XCTAssertTrue(handled)
    }

    func testSuccessDecodesImage() async throws {
        let service = makeServiceReturning(status: 200, body: ["data": [["b64_json": Self.sampleBase64()]]])
        let image = try await service.generatePortrait(from: Self.samplePlatformImage())
        XCTAssertNotNil(image)
    }

    func testUnauthorizedMaps() async {
        let service = makeServiceReturning(status: 401, body: ["error": ["message": "nope"]])
        await XCTAssertThrowsErrorAsync {
            _ = try await service.generatePortrait(from: Self.samplePlatformImage())
        } errorHandler: { error in
            guard case ImageGenerationError.unauthorizedOrForbidden = error else {
                XCTFail("Expected unauthorized, got \(error)")
                return
            }
        }
    }

    func testDecodeFailure() async {
        let service = makeServiceReturning(status: 200, body: ["data": [["b64_json": "%%%"]]])
        await XCTAssertThrowsErrorAsync {
            _ = try await service.generatePortrait(from: Self.samplePlatformImage())
        } errorHandler: { error in
            guard case ImageGenerationError.decodeFailed = error else {
                XCTFail("Expected decodeFailed, got \(error)")
                return
            }
        }
    }

    func testUnknownParameterMapsToClientSchemaError() async {
        let service = makeServiceReturning(status: 400, body: ["error": ["code": "unknown_parameter", "message": "response_format not supported"]])
        await XCTAssertThrowsErrorAsync {
            _ = try await service.generatePortrait(from: Self.samplePlatformImage())
        } errorHandler: { error in
            guard case ImageGenerationError.clientSchemaError = error else {
                XCTFail("Expected clientSchemaError, got \(error)")
                return
            }
        }
    }

    // MARK: - Helpers

    private func makeServiceReturning(status: Int, body: [String: Any]) -> ImageGenerationService {
        let response = HTTPURLResponse(url: URL(string: "\(endpoint)/openai/deployments/\(deployment)/images/generations?api-version=\(apiVersion)")!, statusCode: status, httpVersion: nil, headerFields: nil)!
        let data = try! JSONSerialization.data(withJSONObject: body, options: [])

        return ImageGenerationService(
            config: AzureImageConfig(apiKey: "TEST_KEY", endpoint: endpoint, deployment: deployment, apiVersion: apiVersion),
            session: MockSession { _ in (data, response) }
        )
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

private final class MockSession: URLSessioning {
    let handler: (URLRequest) throws -> (Data, URLResponse)
    init(handler: @escaping (URLRequest) throws -> (Data, URLResponse)) {
        self.handler = handler
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try handler(request)
    }
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

private extension URLRequest {
    func vp_bodyData() -> Data? {
        if let body = httpBody { return body }
        if let stream = httpBodyStream {
            return Data(reading: stream)
        }
        return nil
    }
}

private extension Data {
    init?(reading input: InputStream) {
        self.init()
        input.open()
        defer { input.close() }
        let bufferSize = 1024
        var buffer = [UInt8](repeating: 0, count: bufferSize)
        while input.hasBytesAvailable {
            let read = input.read(&buffer, maxLength: bufferSize)
            if read < 0 { return nil }
            if read == 0 { break }
            append(buffer, count: read)
        }
    }
}
