import Foundation
import Combine
#if os(macOS)
import AppKit
#else
import UIKit
#endif
import CoreGraphics

final class AppViewModel: ObservableObject {
    @Published var guidanceMessage: String = "Initializing…"
    @Published var guidanceState = GuidanceState()
    @Published var strictMode = true
    @Published var countdownValue: Int?
    @Published var showingResult = false
    @Published var bestImage: PlatformImage?
    @Published var showDebugPanel = false
    @Published var cameraWarning: String?
    
    private var wasReadyForCapture = false

    let cameraManager = CameraManager()

    private let guidanceEngine = GuidanceEngine()
    private let stabilityTracker = StabilityTracker()
    private var cancellables = Set<AnyCancellable>()
    private var countdownTimer: Timer?

    init() {
        cameraManager.$poseData
            .receive(on: DispatchQueue.main)
            .sink { [weak self] pose in
                self?.handlePose(pose)
            }
            .store(in: &cancellables)

        cameraManager.$availability
            .receive(on: DispatchQueue.main)
            .sink { [weak self] availability in
                self?.cameraWarning = availability.message
                if availability != .ready {
                    self?.cancelCountdown()
                    self?.guidanceMessage = availability.message ?? "Camera unavailable"
                }
            }
            .store(in: &cancellables)
    }

    func toggleStrictMode() {
        strictMode.toggle()
        handlePose(cameraManager.poseData)
    }

    func toggleDebugPanel() {
        showDebugPanel.toggle()
    }

    func attemptCapture() {
        guard countdownValue == nil else { return }
        guard cameraManager.availability == .ready else {
            guidanceMessage = cameraWarning ?? "Camera not ready"
            return
        }
        guard guidanceState.readyForCapture else {
            guidanceMessage = strictMode ? "Adjust your pose" : "Center yourself a bit more"
            return
        }
        startCountdown()
    }

    func retake() {
        showingResult = false
        bestImage = nil
        // Reset readiness tracking so auto-capture can trigger immediately when still aligned
        wasReadyForCapture = false
    }

    private func cancelCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        countdownValue = nil
    }

    private func startCountdown() {
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
                self.captureBurst()
            }
        }
    }

    private func captureBurst() {
        let burstCount = strictMode ? 5 : 3
        cameraManager.captureBurst(count: burstCount) { [weak self] images in
            guard let self else { return }
            self.evaluateBurst(images: images)
        }
    }

    private func evaluateBurst(images: [PlatformImage]) {
        guard !images.isEmpty else { return }
        guard let pose = cameraManager.poseData else {
            bestImage = images.first
            showingResult = true
            return
        }

        let scores = images.enumerated().map { index, image -> (PlatformImage, Double) in
            let centerScore = 1.0 - Double(abs(pose.horizontalOffset))
            let verticalScore = 1.0 - Double(abs(pose.verticalOffset))
            let tiltScore = 1.0 - min(1.0, abs(pose.headTilt) / 15.0)
            let combined = (centerScore * 0.4 + verticalScore * 0.4 + tiltScore * 0.2) - Double(index) * 0.01
            return (image, combined)
        }

        if let best = scores.max(by: { $0.1 < $1.1 })?.0 {
            bestImage = best
            showingResult = true
        }
    }

    private func handlePose(_ pose: PoseData?) {
        guard cameraManager.availability == .ready else {
            guidanceState = GuidanceState()
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

        let isReady = evaluation.0.readyForCapture

        // Auto-start countdown when transitioning into a ready state
        if isReady && !wasReadyForCapture && countdownValue == nil && !showingResult {
            startCountdown()
        }

        // Cancel countdown if readiness is lost
        if !isReady && countdownValue != nil {
            cancelCountdown()
            guidanceMessage = strictMode ? "Hold steady to capture" : "Stay centered to capture"
        }

        // Track previous readiness to detect transitions
        wasReadyForCapture = isReady
    }

    var stabilityValue: CGFloat {
        stabilityTracker.stabilityValue
    }
}
