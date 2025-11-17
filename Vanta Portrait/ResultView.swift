import SwiftUI
import AppKit

struct ResultView: View {
    let image: NSImage
    let onRetake: () -> Void
    let onSave: (URL) -> Void

    @State private var saveMessage: String?
    @State private var saveError: Bool = false

    var body: some View {
        VStack(spacing: 16) {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .cornerRadius(12)
                .shadow(radius: 8)
                .padding()

            HStack(spacing: 20) {
                Button("Retake", action: onRetake)
                    .buttonStyle(.bordered)
                    .keyboardShortcut("r", modifiers: .command)
                
                Button("Save to Pictures") {
                    do {
                        let url = try saveToPictures()
                        onSave(url)
                        saveMessage = "Saved to \(url.lastPathComponent)"
                        saveError = false
                    } catch {
                        saveMessage = "Failed to save: \(error.localizedDescription)"
                        saveError = true
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut("s", modifiers: .command)
            }

            if let saveMessage {
                Text(saveMessage)
                    .font(.footnote)
                    .foregroundStyle(saveError ? .red : .secondary)
            }
        }
        .padding()
    }

    private func saveToPictures() throws -> URL {
        guard let pictures = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first else {
            throw SaveError.directoryNotFound
        }
        
        let filename = "VantaPortrait-\(Date().formatted(.iso8601.year().month().day().time(includingFractionalSeconds: false))).jpg"
        let url = pictures.appendingPathComponent(filename)
        
        guard let tiff = image.tiffRepresentation else {
            throw SaveError.imageConversionFailed
        }
        
        guard let bitmap = NSBitmapImageRep(data: tiff) else {
            throw SaveError.bitmapCreationFailed
        }
        
        guard let data = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.9]) else {
            throw SaveError.jpegCreationFailed
        }
        
        try data.write(to: url, options: .atomic)
        return url
    }
    
    enum SaveError: LocalizedError {
        case directoryNotFound
        case imageConversionFailed
        case bitmapCreationFailed
        case jpegCreationFailed
        
        var errorDescription: String? {
            switch self {
            case .directoryNotFound:
                return "Could not find Pictures directory"
            case .imageConversionFailed:
                return "Failed to convert image"
            case .bitmapCreationFailed:
                return "Failed to create bitmap"
            case .jpegCreationFailed:
                return "Failed to create JPEG"
            }
        }
    }
}
