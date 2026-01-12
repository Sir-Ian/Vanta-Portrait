# Vanta Portrait

Vanta Portrait is a SwiftUI camera app (macOS/iOS-ready) that turns a built-in camera into an AI-guided portrait flow. It streams a live preview, evaluates pose quality locally with Vision, guides the user with live text, then fires a countdown-based burst capture to surface the best frame. The experience is state-driven to keep capture, guidance, and reveal phases explicit as we prepare to add Azure image models for remote scoring.

## How it works (today)

1. **CameraManager (AVFoundation)** powers the live preview, supplies frames for analysis, and captures burst stills.
2. **PoseDetector (Vision)** extracts a face bounding box, tilt, yaw, and approximate eye openness from video frames.
3. **StabilityTracker** maintains a rolling buffer of face centers and reports stability confidence.
4. **GuidanceEngine** converts pose/stability into a readiness score plus guidance text; eyes-open remains a hard gate.
5. **AppViewModel + ExperienceState** drive the flow (`idle → guiding → almostReady → capturing → revealing → resetting`) so capture commitment and reset hygiene are explicit.
6. **SwiftUI views** render the preview, overlays, countdown, debug panel, and result view. Camera availability issues surface inline.

Strict and flexible capture modes are available; non-eye constraints now act as confidence signals so the app can proceed once readiness is high enough.

## Roadmap to Azure image models

- Current builds are fully local (no networking).  
- Future iterations will ship images and metadata to Azure-hosted models for aesthetic/compliance scoring and selection. The state model is structured to drop in that remote scoring step without altering UI contracts.

## Project layout

```
Vanta Portrait/
├── AppViewModel.swift        // Experience state + capture/guidance flow
├── CameraManager.swift       // AVCaptureSession setup, preview, burst capture
├── CameraPreviewView.swift   // Platform preview layer wrapper
├── ContentView.swift         // Main UI with preview, guidance, controls, overlays
├── CountdownOverlay.swift    // Countdown overlay
├── DebugPanelView.swift      // Optional metrics panel
├── GuidanceEngine.swift      // Pose/stability → readiness score + guidance
├── PoseDetector.swift        // Vision face/landmark pipeline
├── ResultView.swift          // Best-frame display with save/retake
├── StabilityTracker.swift    // Rolling stability/confidence
└── Vanta_PortraitApp.swift   // App entry point
```

Assets and test targets live in their default Xcode folders.

## Requirements

- macOS 13+ (macOS target) or iOS 18.6+ (iOS target)
- Xcode 15+ (or `xcodebuild` command line tools)
- Camera permission granted on first run

## Setup

1. Clone or download this repository.
2. Open `Vanta Portrait.xcodeproj` in Xcode, or work from Terminal in the repository root.
3. Grant camera access when prompted.

## Running the app

### Xcode
1. Open the project in Xcode.
2. Select the **Vanta Portrait** target.
3. Choose **My Mac** or an iOS simulator/device destination.
4. Press **⌘R** to build and run.

### Command line (macOS build)

```bash
xcodebuild -scheme "Vanta Portrait" -sdk macosx -destination 'platform=macOS' build
```

## Operating the app

- **Preview & Guidance**: Keep your face centered/level as guided. Eyes-open is required; other constraints are advisory but influence readiness.
- **Camera status banner**: If the app cannot access a camera (missing device, denied permissions, config errors), a banner explains the issue and disables capture until resolved.
- **Strict vs Flexible**: Toggle the strict switch in the control bar or toolbar. Strict mode expects tighter pose/stability signals; flexible mode is more forgiving.
- **Capture**: Click **Capture** or press Space. When the experience reaches `almostReady`, a 3…2…1 countdown runs and a burst (3–5 frames) fires automatically.
- **Result view**: After the burst, the best frame appears with **Retake** and **Save to Pictures**. Retake runs through a reset state before guiding resumes.
- **Debug Panel**: Toggle “Show Debug” to view readiness components (center, tilt, stability, eyes).

## Testing

Run the unit test target with:

```bash
xcodebuild test -scheme "Vanta Portrait" -sdk macosx -destination 'platform=macOS'
```

## Troubleshooting

- If the preview is blank, confirm camera permissions in **System Settings → Privacy & Security → Camera** (macOS) or **Settings → Privacy & Security → Camera** (iOS).
- If `xcodebuild` cannot find a destination, pass an explicit destination such as `-destination 'platform=macOS,arch=arm64'` on Apple silicon.
