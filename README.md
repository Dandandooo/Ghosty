# Ghost in the Machine — macOS Notch Frontend

Native Swift/SwiftUI notch-resident assistant shell for a Gemini CLI / Python executive backend.

## Features
- Top-center floating notch panel (`NSPanel`)
- Minimal ghost character with `Peek`, `Pulse`, and `Retreat` animations
- Global hotkey: `⌘⇧G` to toggle peek/listen
- Menu bar ghost icon (SVG): hollow when sleeping, filled when awake
- Left-clicking the menu bar ghost activates Ghosty (wake/listen)
- Right-click menu includes `Enable Voice` checkbox and `Quit Ghosty`
- Menu bar popover auto-hides while sleeping
- Native speech recognizer listen mode (`NSSpeechRecognizer`)
- Backend bridge via:
  - Shell command invocation (`gemini -p "intent"`)
  - Local JSON state file monitoring

## Project Structure
- `Sources/GhostyApp/App`
  - `GhostyApp.swift` — app entry point
  - `AppDelegate.swift` — window lifecycle + wiring
  - `GhostAssistantModel.swift` — state machine for ghost modes
- `Sources/GhostyApp/Windowing`
  - `NotchWindowController.swift` — borderless top-center floating panel
- `Sources/GhostyApp/UI`
  - `NotchPanelView.swift` — notch card UI
  - `GhostCharacterView.swift` — minimalist ghost drawing + pulse animation
- `Sources/GhostyApp/Services`
  - `GlobalHotkeyManager.swift` — `⌘⇧G` global hotkey via HotKey
  - `SpeechListener.swift` — native wake-command listener
  - `BackendBridge.swift` — shell process + JSON state-file monitor

## Open in Xcode
1. Open `Package.swift` in Xcode.
2. Select the `Ghosty` scheme.
3. Run.

## Backend State File
Default monitored file: `~/ghosty/state.json`

Example payload:

```json
{
  "state": "listening",
  "completed": false,
  "intent": "summarize current task"
}
```

Supported `state` values: `hidden`, `idle`, `listening`, `working`, `complete`.

## Privacy / Permissions
Add the following key in your app host Info.plist when packaging as an app:
- `NSSpeechRecognitionUsageDescription`: Explain why speech recognition is needed.

For full app-distribution hardening, add app sandbox/entitlements according to your release model.
