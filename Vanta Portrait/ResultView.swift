import SwiftUI
import AppKit

struct ResultView: View {
    let image: NSImage
    let onRetake: () -> Void
    let onSave: (URL) -> Void

    @State private var saveMessage: String?

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
                Button("Save to Pictures") {
                    let url = saveToPictures()
                    onSave(url)
                    saveMessage = "Saved to \(url.path)"
                }
                .buttonStyle(.borderedProminent)
            }

            if let saveMessage {
                Text(saveMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }

    private func saveToPictures() -> URL {
        let pictures = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let filename = "VantaPortrait-\(Int(Date().timeIntervalSince1970)).jpg"
        let url = pictures.appendingPathComponent(filename)
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let data = bitmap.representation(using: .jpeg, properties: [:]) else {
            return url
        }
        try? data.write(to: url)
        return url
    }
}
