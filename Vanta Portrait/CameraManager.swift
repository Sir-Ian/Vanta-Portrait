import Foundation
import AVFoundation
import Vision
import Combine
#if os(macOS)
import AppKit
#else
import UIKit
#endif

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

    private var burstImages: [PlatformImage] = []
    private var burstCompletion: (([PlatformImage]) -> Void)?
    private var expectedBurstCount = 0
    private var processedBurstCount = 0
    private var isConfigured = false
    private let burstLock = NSLock() // Thread-safe burst state access

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

            #if os(iOS)
            // Prefer front camera on iOS
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) ?? AVCaptureDevice.default(for: .video)
            #else
            let device = AVCaptureDevice.default(for: .video)
            #endif
            
            guard let device else {
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
                    if let maxDims = device.activeFormat.supportedMaxPhotoDimensions.last {
                        self.photoOutput.maxPhotoDimensions = maxDims
                    }
                } else {
                    self.photoOutput.isHighResolutionCaptureEnabled = true
                }
            }

            if self.session.canAddOutput(self.videoOutput) {
                self.videoOutput.alwaysDiscardsLateVideoFrames = true
                self.videoOutput.setSampleBufferDelegate(videoDelegate, queue: sampleBufferQueue)
                self.session.addOutput(self.videoOutput)
                
                #if os(iOS)
                // Ensure correct orientation for Vision on iOS
                if let connection = self.videoOutput.connection(with: .video) {
                    if connection.isVideoOrientationSupported {
                        connection.videoOrientation = .portrait
                    }
                    if connection.isVideoMirroringSupported {
                        connection.isVideoMirrored = true
                    }
                }
                #endif
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
    func captureBurst(count: Int = 3, completion: @escaping ([PlatformImage]) -> Void) {
        guard count > 0 else {
            completion([])
            return
        }
        
        burstLock.lock()
        guard burstCompletion == nil else {
            burstLock.unlock()
            return
        }

        burstImages = []
        expectedBurstCount = count
        processedBurstCount = 0
        burstCompletion = completion
        burstLock.unlock()

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
                    settings.maxPhotoDimensions = self.photoOutput.maxPhotoDimensions
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

    fileprivate func didProcessPhoto(image: PlatformImage?, error: Error?) {
        burstLock.lock()
        defer { burstLock.unlock() }
        
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
        // Must be called with burstLock held
        guard expectedBurstCount > 0,
              processedBurstCount >= expectedBurstCount else { return }

        let images = burstImages
        let completion = burstCompletion
        resetBurstState()
        
        // Release lock before calling completion
        burstLock.unlock()
        
        Task { @MainActor [weak self] in
            self?.lastCaptureDate = Date()
            completion?(images)
        }
        
        burstLock.lock() // Re-acquire for defer statement
    }

    private func resetBurstState() {
        // Must be called with burstLock held
        burstImages = []
        expectedBurstCount = 0
        processedBurstCount = 0
        burstCompletion = nil
    }

    private func failBurstCapture(reason: String) {
        print("Burst capture aborted: \(reason)")
        burstLock.lock()
        let completion = self.burstCompletion
        resetBurstState()
        burstLock.unlock()
        
        Task { @MainActor in
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
            let image = data.flatMap { PlatformImage(data: $0) }
            owner.didProcessPhoto(image: image, error: error)
        }
    }
}

private final class VideoDataDelegate: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    weak var owner: CameraManager?
    private let poseDetector = PoseDetector()
    private let processingQueue = DispatchQueue(label: "pose.processing.queue")

    init(owner: CameraManager) {
        self.owner = owner
    }

    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        // Retain the pixel buffer for safe async processing
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        
        struct SendableBuffer: @unchecked Sendable {
            let buffer: CVPixelBuffer
        }
        let sendableBuffer = SendableBuffer(buffer: pixelBuffer)
        
        processingQueue.async { [weak self] in
            let pixelBuffer = sendableBuffer.buffer
            guard let self else {
                CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
                return
            }
            
            #if os(iOS)
            let orientation: CGImagePropertyOrientation = .leftMirrored // Front camera usually needs this
            #else
            let orientation: CGImagePropertyOrientation = .up
            #endif
            
            self.poseDetector.process(pixelBuffer: pixelBuffer, orientation: orientation) { pose in
                CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
                Task { @MainActor in
                    self.owner?.publishPose(pose)
                }
            }
        }
    }
}
