 import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = AppViewModel()
    @State private var showGrid = false
    @State private var showSilhouette = true
    
    var body: some View {
        ZStack {
            if viewModel.showingResult, let image = viewModel.bestImage {
                ResultView(image: image, onRetake: {
                    viewModel.retake()
                }, onSave: { url in
                    // Could add analytics or other post-save actions here
                    print("Photo saved")
                })
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
                    .overlay {
                        if showSilhouette {
                            GuidanceOverlay(state: viewModel.guidanceState)
                        }
                        if showGrid {
                            GridOverlay()
                        }
                    }
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
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(guidanceColor)
                        .padding(16)
                        .frame(maxWidth: .infinity)
                        .background(.ultraThinMaterial)
                        .cornerRadius(16)
                        .padding()
                        .shadow(radius: 4)
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
    
    private var guidanceColor: Color {
        if viewModel.guidanceState.readyForCapture {
            return .green
        } else if viewModel.guidanceMessage.contains("Move") || viewModel.guidanceMessage.contains("Turn") {
            return .orange
        } else {
            return .primary
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
            
            Toggle(isOn: $showSilhouette) {
                Label("Guide", systemImage: "person.fill.viewfinder")
            }
            .toggleStyle(.button)
            
            Toggle(isOn: $showGrid) {
                Label("Grid", systemImage: "grid")
            }
            .toggleStyle(.button)
            
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
