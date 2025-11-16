import SwiftUI

struct DebugPanelView: View {
    let guidanceState: GuidanceState
    let stabilityValue: CGFloat
    let strictMode: Bool
    let countdownActive: Bool
    let lastCaptureDate: Date?

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        formatter.dateStyle = .none
        return formatter
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Debug Panel").font(.headline)
            Divider()
            debugRow(label: "Centered", value: guidanceState.centered)
            debugRow(label: "Vertical", value: guidanceState.verticalAligned)
            debugRow(label: "Leveled", value: guidanceState.leveled)
            debugRow(label: "Eyes Open", value: guidanceState.eyesOpen)
            debugRow(label: "Stable", value: guidanceState.isStable)
            Text("Head tilt: \(String(format: "%.1f", guidanceState.headTilt))°")
            Text("Stability: \(String(format: "%.4f", Double(stabilityValue)))")
            Text("Strict mode: \(strictMode ? "On" : "Off")")
            Text("Countdown: \(countdownActive ? "Running" : "Idle")")
            if let lastCaptureDate {
                Text("Last capture: \(dateFormatter.string(from: lastCaptureDate))")
            } else {
                Text("Last capture: —")
            }
        }
        .padding()
        .background(.thinMaterial)
        .cornerRadius(12)
    }

    private func debugRow(label: String, value: Bool) -> some View {
        HStack {
            Text(label)
            Spacer()
            Image(systemName: value ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundColor(value ? .green : .red)
        }
    }
}
