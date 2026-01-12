import Testing
import Foundation
import CoreGraphics
@testable import Vanta_Portrait

struct GuidanceEngineTests {
    
    let engine = GuidanceEngine()
    
    // Helper to create mock PoseData
    func createPose(x: CGFloat = 0.5, y: CGFloat = 0.5, width: CGFloat = 0.4, height: CGFloat = 0.5, tilt: Double = 0, yaw: Double = 0, eyesOpen: Bool = true) -> PoseData {
        let rect = CGRect(x: x - width/2, y: y - height/2, width: width, height: height)
        return PoseData(boundingBox: rect, headTilt: tilt, headYaw: yaw, eyesOpen: eyesOpen, timestamp: Date())
    }

    @Test("Signals when face is too far and readiness stays false")
    func testDistanceTooFar() {
        let pose = createPose(width: 0.1, height: 0.1)
        let tracker = StabilityTracker()
        tracker.update(with: pose.center)

        let (state, message) = engine.evaluate(pose: pose, stabilityTracker: tracker, strictMode: true)

        #expect(message == "Move closer")
        #expect(!state.readyForCapture)
    }

    @Test("Distance warnings act as signals, not hard blocks")
    func testDistanceWarningStillReady() {
        let pose = createPose(width: 0.6, height: 0.7)
        let tracker = StabilityTracker()
        for _ in 0..<12 { tracker.update(with: pose.center) }

        let (state, message) = engine.evaluate(pose: pose, stabilityTracker: tracker, strictMode: true)

        #expect(message == "Move back")
        #expect(state.readyForCapture)
    }

    @Test("Eyes closed remain a hard gate")
    func testEyeGate() {
        let pose = createPose(eyesOpen: false)
        let tracker = StabilityTracker()
        for _ in 0..<12 { tracker.update(with: pose.center) }

        let (state, message) = engine.evaluate(pose: pose, stabilityTracker: tracker, strictMode: true)

        #expect(!state.readyForCapture)
        #expect(message == "Open your eyes")
    }

    @Test("Vertical alignment guidance still surfaces")
    func testVerticalAlignmentMessaging() {
        let poseLow = createPose(y: 0.65)
        let tracker = StabilityTracker()

        let (_, messageLow) = engine.evaluate(pose: poseLow, stabilityTracker: tracker, strictMode: true)
        #expect(messageLow == "Move up")

        let poseHigh = createPose(y: 0.2)
        let (_, messageHigh) = engine.evaluate(pose: poseHigh, stabilityTracker: tracker, strictMode: true)
        #expect(messageHigh == "Move down")
    }

    @Test("Strict mode reaches readiness with strong signals")
    func testStrictMode() {
        let pose = createPose(x: 0.5, y: 0.4, width: 0.4, height: 0.5, tilt: 0, yaw: 0, eyesOpen: true)
        let tracker = StabilityTracker()
        for _ in 0..<15 { tracker.update(with: pose.center) }

        let (state, message) = engine.evaluate(pose: pose, stabilityTracker: tracker, strictMode: true)

        #expect(state.readyForCapture)
        #expect(message == "Perfect — hold it!")
    }
}
