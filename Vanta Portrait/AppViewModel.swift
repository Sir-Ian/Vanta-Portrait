import Foundation
import Combine
#if os(macOS)
import AppKit
#else
import UIKit
#endif
import CoreGraphics

enum ExperienceState: String {
    case idle
    case guiding
    case almostReady
    case capturing
    case revealing
    case resetting

    func canAdvance(to next: ExperienceState) -> Bool {
        switch (self, next) {
        case (.idle, .guiding),
             (.guiding, .almostReady),
             (.almostReady, .capturing),
             (.capturing, .revealing),
             (.revealing, .resetting),
             (.resetting, .idle):
            return true
        default:
            return false
        }
    }
}

final class AppViewModel: ObservableObject {
    @Published private(set) var experienceState: ExperienceState = .idle
    @Published var guidanceMessage: String = "Initializing…"
    @Published var guidanceState = GuidanceState()
    @Published var strictMode = true
    @Published var countdownValue: Int?
    @Published var showingResult = false
    @Published var bestImage: PlatformImage?
    @Published var showDebugPanel = false
    @Published var cameraWarning: String?
    @Published var isProcessingImage = false
    @Published var processingStatus: String?

    let cameraManager: CameraManager
    private let guidanceEngine = GuidanceEngine()
    private let stabilityTracker = StabilityTracker()
    private let imageGenerator: ImageGenerating
    private let isUITestMode: Bool
    private var cancellables = Set<AnyCancellable>()
    private var countdownTimer: Timer?
    private var poseAtCapture: PoseData?
    private var readinessSnapshot: Double?
    private var frozenGuidanceState: GuidanceState?
    private var frozenGuidanceMessage: String?
    private var lastEyeOpenTimestamp: Date?
    private let eyeOpenGraceWindow: TimeInterval = 0.3
    private let mockAzureSuccess = ProcessInfo.processInfo.arguments.contains("-MockAzureSuccess")
    private let mockAzureFailure = ProcessInfo.processInfo.arguments.contains("-MockAzureFailure")

    init(imageGenerator: ImageGenerating? = nil,
         cameraManager: CameraManager? = nil,
         uiTestMode: Bool = ProcessInfo.processInfo.arguments.contains("-UITestMode")) {
        self.isUITestMode = uiTestMode
        self.cameraManager = cameraManager ?? CameraManager(skipSetup: uiTestMode)
        if let generator = imageGenerator {
            self.imageGenerator = generator
        } else if uiTestMode, mockAzureFailure {
            self.imageGenerator = MockImageGenerator(result: .failure(ImageGenerationError.serviceError("Mock failure")))
        } else if uiTestMode || mockAzureSuccess {
            self.imageGenerator = MockImageGenerator(result: .success(Self.sampleProcessedImage()))
        } else {
            self.imageGenerator = ImageGenerationService(config: AzureImageConfig.fromEnvironment)
        }

        self.cameraManager.$poseData
            .receive(on: DispatchQueue.main)
            .sink { [weak self] pose in
                self?.handlePose(pose)
            }
            .store(in: &cancellables)

        self.cameraManager.$availability
            .receive(on: DispatchQueue.main)
            .sink { [weak self] availability in
                self?.cameraWarning = availability.message
                if availability == .ready {
                    self?.beginGuidingIfIdle()
                } else if self?.experienceState != .capturing {
                    self?.resetCountdownState()
                    self?.guidanceMessage = availability.message ?? "Camera unavailable"
                }
            }
            .store(in: &cancellables)

        if uiTestMode {
            let sample = Self.sampleImage()
            bestImage = sample
            showingResult = true
            experienceState = .revealing
            processCapturedImage(sample)
        }
    }

    func toggleStrictMode() {
        strictMode.toggle()
        handlePose(cameraManager.poseData)
    }

    func toggleDebugPanel() {
        showDebugPanel.toggle()
    }

    func attemptCapture() {
        guard experienceState == .almostReady else {
            if experienceState == .guiding {
                guidanceMessage = guidanceState.eyesOpen ? "Hold steady a moment" : "Open your eyes"
            }
            return
        }
        guard countdownValue == nil else { return }
        guard cameraManager.availability == .ready else {
            guidanceMessage = cameraWarning ?? "Camera not ready"
            return
        }
        startCountdown()
    }

    func retake() {
        guard experienceState == .revealing else {
            bestImage = nil
            showingResult = false
            return
        }
        advanceExperienceState(to: .resetting)
        performReset()
    }

    var countdownActive: Bool {
        experienceState == .almostReady && (countdownValue ?? 0) > 0
    }

    private func advanceExperienceState(to next: ExperienceState) {
        guard experienceState != next, experienceState.canAdvance(to: next) else { return }
        experienceState = next

        switch next {
        case .idle, .guiding, .almostReady, .capturing:
            showingResult = false
        case .revealing:
            showingResult = bestImage != nil
        case .resetting:
            showingResult = false
        }
    }

    private func beginGuidingIfIdle() {
        if experienceState == .idle {
            advanceExperienceState(to: .guiding)
        }
    }

    private func cancelCountdown() {
        guard experienceState != .capturing else { return }
        resetCountdownState()
    }

    private func startCountdown() {
        guard experienceState == .almostReady, countdownValue == nil else { return }
        frozenGuidanceState = guidanceState
        frozenGuidanceMessage = guidanceMessage
        readinessSnapshot = guidanceState.readinessScore
        countdownValue = 3
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            guard let self else { return }
            if let current = self.countdownValue, current > 1 {
                self.countdownValue = current - 1
            } else {
                timer.invalidate()
                self.countdownTimer = nil
                self.countdownValue = nil
                self.commitCapture()
            }
        }
    }

    private func commitCapture() {
        guard experienceState == .almostReady else { return }
        // EYE GATE: do not enter capturing if eyes are closed beyond blink grace.
        guard eyesRecentlyOpen else {
            abortCountdownForEyesClosed()
            return
        }

        poseAtCapture = cameraManager.poseData
        advanceExperienceState(to: .capturing)
        resetCountdownState()

        let burstCount = strictMode ? 5 : 3
        cameraManager.captureBurst(count: burstCount) { [weak self] images in
            guard let self else { return }
            self.evaluateBurst(images: images)
        }
    }

    private func evaluateBurst(images: [PlatformImage]) {
        guard experienceState == .capturing else { return }
        guard !images.isEmpty else {
            guidanceMessage = "Capture failed"
            advanceExperienceState(to: .revealing)
            bestImage = nil
            showingResult = false
            return
        }

        let pose = poseAtCapture
        let scores = images.enumerated().map { index, image -> (PlatformImage, Double) in
            guard let pose else {
                return (image, Double(index) * -0.01)
            }

            let centerScore = 1.0 - Double(abs(pose.horizontalOffset))
            let verticalScore = 1.0 - Double(abs(pose.verticalOffset))
            let tiltScore = 1.0 - min(1.0, abs(pose.headTilt) / 15.0)
            let combined = (centerScore * 0.4 + verticalScore * 0.35 + tiltScore * 0.25) - Double(index) * 0.01
            return (image, combined)
        }

        if let best = scores.max(by: { $0.1 < $1.1 })?.0 {
            bestImage = best
        } else {
            bestImage = images.first
        }

        advanceExperienceState(to: .revealing)
        if let best = bestImage {
            processCapturedImage(best)
        }
    }

    private func performReset() {
        cancelCountdown()
        bestImage = nil
        poseAtCapture = nil
        guidanceState = GuidanceState()
        guidanceMessage = "Initializing…"
        stabilityTracker.reset()
        cameraManager.resetCaptureBuffers()
        resetCountdownState()
        lastEyeOpenTimestamp = nil
        isProcessingImage = false
        processingStatus = nil
        advanceExperienceState(to: .idle)
    }

    private func handlePose(_ pose: PoseData?) {
        guard experienceState != .capturing,
              experienceState != .revealing,
              experienceState != .resetting else { return }

        guard cameraManager.availability == .ready else {
            guidanceState = GuidanceState()
            guidanceMessage = cameraWarning ?? "Camera unavailable"
            return
        }

        if countdownActive {
            if let frozenGuidanceState {
                guidanceState = frozenGuidanceState
            }
            if let frozenGuidanceMessage {
                guidanceMessage = frozenGuidanceMessage
            }
            if let snapshot = readinessSnapshot {
                guidanceState.readinessScore = snapshot
            }
            registerEyeOpen(from: pose)
            return
        }

        if let center = pose?.center {
            stabilityTracker.update(with: center)
        } else {
            stabilityTracker.update(with: nil)
        }

        let evaluation = guidanceEngine.evaluate(pose: pose,
                                                 stabilityTracker: stabilityTracker,
                                                 strictMode: strictMode)
        guidanceState = evaluation.0
        guidanceMessage = evaluation.1
        registerEyeOpen(from: pose)

        if experienceState == .idle {
            advanceExperienceState(to: .guiding)
        }

        // EYE GATE: block advancement into almostReady while eyes are closed.
        guard guidanceState.eyesOpen else {
            cancelCountdown()
            return
        }

        if experienceState == .guiding, guidanceState.readyForCapture {
            advanceExperienceState(to: .almostReady)
            startCountdown()
        } else if experienceState == .almostReady {
            if !guidanceState.readyForCapture {
                cancelCountdown()
            } else if countdownValue == nil {
                startCountdown()
            }
        }
    }

    var stabilityValue: CGFloat {
        stabilityTracker.stabilityValue
    }

    private func registerEyeOpen(from pose: PoseData?) {
        if pose?.eyesOpen == true {
            lastEyeOpenTimestamp = Date()
        }
    }

    private var eyesRecentlyOpen: Bool {
        if guidanceState.eyesOpen { return true }
        guard let last = lastEyeOpenTimestamp else { return false }
        return Date().timeIntervalSince(last) <= eyeOpenGraceWindow
    }

    private func resetCountdownState() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        countdownValue = nil
        frozenGuidanceState = nil
        frozenGuidanceMessage = nil
        readinessSnapshot = nil
    }

    private func abortCountdownForEyesClosed() {
        resetCountdownState()
        advanceExperienceState(to: .guiding)
    }

    private func processCapturedImage(_ image: PlatformImage) {
        guard !isProcessingImage else { return }
        isProcessingImage = true
        processingStatus = "Processing portrait…"

        Task {
            do {
                let generated = try await imageGenerator.generatePortrait(from: image)
                await MainActor.run {
                    self.bestImage = generated
                    self.processingStatus = nil
                    self.isProcessingImage = false
                }
            } catch {
                await MainActor.run {
                    self.processingStatus = "Couldn’t reach the portrait service. Using the original photo."
                    #if DEBUG
                    print("[AzureImage] generation failed: \(error)")
                    #endif
                    self.isProcessingImage = false
                }
            }
        }
    }

    private static func sampleImage() -> PlatformImage {
        #if os(macOS)
        let size = NSSize(width: 512, height: 512)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor(calibratedRed: 0.3, green: 0.5, blue: 0.9, alpha: 1).setFill()
        NSRect(origin: .zero, size: size).fill()
        image.unlockFocus()
        return image
        #else
        let size = CGSize(width: 512, height: 512)
        let renderer = UIGraphicsImageRenderer(size: size)
        let img = renderer.image { context in
            UIColor(red: 0.3, green: 0.5, blue: 0.9, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        return img
        #endif
    }

    private static func sampleProcessedImage() -> PlatformImage {
        #if os(macOS)
        let size = NSSize(width: 512, height: 512)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor(calibratedRed: 0.2, green: 0.7, blue: 0.4, alpha: 1).setFill()
        NSRect(origin: .zero, size: size).fill()
        image.unlockFocus()
        return image
        #else
        let size = CGSize(width: 512, height: 512)
        let renderer = UIGraphicsImageRenderer(size: size)
        let img = renderer.image { context in
            UIColor(red: 0.2, green: 0.7, blue: 0.4, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        return img
        #endif
    }

    private struct MockImageGenerator: ImageGenerating {
        let result: Result<PlatformImage, Error>
        func generatePortrait(from image: PlatformImage) async throws -> PlatformImage {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            switch result {
            case .success(let processed):
                return processed
            case .failure(let error):
                throw error
            }
        }
    }
}
