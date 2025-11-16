import SwiftUI
import AVFoundation

struct CameraPreviewView: NSViewRepresentable {
    @ObservedObject var manager: CameraManager

    func makeNSView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = manager.session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateNSView(_ nsView: PreviewView, context: Context) {
        nsView.videoPreviewLayer.session = manager.session
    }
}

final class PreviewView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer = AVCaptureVideoPreviewLayer()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }
}
