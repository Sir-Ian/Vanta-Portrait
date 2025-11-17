# Vanta Portrait

Vanta Portrait is a SwiftUI macOS app that turns the built-in camera into an AI-guided portrait experience. The app streams a live preview, evaluates pose quality using Vision, guides the user with live text, and fires a countdown-based burst capture that returns the best frame.

## How it works

1. **CameraManager (AVFoundation)** powers the live preview, supplies frames for analysis, and captures a burst of full-resolution stills.
2. **PoseDetector (Vision)** extracts a face bounding box, tilt, and approximate eye openness from video frames.
3. **StabilityTracker** keeps a rolling buffer of recent face centers to decide if the user is steady.
4. **GuidanceEngine** combines pose and stability metrics into human-friendly guidance strings plus booleans used throughout the UI.
5. **AppViewModel + SwiftUI Views** render the live preview, guidance text, capture controls, countdown overlay, debug panel, and result view that highlights the best frame.
6. **Camera availability handling** surfaces permission or hardware issues inline so you know when the webcam is disconnected or denied.

Strict and flexible capture modes enforce different tolerances before the countdown begins. When conditions are met, the app fires a 3-2-1 countdown, captures a burst of 3–5 frames, scores them heuristically (centered, level, eyes open), and surfaces the top image with options to save or retake.

## Project layout

```
Vanta Portrait/
├── AppViewModel.swift        // ObservableObject coordinating guidance and capture flow
├── CameraManager.swift       // AVCaptureSession setup, live preview, burst capture
├── CameraPreviewView.swift   // NSViewRepresentable wrapper around AVCaptureVideoPreviewLayer
├── ContentView.swift         // Main UI with preview, guidance, controls, and overlays
├── CountdownOverlay.swift    // Fullscreen countdown numbers
├── DebugPanelView.swift      // Optional metrics panel for tuning
├── GuidanceEngine.swift      // Converts pose data into guidance state/messages
├── PoseDetector.swift        // Vision pipeline for faces, tilt, and eyes-open
├── ResultView.swift          // Displays the best frame with save/retake actions
├── StabilityTracker.swift    // Rolling movement tracker for steadiness detection
└── Vanta_PortraitApp.swift   // App entry point
```

Assets and test targets live in their default Xcode folders.

## Requirements

- macOS 13+
- Xcode 15+ (or `xcodebuild` command line tools)
- Mac with an available webcam

## Setup

1. Clone or download this repository.
2. Open `Vanta Portrait.xcodeproj` in Xcode, or work from Terminal in the repository root.
3. Ensure the app has permission to use the camera the first time it runs.

## Running the app

### Xcode
1. Open the project in Xcode.
2. Select the **Vanta Portrait** target.
3. Choose the **My Mac** destination.
4. Press **⌘R** to build and run.

### Command line

```bash
xcodebuild -scheme "Vanta Portrait" -sdk macosx -destination 'platform=macOS' build
```

After a successful build you can run the generated `.app` from the derived data path or continue using Xcode for debugging.

## Operating the app

- **Preview & Guidance**: Keep your face centered and level as guided by the text overlay. Strict mode requires tighter tolerances.
- **Camera status banner**: If the app cannot access a webcam (missing device, denied permissions, or configuration errors), a red banner explains the issue and disables capture until resolved.
- **Strict vs Flexible**: Toggle the strict switch in the control bar or toolbar. Strict mode enforces alignment, head tilt, eyes-open, and stability; flexible mode only requires centered & stable.
- **Capture**: Click the **Capture** button or press the space bar. If you meet the requirements, a 3…2…1 countdown appears before the burst fires.
- **Result view**: After the burst, the best frame appears with **Retake** and **Save to Pictures** buttons.
- **Debug Panel**: Toggle “Show Debug” to display raw metrics such as stability, tilt, and booleans used for strict/flexible decisions.

## Testing and linting

This project currently relies on Xcode’s build/test tooling. Run the unit test target (even if it only contains template tests) with:

```bash
xcodebuild test -scheme "Vanta Portrait" -sdk macosx -destination 'platform=macOS'
```

Running either the `build` or `test` command ensures SwiftUI, AVFoundation, and Vision files compile and link.

## Troubleshooting

- If the preview is blank, confirm the app has camera permissions in **System Settings → Privacy & Security → Camera**.
- If `xcodebuild` cannot find a destination, pass an explicit destination such as `-destination 'platform=macOS,arch=arm64'` on Apple silicon.
- The Vision-based heuristics are intentionally simple; adjust thresholds inside `GuidanceEngine` and `StabilityTracker` for your environment.
