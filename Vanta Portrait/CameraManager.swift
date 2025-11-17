import Foundation
import AVFoundation
import Vision
import Combine
import AppKit

final class CameraManager: NSObject, ObservableObject {
    let session = AVCaptureSession()

    @Published var poseData: PoseData?
    @Published var lastCaptureDate: Date?
    @Published var countdownActive = false
    @Published var availability: CameraAvailability = .unknown

    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private let sampleBufferQueue = DispatchQueue(label: "camera.sample.queue")
    private lazy var photoDelegate = PhotoCaptureDelegate(owner: self)
    private lazy var videoDelegate = VideoDataDelegate(owner: self)

    private var burstImages: [NSImage] = []
    private var burstCompletion: (([NSImage]) -> Void)?
    private var expectedBurstCount = 0
    private var processedBurstCount = 0
    private var isConfigured = false

    override init() {
        super.init()
        requestCameraAccessIfNeeded()
    }

    private func requestCameraAccessIfNeeded() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            Task { @MainActor in
                self.configureSession()
            }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard let self else { return }
                if granted {
                    Task { @MainActor in
                        self.configureSession()
                    }
                } else {
                    print("Camera access was denied by the user.")
                    Task { @MainActor in
                        self.availability = .denied
                    }
                }
            }
        default:
            print("Camera access not granted. Update privacy permissions to capture photos.")
            availability = .denied
        }
    }

    @MainActor
    private func configureSession() {
        let videoDelegate = self.videoDelegate
        let sampleBufferQueue = self.sampleBufferQueue
        sessionQueue.async { [weak self] in
            guard let self, !self.isConfigured else { return }

            self.session.beginConfiguration()
            self.session.sessionPreset = .high

            guard let device = AVCaptureDevice.default(for: .video) else {
                self.session.commitConfiguration()
                DispatchQueue.main.async {
                    self.availability = .noDevice
                }
                return
            }

            do {
                let input = try AVCaptureDeviceInput(device: device)
                guard self.session.canAddInput(input) else {
                    self.session.commitConfiguration()
                    DispatchQueue.main.async {
                        self.availability = .configurationFailed("Cannot add camera input to session.")
                    }
                    return
                }
                self.session.addInput(input)
            } catch {
                print("Unable to create camera input: \(error.localizedDescription)")
                self.session.commitConfiguration()
                DispatchQueue.main.async {
                    self.availability = .configurationFailed("Failed to open the camera: \(error.localizedDescription)")
                }
                return
            }

            if self.session.canAddOutput(self.photoOutput) {
                self.session.addOutput(self.photoOutput)
                if #available(macOS 13.0, iOS 16.0, *) {
                    // On newer OS versions, default max dimensions are fine; no explicit setting needed here.
                } else {
                    self.photoOutput.isHighResolutionCaptureEnabled = true
                }
            }

            if self.session.canAddOutput(self.videoOutput) {
                self.videoOutput.alwaysDiscardsLateVideoFrames = true
                self.videoOutput.setSampleBufferDelegate(videoDelegate, queue: sampleBufferQueue)
                self.session.addOutput(self.videoOutput)
            }

            self.session.commitConfiguration()
            self.isConfigured = true
            DispatchQueue.main.async {
                self.availability = .ready
            }
            self.session.startRunning()
        }
    }

    @MainActor
    func captureBurst(count: Int = 3, completion: @escaping ([NSImage]) -> Void) {
        guard count > 0 else {
            completion([])
            return
        }
        guard burstCompletion == nil else { return }

        burstImages = []
        expectedBurstCount = count
        processedBurstCount = 0
        burstCompletion = completion

        let photoDelegate = self.photoDelegate
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard self.isConfigured else {
                self.failBurstCapture(reason: "Camera session is not configured.")
                return
            }
            guard self.session.isRunning else {
                self.failBurstCapture(reason: "Camera session is not running.")
                return
            }
            guard self.photoOutput.connection(with: .video) != nil else {
                self.failBurstCapture(reason: "Photo output has no active video connection.")
                return
            }

            for _ in 0..<count {
                let settings = AVCapturePhotoSettings()
                if #available(macOS 13.0, iOS 16.0, *) {
                    // Use default settings; maxPhotoDimensions API isn't available on older SDKs in this project.
                } else {
                    settings.isHighResolutionPhotoEnabled = true
                }
                self.photoOutput.capturePhoto(with: settings, delegate: photoDelegate)
            }
        }
    }

    fileprivate func publishPose(_ pose: PoseData?) {
        poseData = pose
    }

    fileprivate func didProcessPhoto(image: NSImage?, error: Error?) {
        processedBurstCount += 1

        if let error {
            print("Photo capture error: \(error.localizedDescription)")
        }

        if let image {
            burstImages.append(image)
        }

        completeBurstIfNeeded()
    }

    private func completeBurstIfNeeded() {
        guard expectedBurstCount > 0,
              processedBurstCount >= expectedBurstCount else { return }

        let images = burstImages
        resetBurstState()
        lastCaptureDate = Date()
        burstCompletion?(images)
        burstCompletion = nil
    }

    private func resetBurstState() {
        burstImages = []
        expectedBurstCount = 0
        processedBurstCount = 0
    }

    private func failBurstCapture(reason: String) {
        print("Burst capture aborted: \(reason)")
        Task { @MainActor [weak self] in
            guard let self else { return }
            let completion = self.burstCompletion
            self.resetBurstState()
            self.burstCompletion = nil
            completion?([])
        }
    }
}

enum CameraAvailability: Equatable {
    case unknown
    case ready
    case noDevice
    case denied
    case configurationFailed(String)

    var message: String? {
        switch self {
        case .unknown, .ready:
            return nil
        case .noDevice:
            return "No compatible camera was found. Connect a webcam and restart the app."
        case .denied:
            return "Camera permission is denied. Enable access in System Settings → Privacy & Security → Camera."
        case .configurationFailed(let reason):
            return "Camera could not be initialized: \(reason)"
        }
    }
}

private final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    weak var owner: CameraManager?

    init(owner: CameraManager) {
        self.owner = owner
    }

    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let data = photo.fileDataRepresentation()
        Task { @MainActor [weak self] in
            guard let owner = self?.owner else { return }
            let image = data.flatMap { NSImage(data: $0) }
            owner.didProcessPhoto(image: image, error: error)
        }
    }
}

private final class VideoDataDelegate: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    weak var owner: CameraManager?
    private struct PixelBufferBox: @unchecked Sendable {
        let buffer: CVImageBuffer
    }
    private let poseDetector = PoseDetector()
    private let processingQueue = DispatchQueue(label: "pose.processing.queue")

    init(owner: CameraManager) {
        self.owner = owner
    }

    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let box = PixelBufferBox(buffer: pixelBuffer)
        processingQueue.async { [weak self, box] in
            guard let self else { return }
            self.poseDetector.process(pixelBuffer: box.buffer) { pose in
                Task { @MainActor in
                    self.owner?.publishPose(pose)
                }
            }
        }
    }
}
