import Testing
import Foundation
import CoreGraphics
@testable import Vanta_Portrait

struct GuidanceEngineTests {
    
    let engine = GuidanceEngine()
    let tracker = StabilityTracker()
    
    // Helper to create mock PoseData
    func createPose(x: CGFloat = 0.5, y: CGFloat = 0.5, width: CGFloat = 0.4, height: CGFloat = 0.5, tilt: Double = 0, yaw: Double = 0, eyesOpen: Bool = true) -> PoseData {
        let rect = CGRect(x: x - width/2, y: y - height/2, width: width, height: height)
        return PoseData(boundingBox: rect, headTilt: tilt, headYaw: yaw, eyesOpen: eyesOpen, timestamp: Date())
    }

    @Test("Detects when user is too far (face too small)")
    func testDistanceTooFar() {
        // Area = 0.1 * 0.1 = 0.01 (Threshold is 0.10)
        let pose = createPose(width: 0.1, height: 0.1) 
        let (state, message) = engine.evaluate(pose: pose, stabilityTracker: tracker, strictMode: true)
        
        #expect(!state.readyForCapture)
        #expect(message == "Move closer")
    }
    
    @Test("Detects when user is too close (face too big)")
    func testDistanceTooClose() {
        // Area = 0.6 * 0.7 = 0.42 (Max is 0.35)
        let pose = createPose(width: 0.6, height: 0.7)
        let (state, message) = engine.evaluate(pose: pose, stabilityTracker: tracker, strictMode: true)
        
        #expect(!state.readyForCapture)
        #expect(message == "Move back")
    }
    
    @Test("Detects perfect distance")
    func testDistancePerfect() {
        // Area = 0.4 * 0.5 = 0.20 (Within 0.10 - 0.35)
        let pose = createPose(width: 0.4, height: 0.5)
        // Ensure centered and stable
        tracker.update(with: pose.center)
        tracker.update(with: pose.center) // Need multiple updates for stability?
        
        let (state, _) = engine.evaluate(pose: pose, stabilityTracker: tracker, strictMode: true)
        
        // Note: Stability might need more updates to be "stable" depending on implementation
        // But here we just check if distance logic didn't fail it immediately
        // Actually, let's just check the message isn't about distance
        let (_, message) = engine.evaluate(pose: pose, stabilityTracker: tracker, strictMode: true)
        #expect(message != "Move closer")
        #expect(message != "Move back")
    }
    
    @Test("Detects head turn (Yaw)")
    func testYawCheck() {
        // Turned right > 10 degrees
        let pose = createPose(yaw: 15)
        let (state, message) = engine.evaluate(pose: pose, stabilityTracker: tracker, strictMode: true)
        
        #expect(!state.readyForCapture)
        #expect(message == "Turn face left")
    }
    
    @Test("Detects vertical alignment (Headshot composition)")
    func testVerticalAlignment() {
        // Target vertical offset is -0.1 (eyes slightly above center)
        // If y is 0.5 (center), offset is 0. Target is -0.1. Diff is 0.1.
        // Strict threshold is 0.06. So 0.1 > 0.06 -> Not aligned.
        
        // Case 1: Too low in frame (y=0.5, needs to be higher ~0.4)
        let poseLow = createPose(y: 0.5)
        let (_, messageLow) = engine.evaluate(pose: poseLow, stabilityTracker: tracker, strictMode: true)
        #expect(messageLow == "Move up")
        
        // Case 2: Too high in frame (y=0.2)
        // Offset = 0.2 - 0.5 = -0.3. Target -0.1. Diff = -0.2.
        let poseHigh = createPose(y: 0.2)
        let (_, messageHigh) = engine.evaluate(pose: poseHigh, stabilityTracker: tracker, strictMode: true)
        #expect(messageHigh == "Move down")
        
        // Case 3: Perfect (y=0.4)
        // Offset = 0.4 - 0.5 = -0.1. Target -0.1. Diff = 0.
        let posePerfect = createPose(y: 0.4)
        let (state, _) = engine.evaluate(pose: posePerfect, stabilityTracker: tracker, strictMode: true)
        #expect(state.verticalAligned)
    }
    
    @Test("Strict mode requires all conditions")
    func testStrictMode() {
        // Perfect pose
        let pose = createPose(x: 0.5, y: 0.4, width: 0.4, height: 0.5, tilt: 0, yaw: 0, eyesOpen: true)
        
        // Make it stable
        let stableTracker = StabilityTracker()
        for _ in 0..<20 {
            stableTracker.update(with: pose.center)
        }
        
        let (state, message) = engine.evaluate(pose: pose, stabilityTracker: stableTracker, strictMode: true)
        
        #expect(state.readyForCapture)
        #expect(message == "Perfect — hold it!")
    }
}
