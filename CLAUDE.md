# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build

Built via GitHub Actions on push to main. Download the artifact from the Actions tab.

## Architecture

Five Swift files, no tests:

- `MacRecordWidgetApp.swift` - SwiftUI `@main` entry point, `.window`-style `MenuBarExtra` (popover panel). Single-row `HStack` with: a switch-style video toggle (camera icon label, `video`/`video.fill` reflects state), a `record.circle.fill` start button (red, plain style), a `stop.fill` stop button (plain style), and a `power` quit button. Panel stays open after Start/Stop; closes only when the user clicks the menu bar icon. The menu bar icon is always `record.circle`; it turns green while recording and gains a small blinking amber dot (blink suppressed under Reduce Motion). It never changes to a mic or camera glyph.
- `RecordingManager.swift` - `@MainActor @Observable` class with `isRecording`, `videoEnabled`, and `isInFlight` state. `startRecording()` is `async throws`: quits Voice Memos first (if open) with a 1.5s wait using `Task { }` and structured concurrency, then fires `shortcuts://run-shortcut?name=Start&input=text&text=Recording-<timestamp>` (the timestamp is generated in `startRecording()` and passed to the Shortcut as input text). If `videoEnabled`, also opens Photo Booth (does not go full-screen). `stopRecording()` fires `shortcuts://run-shortcut?name=Stop`. State is updated only after the shortcut URL opens successfully. An `isInFlight` guard prevents a second invocation while the first is still running.

Requires two user-created Shortcuts named exactly "Start" and "Stop". No Accessibility permission required (osascript full-screen call was removed). Minimum macOS deployment target is 14.0.

## Gotchas

- Voice Memos must be quit before firing the Start shortcut or macOS raises `VMAudioServiceErrorDomain` error 5. The quit + wait runs inside a `Task { }` using `async`/`await` so the UI doesn't block.
- Do not call `popover.close()` or `panel?.orderOut(nil)` after Start/Stop. The panel intentionally stays open during recording so the user can press Stop without re-opening the popover. The panel closes only via the menu bar icon click (native MenuBarExtra behavior).
- Photo Booth launches in video mode but does not go full-screen by design. The osascript full-screen call was removed to avoid the Accessibility permission prompt.

## Live camera preview

Shipped 2026-09-04. Turning the video toggle on opens a live 480x270pt camera
preview below the button row. The preview is display-only: it never writes a
file, and Photo Booth remains the sole capturer.

Three files implement it:

- `CameraManager.swift` - `@MainActor @Observable` owner of the `AVCaptureSession`.
  Distinguishes every permission state; `restricted` deliberately offers no
  "Open Settings" action because that pane cannot resolve an MDM restriction.
  Camera choice and mirror flag persist in `UserDefaults`. A disconnect falls
  back to another camera *without* clearing the stored preference, so
  reconnecting the preferred device restores it.
- `CameraPreviewView.swift` - `AVCaptureVideoPreviewLayer` inside an
  `NSViewRepresentable`, because macOS 14 has no SwiftUI-native camera preview.
  The picker's selected value doubles as the camera-name indicator.
- `PanelSizer.swift` - drives the panel's `NSWindow` frame. See the gotcha below.

The session starts when the toggle turns on and stops when the popover closes,
so the camera activity light cycles with the panel by design.

Design artifacts: `projects/20260904-live-camera-preview/` (PRD and mocks), merged
into `projects/master/`.

### Panel sizing gotchas

- **`MenuBarExtraWindow` reverts origin changes made inside `setFrame`.** The size
  is honoured and the move is silently discarded, so reading the frame back
  immediately shows the old x. Measured: asking for x=1072 landed at x=848,
  asking for x=768 landed at x=376. The revert is scoped to that call, so
  `PanelSizer` reasserts the origin via `setFrameOrigin` on the next runloop
  pass. Do not fold that deferred call back into `setFrame`; it will stop working.
- **AppKit grows the panel to fit content but never shrinks it back.** Without an
  explicit frame the panel strands at full size with the collapsed row floating
  in the middle of it.
- **Padding order matters.** `.frame(width:)` must size the content *before*
  `.padding` is added outside it, or the row is squeezed by the 24pt of padding.
- The button row is trailing-aligned. An `HStack` in a `.frame(width:)` with no
  alignment argument centers, so it slides when the frame widens.

### Verified on hardware (these were open questions in the design)

- The panel does **not** pin its own trailing edge, contrary to what the design
  assumed. It anchors to the status item; right-alignment is something
  `PanelSizer` imposes, 8pt from the screen's visible frame.
- The width change **does** animate, via `NSAnimationContext` on the window.
- **Still untested:** whether this app and Photo Booth can hold the same camera
  at once. The preview is left running during recording on the assumption that
  they can. If they cannot, that decision needs revisiting.

### Swift 5.9 concurrency

CI builds with Xcode 15.2, which does **not** infer `@MainActor` on `App` or on
view bodies. `MacRecordWidgetApp`, `MenuBarIcon`, `CameraPreviewPanel` and
`CameraPreviewLayerView` carry explicit `@MainActor` annotations for that
reason. Removing them builds locally on newer toolchains and fails in CI.

### Source layout exception

Swift sources live in `MacRecordWidget/`, not `src/`. This is a deliberate,
standing exception to the `src/` convention documented in `.claude/tech-config.md`:
the directory name is the Xcode target's group and changing it means
restructuring `MacRecordWidget.xcodeproj`. Do not "fix" it by moving files.

Adding a source file requires four `project.pbxproj` edits by hand
(`PBXBuildFile`, `PBXFileReference`, the group's `children`, and the sources
build phase). The project uses classic file references, not synchronized groups.

### Known dead code

`RecordingError.accessibilityDenied` and its branch in `presentAlert(for:)` are
unreachable. They date from the removed osascript full-screen call; the app no
longer requests Accessibility permission. Left in place deliberately, but do not
treat the alert text as describing current behaviour.
