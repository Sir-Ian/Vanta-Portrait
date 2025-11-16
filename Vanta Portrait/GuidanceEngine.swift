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
    private let strictHorizontalThreshold: CGFloat = 0.05
    private let flexibleHorizontalThreshold: CGFloat = 0.12
    private let strictVerticalThreshold: CGFloat = 0.05
    private let flexibleVerticalThreshold: CGFloat = 0.12
    private let strictTiltThreshold: Double = 4
    private let flexibleTiltThreshold: Double = 8

    func evaluate(pose: PoseData?, stabilityTracker: StabilityTracker, strictMode: Bool) -> (GuidanceState, String) {
        guard let pose else {
            return (GuidanceState(), "Looking for your face…")
        }

        let horizontalThreshold = strictMode ? strictHorizontalThreshold : flexibleHorizontalThreshold
        let verticalThreshold = strictMode ? strictVerticalThreshold : flexibleVerticalThreshold
        let tiltThreshold = strictMode ? strictTiltThreshold : flexibleTiltThreshold

        let centered = abs(pose.horizontalOffset) < horizontalThreshold
        let verticalAligned = abs(pose.verticalOffset) < verticalThreshold
        let leveled = abs(pose.headTilt) < tiltThreshold
        let eyesOpen = pose.eyesOpen

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
            ready = centered && verticalAligned && leveled && eyesOpen && stable
        } else {
            ready = centered && stable
        }
        state.readyForCapture = ready

        let message: String
        if !centered {
            message = pose.horizontalOffset > 0 ? "Move left" : "Move right"
        } else if !verticalAligned {
            message = pose.verticalOffset > 0 ? "Chin down" : "Chin up"
        } else if !leveled {
            message = pose.headTilt > 0 ? "Straighten left" : "Straighten right"
        } else if !eyesOpen {
            message = "Open your eyes fully"
        } else if !stable {
            message = "Hold still…"
        } else {
            message = "Great — hold that pose"
        }

        return (state, message)
    }
}
