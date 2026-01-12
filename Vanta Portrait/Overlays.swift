import SwiftUI

struct GuidanceOverlay: View {
    let state: GuidanceState
    let countdownValue: Int?
    let countdownActive: Bool
    let experienceState: ExperienceState
    
    private var readinessProgress: CGFloat {
        CGFloat(min(max(state.readinessScore, 0), 1))
    }
    
    private var ringColor: Color {
        if countdownActive || experienceState == .capturing || experienceState == .revealing {
            return Color.green.opacity(0.85)
        }
        return state.readyForCapture ? Color.green.opacity(0.8) : Color.white.opacity(0.6)
    }
    
    private var countdownProgress: CGFloat {
        guard countdownActive, let value = countdownValue else { return 0 }
        let total = 3.0
        let clamped = max(1.0, min(total, Double(value)))
        return CGFloat((total - clamped + 1) / total)
    }
    
    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height) * 0.5
            let circleFrame = CGSize(width: size, height: size)
            
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.15), lineWidth: 3)
                    .frame(width: circleFrame.width, height: circleFrame.height)
                
                Circle()
                    .trim(from: 0, to: readinessProgress)
                    .stroke(ringColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: circleFrame.width, height: circleFrame.height)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.35), value: readinessProgress)
                    .scaleEffect(countdownActive ? 1.02 : 1.0)
                    .animation(.easeInOut(duration: 0.4).repeatForever(autoreverses: true), value: countdownActive)
                
                if countdownActive, let value = countdownValue {
                    ZStack {
                        Circle()
                            .trim(from: 0, to: countdownProgress)
                            .stroke(ringColor.opacity(0.9), style: StrokeStyle(lineWidth: 10, lineCap: .round))
                            .frame(width: circleFrame.width, height: circleFrame.height)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 0.3), value: countdownProgress)
                        
                        Text("\(value)")
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                            .transition(.opacity)
                            .id(value)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .allowsHitTesting(false)
    }
}
