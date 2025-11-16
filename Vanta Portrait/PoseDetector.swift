import Foundation
import Vision
import CoreGraphics

struct PoseData {
    let boundingBox: CGRect
    let headTilt: Double
    let eyesOpen: Bool
    let timestamp: Date

    var center: CGPoint {
        CGPoint(x: boundingBox.midX, y: boundingBox.midY)
    }

    var horizontalOffset: CGFloat {
        center.x - 0.5
    }

    var verticalOffset: CGFloat {
        center.y - 0.5
    }
}

final class PoseDetector {
    private let requestHandlerQueue = DispatchQueue(label: "pose.detector.queue")

    func process(pixelBuffer: CVPixelBuffer, completion: @escaping (PoseData?) -> Void) {
        let request = VNDetectFaceLandmarksRequest { request, error in
            guard error == nil,
                  let observation = request.results?.first as? VNFaceObservation else {
                completion(nil)
                return
            }

            let tilt = self.estimateTilt(from: observation)
            let eyesOpen = self.estimateEyesOpen(from: observation)
            let pose = PoseData(boundingBox: observation.boundingBox,
                                headTilt: tilt,
                                eyesOpen: eyesOpen,
                                timestamp: Date())
            completion(pose)
        }

        requestHandlerQueue.async {
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
            try? handler.perform([request])
        }
    }

    private func estimateTilt(from observation: VNFaceObservation) -> Double {
        guard let leftEye = observation.landmarks?.leftEye,
              let rightEye = observation.landmarks?.rightEye,
              leftEye.pointCount > 0,
              rightEye.pointCount > 0 else {
            return 0
        }

        let leftPoint = averagePoint(from: leftEye.normalizedPoints)
        let rightPoint = averagePoint(from: rightEye.normalizedPoints)
        let delta = CGPoint(x: rightPoint.x - leftPoint.x, y: rightPoint.y - leftPoint.y)
        let angle = atan2(delta.y, delta.x)
        return Double(angle * 180 / .pi)
    }

    private func estimateEyesOpen(from observation: VNFaceObservation) -> Bool {
        guard let left = observation.landmarks?.leftEye,
              let right = observation.landmarks?.rightEye,
              left.pointCount > 3,
              right.pointCount > 3 else {
            return true
        }

        func openness(for region: VNFaceLandmarkRegion2D) -> CGFloat {
            guard region.pointCount >= 4 else { return 0 }
            let top = region.normalizedPoints.max(by: { $0.y < $1.y })?.y ?? 0
            let bottom = region.normalizedPoints.min(by: { $0.y < $1.y })?.y ?? 0
            return CGFloat(top - bottom)
        }

        let leftOpen = openness(for: left)
        let rightOpen = openness(for: right)
        return (leftOpen + rightOpen) / 2 > 0.02
    }

    private func averagePoint(from points: [CGPoint]) -> CGPoint {
        guard !points.isEmpty else { return .zero }
        let sum = points.reduce(CGPoint.zero) { CGPoint(x: $0.x + $1.x, y: $0.y + $1.y) }
        return CGPoint(x: sum.x / CGFloat(points.count), y: sum.y / CGFloat(points.count))
    }
}
