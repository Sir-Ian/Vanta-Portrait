import SwiftUI

struct CountdownOverlay: View {
    let value: Int

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            Text("\(value)")
                .font(.system(size: 120, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .shadow(radius: 10)
        }
        .transition(.opacity)
    }
}
