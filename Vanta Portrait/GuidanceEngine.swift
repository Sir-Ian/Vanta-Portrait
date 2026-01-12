import Foundation
import CoreGraphics

struct GuidanceState {
    var centered: Bool = false
    var verticalAligned: Bool = false
    var leveled: Bool = false
    var eyesOpen: Bool = false
    var isStable: Bool = false
    var readyForCapture: Bool = false
    var headTilt: Double = 0
    var horizontalOffset: CGFloat = 0
    var verticalOffset: CGFloat = 0
    var readinessScore: Double = 0
}

final class GuidanceEngine {
    // Thresholds
    private let strictHorizontalThreshold: CGFloat = 0.08
    private let flexibleHorizontalThreshold: CGFloat = 0.16
    private let strictVerticalThreshold: CGFloat = 0.1 // Looser vertical framing
    private let flexibleVerticalThreshold: CGFloat = 0.2
    private let strictTiltThreshold: Double = 8
    private let flexibleTiltThreshold: Double = 14
    private let strictYawThreshold: Double = 14 // Degrees
    private let flexibleYawThreshold: Double = 24
    
    // Headshot Framing (Face Area Ratio)
    private let minFaceAreaRatio: CGFloat = 0.08
    private let maxFaceAreaRatio: CGFloat = 0.38

    private let readinessThresholdStrict: Double = 0.7
    private let readinessThresholdFlexible: Double = 0.55

    func evaluate(pose: PoseData?, stabilityTracker: StabilityTracker, strictMode: Bool) -> (GuidanceState, String) {
        guard let pose else {
            return (GuidanceState(), "Looking for your face…")
        }

        let horizontalThreshold = strictMode ? strictHorizontalThreshold : flexibleHorizontalThreshold
        let verticalThreshold = strictMode ? strictVerticalThreshold : flexibleVerticalThreshold
        let tiltThreshold = strictMode ? strictTiltThreshold : flexibleTiltThreshold
        let yawThreshold = strictMode ? strictYawThreshold : flexibleYawThreshold

        // 1. Center Check
        let centered = abs(pose.horizontalOffset) < horizontalThreshold
        // For headshots, eyes should be slightly above center (Rule of Thirds). 
        // verticalOffset is (y - 0.5). If y is 0.4 (above center), offset is -0.1.
        // Let's target -0.1 to 0.0 range.
        let targetVerticalOffset: CGFloat = -0.05
        let verticalDiff = pose.verticalOffset - targetVerticalOffset
        let verticalAligned = abs(verticalDiff) < verticalThreshold
        
        // 2. Orientation Check
        let leveled = abs(pose.headTilt) < tiltThreshold
        let facingForward = abs(pose.headYaw) < yawThreshold
        let eyesOpen = pose.eyesOpen

        // 3. Distance Check (Framing)
        let faceArea = pose.boundingBox.width * pose.boundingBox.height
        let distanceOk = faceArea >= minFaceAreaRatio && faceArea <= maxFaceAreaRatio
        
        // 4. Stability
        let stable = stabilityTracker.isStable(strict: strictMode)
        let stabilityScore = stabilityTracker.stabilityConfidence(strict: strictMode)

        // Confidence signals (non-eye constraints)
        let centerScore = score(for: pose.horizontalOffset, limit: horizontalThreshold)
        let verticalScore = score(for: verticalDiff, limit: verticalThreshold)
        let tiltScore = score(for: pose.headTilt, limit: tiltThreshold)
        let yawScore = score(for: pose.headYaw, limit: yawThreshold)
        let distanceScore = distanceConfidence(for: faceArea)

        let readinessScore = centerScore * 0.24
                        + verticalScore * 0.14
                        + tiltScore * 0.14
                        + yawScore * 0.12
                        + distanceScore * 0.18
                        + stabilityScore * 0.18
        let readinessThreshold = strictMode ? readinessThresholdStrict : readinessThresholdFlexible

        var state = GuidanceState(centered: centered,
                                  verticalAligned: verticalAligned,
                                  leveled: leveled,
                                  eyesOpen: eyesOpen,
                                  isStable: stable,
                                  readyForCapture: false,
                                  headTilt: pose.headTilt,
                                  horizontalOffset: pose.horizontalOffset,
                                  verticalOffset: pose.verticalOffset,
                                  readinessScore: readinessScore)

        state.readyForCapture = eyesOpen && readinessScore >= readinessThreshold

        let message: String
        if !eyesOpen {
            message = "Open your eyes"
        } else if !distanceOk {
            message = faceArea < minFaceAreaRatio ? "Move closer" : "Move back"
        } else if !centered {
            message = pose.horizontalOffset > 0 ? "Move left" : "Move right"
        } else if !verticalAligned {
            message = verticalDiff > 0 ? "Move up" : "Move down"
        } else if !leveled {
            message = pose.headTilt > 0 ? "Straighten head (left)" : "Straighten head (right)"
        } else if !facingForward {
            message = pose.headYaw > 0 ? "Turn face right" : "Turn face left"
        } else if !stable {
            message = "Hold still…"
        } else if readinessScore >= readinessThreshold {
            message = "Perfect — hold it!"
        } else {
            message = "Almost there…"
        }

        return (state, message)
    }

    private func score(for delta: CGFloat, limit: CGFloat) -> Double {
        let normalized = max(0, 1 - Double(abs(delta) / limit))
        return min(1, normalized)
    }

    private func score(for delta: Double, limit: Double) -> Double {
        let normalized = max(0, 1 - abs(delta) / limit)
        return min(1, normalized)
    }

    private func distanceConfidence(for faceArea: CGFloat) -> Double {
        if faceArea >= minFaceAreaRatio && faceArea <= maxFaceAreaRatio {
            return 1
        } else if faceArea < minFaceAreaRatio {
            return min(1, Double(faceArea / minFaceAreaRatio)) * 0.7
        } else {
            return min(1, Double(maxFaceAreaRatio / faceArea)) * 0.7
        }
    }
}
