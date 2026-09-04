# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build

Built via GitHub Actions on push to main. Download the artifact from the Actions tab.

## Architecture

Two Swift files, no tests:

- `MacRecordWidgetApp.swift` - SwiftUI `@main` entry point, `.window`-style `MenuBarExtra` (popover panel). Single-row `HStack` with: a switch-style video toggle (camera icon label, `video`/`video.fill` reflects state), a `record.circle.fill` start button (red, plain style), a `stop.fill` stop button (plain style), and a `power` quit button. Panel stays open after Start/Stop; closes only when the user clicks the menu bar icon. The menu bar icon is always `record.circle`; it turns green while recording and gains a small blinking amber dot (blink suppressed under Reduce Motion). It never changes to a mic or camera glyph.
- `RecordingManager.swift` - `@Observable` class with `isRecording`, `videoEnabled`, and `isInFlight` state. `startRecording()` is `async throws`: quits Voice Memos first (if open) with a 1.5s wait using `Task { }` and structured concurrency, then fires `shortcuts://run-shortcut?name=Start&input=text&text=Recording-<timestamp>` (the timestamp is generated in `startRecording()` and passed to the Shortcut as input text). If `videoEnabled`, also opens Photo Booth (does not go full-screen). `stopRecording()` fires `shortcuts://run-shortcut?name=Stop`. State is updated only after the shortcut URL opens successfully. An `isInFlight` guard prevents a second invocation while the first is still running.

Requires two user-created Shortcuts named exactly "Start" and "Stop". No Accessibility permission required (osascript full-screen call was removed). Minimum macOS deployment target is 14.0.

## Gotchas

- Voice Memos must be quit before firing the Start shortcut or macOS raises `VMAudioServiceErrorDomain` error 5. The quit + wait runs inside a `Task { }` using `async`/`await` so the UI doesn't block.
- Do not call `popover.close()` or `panel?.orderOut(nil)` after Start/Stop. The panel intentionally stays open during recording so the user can press Stop without re-opening the popover. The panel closes only via the menu bar icon click (native MenuBarExtra behavior).
- Photo Booth launches in video mode but does not go full-screen by design. The osascript full-screen call was removed to avoid the Accessibility permission prompt.

## Live camera preview (DESIGN ONLY, NOT IMPLEMENTED)

There is an approved PRD and an approved set of mocks for an in-popover live camera preview. **None of it exists in code.** Stages 3 (technical planning), 4 (engineering) and 5 (QA) were skipped by the human's phase config for that pass. `MacRecordWidgetApp.swift`, `RecordingManager.swift` and `Info.plist` are unchanged by it. Do not describe the preview as a shipped capability anywhere.

Where the design lives:

| Artifact | Path |
|---|---|
| PRD (approved) | `projects/20260904-live-camera-preview/product-specs/prd.md` |
| Mocks (approved) | `projects/20260904-live-camera-preview/generated-docs/design/` |
| Merged baseline PRD | `projects/master/product-specs/prd.md` (section marked `[DESIGN ONLY — NOT SHIPPED]`) |
| Merged baseline mocks | `projects/master/mocks/` |

Design intent in one line: flipping the video toggle on also opens a 480x270pt live `AVCaptureSession` preview below the button row, with a persisted camera picker and a persisted mirror toggle. The preview is display-only, never writes a file, and Photo Booth remains the sole capturer. Start and Stop must stay usable in every permission, hardware and error state.

### Prerequisites before any preview code lands

1. **Make `RecordingManager` `@MainActor` first, as a separate change.** It is not `@MainActor` today, and `startRecording()` / `stopRecording()` mutate `isRecording`, `videoEnabled` and `isInFlight` after `await` points, i.e. off the main thread. That is already wrong; adding an `AVCaptureSession` plus new observable preview state to the same class makes it much worse. Fix the concurrency annotation and land it before writing preview code, as its own change.
2. **`Info.plist` needs `NSCameraUsageDescription`.** It currently contains only `LSUIElement`. A missing usage-description string is a hard crash the first time capture is requested, not a permission denial, so it will not surface as a recoverable error state.
3. **Camera entitlement** must be added to the app's entitlements alongside the plist string.
4. **An `NSViewRepresentable` wrapper around `AVCaptureVideoPreviewLayer` is required.** macOS 14 has no SwiftUI-native camera preview view, so the preview cannot be pure SwiftUI.
5. **Persistence deviates from `tech-config.md`.** The camera selection and mirror flag are two scalar preferences; the design uses `@AppStorage`/`UserDefaults`, not the SwiftData listed in `.claude/tech-config.md`. This is deliberate, so record it in the detailed design rather than silently reintroducing SwiftData.

### Source layout exception

Swift sources live in `MacRecordWidget/`, not `src/`. This is a deliberate, standing exception to the `src/` convention documented in `.claude/tech-config.md`: the directory name is the Xcode target's group and changing it means restructuring `MacRecordWidget.xcodeproj`. Do not "fix" it by moving files.

### Unverified assumptions in the design (do not restate these as facts)

- **Panel resize behaviour is unverified.** The design assumes a `MenuBarExtra(.window)` panel is pinned at its trailing edge and therefore grows ~304pt leftward (200pt → 504pt) when the preview opens. Nobody has confirmed this on a real machine; it needs a human check on hardware. What *is* certain from the code: the button row is an `HStack` inside `.frame(width: 200)` with no alignment argument, so it is centered. Widening that frame will move the buttons unless the frame is given an explicit `alignment: .trailing`.
- **Whether the panel animates or snaps a width change is unverified.** The PRD specifies an animation gated on `accessibilityReduceMotion`; whether AppKit will animate a `MenuBarExtra(.window)` panel's width at all is unknown.
- **Simultaneous camera access with Photo Booth is unverified.** Whether this app and Photo Booth can both hold the same camera on macOS 14 has not been tested. The "preview keeps running during recording" decision depends entirely on it. If they cannot share the device, that decision has to be revisited before implementation.

### Known dead code

`RecordingError.accessibilityDenied` and its branch in `presentAlert(for:)` are unreachable. They date from the removed osascript full-screen call; the app no longer requests Accessibility permission. Left in place deliberately, but do not treat the alert text as describing current behaviour.
