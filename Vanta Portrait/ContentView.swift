import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = AppViewModel()
    
    var body: some View {
        ZStack {
            if viewModel.showingResult, let image = viewModel.bestImage {
                ResultView(image: image, onRetake: {
                    viewModel.retake()
                }, onSave: { _ in },
                isProcessing: viewModel.isProcessingImage,
                statusMessage: viewModel.processingStatus)
                .transition(.opacity.combined(with: .scale))
            } else {
                mainCaptureView
                    .transition(.opacity)
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .background(Color.black)
    }

    private var mainCaptureView: some View {
        ZStack {
            CameraPreviewView(manager: viewModel.cameraManager)
                .accessibilityLabel("Camera preview")
                .accessibilityValue(viewModel.guidanceMessage)
                .overlay {
                    GuidanceOverlay(state: viewModel.guidanceState,
                                    countdownValue: viewModel.countdownValue,
                                    countdownActive: viewModel.countdownActive,
                                    experienceState: viewModel.experienceState)
                }
                .overlay(alignment: .top) {
                    if let warning = viewModel.cameraWarning {
                        statusBanner(text: warning)
                            .padding()
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .accessibilityAddTraits(.isStaticText)
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: viewModel.cameraWarning)
            
            VStack {
                Spacer()
                guidanceText
                    .padding(.bottom, 32)
            }
            .padding(.horizontal, 40)
        }
    }
    
    private var guidanceText: some View {
        Text(viewModel.guidanceMessage)
            .font(.system(size: 20, weight: .semibold, design: .rounded))
            .foregroundStyle(.primary.opacity(0.9))
            .lineLimit(1)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: Capsule())
            .shadow(radius: 4)
            .id(viewModel.guidanceMessage)
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.2), value: viewModel.guidanceMessage)
            .accessibilityAddTraits(.isStaticText)
    }

    private func statusBanner(text: String) -> some View {
        Text(text)
            .font(.headline)
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(Color.red.opacity(0.85))
            .foregroundColor(.white)
            .cornerRadius(12)
    }
}

#Preview {
    ContentView()
}
