import SwiftUI
import AVFoundation

struct CameraPreviewView: PlatformViewRepresentable {
    @ObservedObject var manager: CameraManager

    #if os(macOS)
    func makeNSView(context: Context) -> PreviewView {
        createPreviewView()
    }

    func updateNSView(_ nsView: PreviewView, context: Context) {
        updatePreviewView(nsView)
    }
    #else
    func makeUIView(context: Context) -> PreviewView {
        createPreviewView()
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        updatePreviewView(uiView)
    }
    #endif

    private func createPreviewView() -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = manager.session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    private func updatePreviewView(_ view: PreviewView) {
        view.videoPreviewLayer.session = manager.session
    }
}

#if os(macOS)
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
#else
import UIKit
final class PreviewView: UIView {
    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }

    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }
}
#endif
