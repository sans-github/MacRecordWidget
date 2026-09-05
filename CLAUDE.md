# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build

Built via GitHub Actions on push to main. Download the artifact from the Actions tab.

## Architecture

Five Swift files, no tests:

- `MacRecordWidgetApp.swift` - SwiftUI `@main` entry point, `.window`-style `MenuBarExtra` (popover panel). Single row, left to right: an "Audio" label, ONE audio toggle button (`record.circle.fill` idle / `stop.fill` recording, tinted red), a spacer, a camera toggle button (`video.fill`), the camera picker (only while the camera is on), and a bordered power button. Every control is `.controlSize(.small)` with a 13pt glyph in a 16pt frame and a constant 1pt outline, so an off toggle and an on toggle read as one control in two states. Panel stays open after start/stop; it closes only when the user clicks the menu bar icon. The menu bar icon is always `record.circle`; it turns green while recording and gains a small blinking amber dot (blink suppressed under Reduce Motion).
- `RecordingManager.swift` - `@MainActor @Observable` class with `isRecording`, `videoEnabled`, and `isInFlight` state. `startRecording()` is `async throws`: quits Voice Memos first (if open) with a 1.5s wait, then fires `shortcuts://run-shortcut?name=Start&input=text&text=Recording-<timestamp>`. `stopRecording()` fires `shortcuts://run-shortcut?name=Stop`. State is updated only after the shortcut URL opens successfully, and an `isInFlight` guard prevents a second invocation while the first is still running. **Recording is audio only.** Photo Booth is never launched.

Requires two user-created Shortcuts named exactly "Start" and "Stop". No Accessibility permission required. Minimum macOS deployment target is 14.0.

**The app has no video capture.** The camera toggle drives an on-screen preview and nothing else; recording produces an audio memo in Voice Memos. Photo Booth used to be launched for video and that was removed deliberately, because one toggle was silently doing two jobs.

## Gotchas

- Voice Memos must be quit before firing the Start shortcut or macOS raises `VMAudioServiceErrorDomain` error 5. The quit + wait runs inside a `Task { }` using `async`/`await` so the UI doesn't block.
- Do not call `popover.close()` or `panel?.orderOut(nil)` after Start/Stop. The panel intentionally stays open during recording so the user can press Stop without re-opening the popover. The panel closes only via the menu bar icon click (native MenuBarExtra behavior).
- `NSWorkspace.open` returns `true` whenever something claims the `shortcuts://` scheme, which the Shortcuts app always does. It says nothing about whether the "Start" Shortcut exists or ran, so the app cannot detect a missing or broken Shortcut. Do not read that return value as proof a recording started.

## Live camera preview

Shipped 2026-09-04. The camera toggle opens a live 480x270pt preview below the
button row. It is display-only: it never writes a file, and nothing else
captures video either. The preview exists so the user can see themselves, not
to record.

Three files implement it:

- `CameraManager.swift` - `@MainActor @Observable` owner of the `AVCaptureSession`.
  Distinguishes every permission state; `restricted` deliberately offers no
  "Open Settings" action because that pane cannot resolve an MDM restriction.
  Camera choice persists in `UserDefaults`. A disconnect falls back to another
  camera *without* clearing the stored preference, so reconnecting the preferred
  device restores it. Mirroring is hardcoded on: the user-facing toggle was
  removed, and the stored preference is deliberately not read, because a
  previously saved `false` would otherwise strand the preview unmirrored with no
  way to change it back.
- `CameraPreviewView.swift` - `AVCaptureVideoPreviewLayer` inside an
  `NSViewRepresentable`, because macOS 14 has no SwiftUI-native camera preview.
  `CameraControls` holds the picker, which lives in the button row rather than
  under the preview; its selected value doubles as the camera-name indicator,
  naming the device actually feeding the layer rather than the stored preference.
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
  `setFrameOrigin` immediately afterwards sticks.
- **Never animate the panel resize.** `animator().setFrame` animates the reverted
  origin as well, sliding the panel across the screen before the correction
  lands. `PanelSizer` applies size and corrected origin with
  `disableScreenUpdatesUntilFlush()` and flushes once, so the anchored
  intermediate position is never painted.
- **The panel is a fixed 504pt wide in both states.** A width change forces AppKit
  to reposition as well as resize, and the anchored position is shown before the
  correction. Holding the width constant means only the height moves.
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
- The resize is **not** animated. Animating it animates the reverted origin too,
  which slides the panel across the screen before the correction lands.
- Camera contention with Photo Booth is **moot**: Photo Booth is no longer
  launched, so nothing competes for the device.

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
