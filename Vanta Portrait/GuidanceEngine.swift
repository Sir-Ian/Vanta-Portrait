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
}

final class GuidanceEngine {
    // Thresholds
    private let strictHorizontalThreshold: CGFloat = 0.05
    private let flexibleHorizontalThreshold: CGFloat = 0.12
    private let strictVerticalThreshold: CGFloat = 0.06 // Slightly looser vertically
    private let flexibleVerticalThreshold: CGFloat = 0.15
    private let strictTiltThreshold: Double = 5
    private let flexibleTiltThreshold: Double = 10
    private let strictYawThreshold: Double = 10 // Degrees
    private let flexibleYawThreshold: Double = 20
    
    // Headshot Framing (Face Area Ratio)
    // Ideal is roughly 15-25% of the screen for a head-and-shoulders shot
    private let minFaceAreaRatio: CGFloat = 0.10
    private let maxFaceAreaRatio: CGFloat = 0.35

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

        var state = GuidanceState(centered: centered,
                                  verticalAligned: verticalAligned,
                                  leveled: leveled,
                                  eyesOpen: eyesOpen,
                                  isStable: stable,
                                  readyForCapture: false,
                                  headTilt: pose.headTilt,
                                  horizontalOffset: pose.horizontalOffset,
                                  verticalOffset: pose.verticalOffset)

        let ready: Bool
        if strictMode {
            ready = centered && verticalAligned && leveled && facingForward && eyesOpen && stable && distanceOk
        } else {
            ready = centered && stable && distanceOk
        }
        state.readyForCapture = ready

        let message: String
        if !distanceOk {
            message = faceArea < minFaceAreaRatio ? "Move closer" : "Move back"
        } else if !centered {
            message = pose.horizontalOffset > 0 ? "Move left" : "Move right"
        } else if !verticalAligned {
            // If pose.verticalOffset is -0.3 (too high), diff is -0.2. We want them to move down (chin down/camera up).
            // Actually, if face is too high in frame (y < 0.5), we want them to move camera up or face down.
            // Let's keep it simple: "Move Up" / "Move Down" refers to the person's position relative to frame.
            message = verticalDiff > 0 ? "Move up" : "Move down"
        } else if !leveled {
            message = pose.headTilt > 0 ? "Straighten head (left)" : "Straighten head (right)"
        } else if !facingForward {
            message = pose.headYaw > 0 ? "Turn face right" : "Turn face left"
        } else if !eyesOpen {
            message = "Open your eyes"
        } else if !stable {
            message = "Hold still…"
        } else {
            message = "Perfect — hold it!"
        }

        return (state, message)
    }
}
