import Foundation
import CoreGraphics

final class StabilityTracker {
    private var points: [CGPoint] = []
    private let maxSamples = 15
    private(set) var stabilityValue: CGFloat = 1
    private let strictThreshold: CGFloat = 0.006
    private let flexibleThreshold: CGFloat = 0.015

    func update(with point: CGPoint?) {
        guard let point else {
            points.removeAll()
            stabilityValue = 1
            return
        }

        points.append(point)
        if points.count > maxSamples {
            points.removeFirst(points.count - maxSamples)
        }

        guard points.count > 1 else {
            stabilityValue = 1
            return
        }

        let avg = points.reduce(CGPoint.zero) { CGPoint(x: $0.x + $1.x, y: $0.y + $1.y) }
        let mean = CGPoint(x: avg.x / CGFloat(points.count), y: avg.y / CGFloat(points.count))
        let variance = points.reduce(CGFloat.zero) { partial, p in
            let dx = p.x - mean.x
            let dy = p.y - mean.y
            return partial + sqrt(dx * dx + dy * dy)
        } / CGFloat(points.count)
        stabilityValue = variance
    }

    func isStable(strict: Bool) -> Bool {
        stabilityValue < (strict ? strictThreshold : flexibleThreshold)
    }
}
