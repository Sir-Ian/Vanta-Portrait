import Foundation
#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct AzureImageConfig {
    /// Inject the real key securely at runtime (env/Keychain). Placeholder only.
    let apiKey: String // e.g. "<AZURE_OPENAI_API_KEY>"
    let endpoint: String
    let deployment: String
    let apiVersion: String

    static var fromEnvironment: AzureImageConfig {
        let env = ProcessInfo.processInfo.environment
        let envKey = env["AZURE_OPENAI_API_KEY"]
        let key = envKey?.isEmpty == false && envKey != "<AZURE_OPENAI_API_KEY>" ? envKey! : AppSecrets.azureOpenAIKey
        return AzureImageConfig(
            apiKey: key,
            endpoint: "https://aistudio-foundry-east-us-2.cognitiveservices.azure.com",
            deployment: "gpt-image-1.5",
            apiVersion: "2024-02-01"
        )
    }
}

protocol ImageGenerating {
    func generatePortrait(from image: PlatformImage) async throws -> PlatformImage
}

enum ImageGenerationError: LocalizedError {
    case missingAPIKey
    case encodingFailed
    case dnsBlockedOrHostNotFound
    case noInternet
    case unauthorizedOrForbidden
    case invalidResponse
    case decodeFailed
    case serviceError(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "API key not configured"
        case .encodingFailed: return "Could not encode image"
        case .dnsBlockedOrHostNotFound: return "DNS lookup failed or host unreachable"
        case .noInternet: return "No internet connection"
        case .unauthorizedOrForbidden: return "Unauthorized request"
        case .invalidResponse: return "Invalid response"
        case .decodeFailed: return "Could not decode generated image"
        case .serviceError(let message): return message
        }
    }
}

final class ImageGenerationService: ImageGenerating {
    private let config: AzureImageConfig
    private let session: URLSession
    private let prompt: String = """
Using the provided image of the subject as reference, create a clean, realistic studio portrait inspired by the visual conventions of new-graduate job-hunting photos. If a person is present, preserve the subject's facial features, proportions, and identity exactly as shown, without beautifying or altering their face. If not, if not, apply the same restrained studio lighting, neutral background, and formal framing to the object or scene. Present the subject in a centered, front-facing composition wearing conservative, entry-level business attire, with neat grooming and a neutral, polite expression. Use flat, even studio lighting that minimizes shadows and emphasizes clarity, paired with a plain light blue, pale gray, or white background. The framing should be tightly cropped, symmetrical, and formal, with a restrained, slightly earnest mood that reflects professionalism, sincerity, and readiness for a job.
"""

    init(config: AzureImageConfig, session: URLSession? = nil) {
        self.config = config
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.default
            configuration.timeoutIntervalForRequest = 60
            configuration.timeoutIntervalForResource = 60
            self.session = URLSession(configuration: configuration)
        }
    }

    func generatePortrait(from image: PlatformImage) async throws -> PlatformImage {
        guard !config.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("<") else {
            throw ImageGenerationError.missingAPIKey
        }

        guard let imageData = image.azureJPEGData(compressionQuality: 0.9) ?? image.azurePNGData() else {
            throw ImageGenerationError.encodingFailed
        }
        let base64Image = imageData.base64EncodedString()

        guard let url = URL(string: "\(config.endpoint)/openai/deployments/\(config.deployment)/images/generations?api-version=\(config.apiVersion)") else {
            throw ImageGenerationError.invalidResponse
        }

        var request = URLRequest(url: url, timeoutInterval: 60)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.apiKey, forHTTPHeaderField: "api-key")

        let body: [String: Any] = [
            "prompt": prompt,
            "image": [base64Image],
            "size": "1024x1024",
            "response_format": "base64_json"
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            throw mapURLError(error)
        } catch {
            throw ImageGenerationError.invalidResponse
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ImageGenerationError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            let bodyPreview = String(data: data, encoding: .utf8) ?? ""
            debugPrint("[AzureImage] HTTP \(httpResponse.statusCode) body: \(bodyPreview)")
            switch httpResponse.statusCode {
            case 401, 403:
                throw ImageGenerationError.unauthorizedOrForbidden
            default:
                if let message = AzureServiceError.decodeMessage(from: data) {
                    throw ImageGenerationError.serviceError(message)
                } else {
                    throw ImageGenerationError.invalidResponse
                }
            }
        }

        let decoded: ImageGenerationResponse
        do {
            decoded = try JSONDecoder().decode(ImageGenerationResponse.self, from: data)
        } catch {
            throw ImageGenerationError.invalidResponse
        }
        guard let base64 = decoded.data.first?.b64_json,
              let resultData = Data(base64Encoded: base64),
              let resultImage = PlatformImage.azureInit(data: resultData) else {
            throw ImageGenerationError.decodeFailed
        }

        return resultImage
    }

    private func mapURLError(_ error: URLError) -> ImageGenerationError {
        switch error.code {
        case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
            return .dnsBlockedOrHostNotFound
        case .notConnectedToInternet:
            return .noInternet
        case .timedOut:
            return .serviceError("Request timed out")
        default:
            return .invalidResponse
        }
    }
}

private struct ImageGenerationResponse: Decodable {
    struct DataItem: Decodable {
        let b64_json: String?
    }

    let data: [DataItem]
}

private enum AzureServiceError {
    struct ErrorPayload: Decodable {
        struct InnerError: Decodable { let message: String? }
        let error: InnerError?
    }

    static func decodeMessage(from data: Data) -> String? {
        guard let decoded = try? JSONDecoder().decode(ErrorPayload.self, from: data) else { return nil }
        return decoded.error?.message
    }
}

private extension PlatformImage {
    func azureJPEGData(compressionQuality: CGFloat) -> Data? {
        #if os(macOS)
        guard let tiff = tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
        return bitmap.representation(using: .jpeg, properties: [.compressionFactor: compressionQuality])
        #else
        return self.jpegData(compressionQuality: compressionQuality)
        #endif
    }

    func azurePNGData() -> Data? {
        #if os(macOS)
        guard let tiff = tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
        #else
        return self.pngData()
        #endif
    }

    static func azureInit(data: Data) -> PlatformImage? {
        #if os(macOS)
        return NSImage(data: data)
        #else
        return UIImage(data: data)
        #endif
    }
}
