# Vanta Portrait

SwiftUI macOS/iOS camera app that guides the user into frame, runs a countdown-gated burst, and (optionally) sends the selected frame to Azure OpenAI Images for a processed portrait. The experience is driven by an explicit state machine to keep capture, guidance, and reveal phases predictable.

## What it does
- Live AVFoundation preview with Vision-based pose/eye detection (center, tilt, stability, eyes-open as a hard gate).
- ExperienceState flow: `idle → guiding → almostReady → capturing → revealing → resetting`, with countdown and eye-blink grace handled in the view model.
- Burst capture picks the best frame; Azure image generation runs after capture and falls back to the original photo on failure.
- Works on macOS and iOS with sandbox-friendly networking (macOS entitlements include outgoing network + camera).
- UITest mode bypasses camera hardware and drives the flow with a bundled sample image and mock Azure responses.

## Setup & configuration
- Requirements: macOS 15.6+ or iOS 18.6+, Xcode 16+ (macOS builds target macosx SDK).
- Azure API key (preferred): export `AZURE_OPENAI_API_KEY` in your environment before launching or running `xcodebuild`.
- Azure API key (fallback): create `Vanta Portrait/AppSecrets.swift` with the user-managed placeholder below (file is gitignored):
  ```swift
  // AppSecrets.swift
  // User-managed configuration.
  // IMPORTANT: Do not modify this file via Codex.

  enum AppSecrets {
      /// Paste your Azure OpenAI API key here for local development.
      static let azureOpenAIKey: String = "<PASTE_API_KEY_HERE>"
  }
  ```
- Azure endpoint config (hard-coded constants in `ImageGenerationService`):  
  - Endpoint: `https://aistudio-foundry-east-us-2.cognitiveservices.azure.com`  
  - Deployment: `gpt-image-1.5`  
  - API version: `2024-02-01`  
  - Request payload: `{ prompt, image: [base64], size: "1024x1024" }`
- Permissions: grant camera access on first run. DEBUG builds print a network preflight log to help diagnose sandbox/DNS issues on macOS.

## Project layout
- `Vanta Portrait/` — App sources (SwiftUI views, AppViewModel, CameraManager, GuidanceEngine, StabilityTracker, ImageGenerationService, entitlements).
- `Vanta PortraitTests/` — Unit tests for the Azure client and app logic.
- `Vanta PortraitUITests/` — UI/system tests that read status from a sandboxed JSON file while mocking Azure.
- `Vanta Portrait.xcodeproj` — Xcode project, deployment targets (macOS 15.6 / iOS 18.6), and capabilities.
- `Vanta-Portrait-Info.plist` — Shared Info.plist.
- `AppSecrets.swift` — User-managed key file (gitignored; see above).

## Running
- Xcode: open `Vanta Portrait.xcodeproj`, select the **Vanta Portrait** scheme, choose **My Mac** or an iOS destination, then **⌘R**.
- Command line (macOS build):
  ```bash
  xcodebuild -scheme "Vanta Portrait" -sdk macosx -destination 'platform=macOS' build
  ```

## Testing
- Unit tests (macOS):
  ```bash
  xcodebuild test -scheme "Vanta Portrait" -sdk macosx -destination 'platform=macOS'
  ```
- UI tests (macOS): same command above, or target-only:
  ```bash
  xcodebuild test -scheme "Vanta Portrait" -sdk macosx -destination 'platform=macOS' -only-testing:"Vanta PortraitUITests"
  ```
  UI tests launch with `-UITestMode` and mock Azure responses; they read/write a status JSON file in the app container specified by `UITestStatusFile`.

## Operating notes
- Eyes-open is a hard gate for entering countdown and committing capture; other pose signals feed readiness but no longer block indefinitely.
- Countdown freezes guidance text/score; if eyes are closed too long at commit, the app aborts cleanly back to guiding.
- Azure errors surface a user-safe fallback message while keeping the original image visible. Debug logs include response details with the API key redacted.

## Troubleshooting
- Blank preview or blocked camera: check camera permissions in system settings.
- Networking errors on macOS: confirm the app has outgoing network entitlement and a valid API key; DEBUG launch prints DNS/connectivity status to the console.
- If `xcodebuild` cannot find a destination, pass `-destination 'platform=macOS,arch=arm64'` on Apple silicon.
