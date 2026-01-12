import SwiftUI

struct GuidanceOverlay: View {
    let state: GuidanceState
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 1. Dynamic Target Frame
                // We want a frame that represents the ideal head position.
                // It should be roughly centered and of appropriate size.
                let frameWidth = geometry.size.width * 0.45
                let frameHeight = geometry.size.height * 0.55
                let frameRect = CGRect(
                    x: (geometry.size.width - frameWidth) / 2,
                    y: (geometry.size.height - frameHeight) / 2 - (geometry.size.height * 0.05), // Slightly above center
                    width: frameWidth,
                    height: frameHeight
                )
                
                // Dimmed background with cutout
                Color.black.opacity(0.4)
                    .mask(
                        Rectangle()
                            .overlay(
                                RoundedRectangle(cornerRadius: frameWidth * 0.4)
                                    .frame(width: frameRect.width, height: frameRect.height)
                                    .position(x: frameRect.midX, y: frameRect.midY)
                                    .blendMode(.destinationOut)
                            )
                    )
                
                // The Target Ring
                RoundedRectangle(cornerRadius: frameWidth * 0.4)
                    .stroke(statusColor, style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: state.readyForCapture ? [] : [10, 10]))
                    .frame(width: frameRect.width, height: frameRect.height)
                    .position(x: frameRect.midX, y: frameRect.midY)
                    .animation(.easeInOut(duration: 0.2), value: statusColor)
                
                // 2. Directional Arrows
                if !state.centered || !state.verticalAligned {
                    // Horizontal
                    if state.horizontalOffset > 0.05 { // User is to the right, needs to move left
                        DirectionalArrow(direction: .left)
                            .position(x: frameRect.minX - 40, y: frameRect.midY)
                    } else if state.horizontalOffset < -0.05 { // User is to the left, needs to move right
                        DirectionalArrow(direction: .right)
                            .position(x: frameRect.maxX + 40, y: frameRect.midY)
                    }
                    
                    // Vertical
                    // verticalOffset: + is down, - is up.
                    // If offset is positive (user is low), we need them to move up.
                    // Wait, let's check GuidanceEngine logic.
                    // "verticalDiff > 0 ? Move up : Move down"
                    // If verticalDiff is positive, it means pose.verticalOffset > target (-0.1).
                    // So pose is e.g. 0.0 (center). Target is -0.1 (higher).
                    // So user is lower than target. They need to move UP.
                    
                    let targetVerticalOffset: CGFloat = -0.1
                    let verticalDiff = state.verticalOffset - targetVerticalOffset
                    
                    if verticalDiff > 0.05 { // User is too low
                        DirectionalArrow(direction: .up)
                            .position(x: frameRect.midX, y: frameRect.minY - 40)
                    } else if verticalDiff < -0.05 { // User is too high
                        DirectionalArrow(direction: .down)
                            .position(x: frameRect.midX, y: frameRect.maxY + 40)
                    }
                }
                
                // 3. Eye Level Guide (Rule of Thirds)
                // Eyes should be roughly at the top third line.
                Path { path in
                    let y = geometry.size.height * 0.38 // Approx eye level
                    path.move(to: CGPoint(x: frameRect.minX + 20, y: y))
                    path.addLine(to: CGPoint(x: frameRect.maxX - 20, y: y))
                }
                .stroke(Color.white.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                
                // 4. Distance/Size Feedback (Corner Brackets)
                // If too far (face small), brackets expand or pulse?
                // Let's keep it simple: The ring color handles "move closer/back" for now via GuidanceEngine message,
                // but we could add specific icons.
            }
        }
        .allowsHitTesting(false)
    }
    
    var statusColor: Color {
        if state.readyForCapture {
            return .green
        } else if state.centered && state.verticalAligned && state.leveled {
            // Position is good, maybe waiting for stability or expression
            return .yellow
        } else {
            return .white.opacity(0.7)
        }
    }
}

struct DirectionalArrow: View {
    enum Direction { case left, right, up, down }
    let direction: Direction
    
    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 40, weight: .bold))
            .foregroundColor(.white)
            .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
            .opacity(0.8)
            .symbolEffect(.pulse, options: .repeating)
    }
    
    var systemName: String {
        switch direction {
        case .left: return "arrow.left"
        case .right: return "arrow.right"
        case .up: return "arrow.up"
        case .down: return "arrow.down"
        }
    }
}

struct GridOverlay: View {
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                // Vertical lines
                let thirdWidth = geometry.size.width / 3
                path.move(to: CGPoint(x: thirdWidth, y: 0))
                path.addLine(to: CGPoint(x: thirdWidth, y: geometry.size.height))
                path.move(to: CGPoint(x: thirdWidth * 2, y: 0))
                path.addLine(to: CGPoint(x: thirdWidth * 2, y: geometry.size.height))
                
                // Horizontal lines
                let thirdHeight = geometry.size.height / 3
                path.move(to: CGPoint(x: 0, y: thirdHeight))
                path.addLine(to: CGPoint(x: geometry.size.width, y: thirdHeight))
                path.move(to: CGPoint(x: 0, y: thirdHeight * 2))
                path.addLine(to: CGPoint(x: geometry.size.width, y: thirdHeight * 2))
            }
            .stroke(Color.white.opacity(0.2), lineWidth: 1)
        }
        .allowsHitTesting(false)
    }
}
