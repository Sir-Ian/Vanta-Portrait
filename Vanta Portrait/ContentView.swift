 import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = AppViewModel()
    
    var body: some View {
        ZStack {
            if viewModel.showingResult, let image = viewModel.bestImage {
                ResultView(image: image) {
                    viewModel.retake()
                } onSave: { url in
                    // Could add analytics or other post-save actions here
                    print("Photo saved to: \(url.path)")
                }
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
                    .accessibilityLabel("Camera preview")
                    .accessibilityValue(viewModel.guidanceMessage)
                    .overlay(alignment: .top) {
                        if let warning = viewModel.cameraWarning {
                            statusBanner(text: warning)
                                .padding()
                                .transition(.move(edge: .top).combined(with: .opacity))
                                .accessibilityAddTraits(.isStaticText)
                        }
                    }
                    .overlay(alignment: .topLeading) {
                        if viewModel.showDebugPanel {
                            DebugPanelView(guidanceState: viewModel.guidanceState,
                                           stabilityValue: viewModel.stabilityValue,
                                           strictMode: viewModel.strictMode,
                                           countdownActive: viewModel.countdownValue != nil,
                                           lastCaptureDate: viewModel.cameraManager.lastCaptureDate)
                            .padding()
                            .transition(.opacity.combined(with: .scale(scale: 0.9)))
                            .accessibilityLabel("Debug panel")
                        }
                    }
                    .animation(.easeInOut(duration: 0.3), value: viewModel.showDebugPanel)
                    .animation(.easeInOut(duration: 0.3), value: viewModel.cameraWarning)
                
                VStack(spacing: 8) {
                    Text(viewModel.guidanceMessage)
                        .font(.title3)
                        .padding(12)
                        .frame(maxWidth: .infinity)
                        .background(.thinMaterial)
                        .cornerRadius(12)
                        .padding()
                        .animation(.easeInOut(duration: 0.2), value: viewModel.guidanceMessage)
                        .accessibilityAddTraits(.isStaticText)
                    controlBar
                }
            }
        }
        .background(Color.black.opacity(0.9))
        .overlay {
            if let countdown = viewModel.countdownValue {
                CountdownOverlay(value: countdown)
                    .transition(.scale.combined(with: .opacity))
                    .accessibilityLabel("Countdown: \(countdown)")
                    .accessibilityAddTraits(.updatesFrequently)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.countdownValue)
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                Toggle("Strict", isOn: strictBinding)
                    .help("Enable strict mode for higher quality requirements")
                
                Button(viewModel.showDebugPanel ? "Hide Debug" : "Show Debug") {
                    viewModel.toggleDebugPanel()
                }
                .help("Toggle debug panel")
                .keyboardShortcut("d", modifiers: [.command, .shift])
            }
        }
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

    private var controlBar: some View {
        HStack(spacing: 16) {
            Toggle("Strict Mode", isOn: strictBinding)
                .toggleStyle(.switch)
                .labelsHidden()
                .help("Enable strict mode for higher quality requirements")
                .accessibilityLabel("Strict mode toggle")
                .accessibilityValue(viewModel.strictMode ? "On" : "Off")
            
            Button(action: viewModel.toggleDebugPanel) {
                Label(viewModel.showDebugPanel ? "Hide Debug" : "Show Debug", systemImage: "waveform")
            }
            .help("Toggle debug panel (⌘⇧D)")
            .accessibilityLabel(viewModel.showDebugPanel ? "Hide debug panel" : "Show debug panel")
            
            Spacer()
            
            Button(action: viewModel.attemptCapture) {
                Label("Capture", systemImage: "camera.fill")
            }
            .keyboardShortcut(.space, modifiers: [])
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.cameraWarning != nil) // Disable capture if there's a warning
            .help("Capture photo (Space)")
            .accessibilityLabel("Capture photo")
            .accessibilityHint(viewModel.cameraWarning != nil ? "Camera unavailable" : viewModel.guidanceMessage)
        }
        .padding()
        .background(.ultraThinMaterial)
    }
}

#Preview {
    ContentView()
}
