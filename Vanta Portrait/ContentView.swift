 import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = AppViewModel()

    var body: some View {
        ZStack {
            if viewModel.showingResult, let image = viewModel.bestImage {
                ResultView(image: image) {
                    viewModel.retake()
                } onSave: { _ in }
            } else {
                mainCaptureView
            }
        }
        .frame(minWidth: 800, minHeight: 600)
    }

    private var strictBinding: Binding<Bool> {
        Binding(get: { viewModel.strictMode }, set: { newValue in
            if viewModel.strictMode != newValue {
                viewModel.toggleStrictMode()
            }
        })
    }

    private var mainCaptureView: some View {
        VStack(spacing: 16) {
            ZStack(alignment: .bottom) {
                CameraPreviewView(manager: viewModel.cameraManager)
                    .overlay(alignment: .topLeading) {
                        if viewModel.showDebugPanel {
                            DebugPanelView(guidanceState: viewModel.guidanceState,
                                           stabilityValue: viewModel.stabilityValue,
                                           strictMode: viewModel.strictMode,
                                           countdownActive: viewModel.countdownValue != nil,
                                           lastCaptureDate: viewModel.cameraManager.lastCaptureDate)
                            .padding()
                        }
                    }
                VStack(spacing: 8) {
                    Text(viewModel.guidanceMessage)
                        .font(.title3)
                        .padding(12)
                        .frame(maxWidth: .infinity)
                        .background(.thinMaterial)
                        .cornerRadius(12)
                        .padding()
                    controlBar
                }
            }
        }
        .background(Color.black.opacity(0.9))
        .overlay {
            if let countdown = viewModel.countdownValue {
                CountdownOverlay(value: countdown)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                Toggle("Strict", isOn: strictBinding)
                Button(viewModel.showDebugPanel ? "Hide Debug" : "Show Debug") {
                    viewModel.toggleDebugPanel()
                }
            }
        }
    }

    private var controlBar: some View {
        HStack(spacing: 16) {
            Toggle("Strict Mode", isOn: strictBinding)
                .toggleStyle(.switch)
                .labelsHidden()
            Button(action: viewModel.toggleDebugPanel) {
                Label(viewModel.showDebugPanel ? "Hide Debug" : "Show Debug", systemImage: "waveform")
            }
            Spacer()
            Button(action: viewModel.attemptCapture) {
                Label("Capture", systemImage: "camera.fill")
            }
            .keyboardShortcut(.space, modifiers: [])
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(.ultraThinMaterial)
    }
}

#Preview {
    ContentView()
}
