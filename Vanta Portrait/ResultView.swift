import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
import Photos
#endif

struct ResultView: View {
    let image: PlatformImage
    let onRetake: () -> Void
    let onSave: (URL?) -> Void

    @State private var saveMessage: String?
    @State private var saveError: Bool = false

    var body: some View {
        VStack(spacing: 16) {
            Image(platformImage: image)
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
                    saveImage()
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

    private func saveImage() {
        #if os(macOS)
        do {
            let url = try saveToPicturesMacOS()
            onSave(url)
            saveMessage = "Saved to \(url.lastPathComponent)"
            saveError = false
        } catch {
            saveMessage = "Failed to save: \(error.localizedDescription)"
            saveError = true
        }
        #else
        saveToPhotosLibraryIOS()
        #endif
    }

    #if os(macOS)
    private func saveToPicturesMacOS() throws -> URL {
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
    #else
    private func saveToPhotosLibraryIOS() {
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async {
                    saveMessage = "Photos access denied"
                    saveError = true
                }
                return
            }
            
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            } completionHandler: { success, error in
                DispatchQueue.main.async {
                    if success {
                        saveMessage = "Saved to Photos"
                        saveError = false
                        onSave(nil)
                    } else {
                        saveMessage = "Failed to save: \(error?.localizedDescription ?? "Unknown error")"
                        saveError = true
                    }
                }
            }
        }
    }
    #endif
    
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
