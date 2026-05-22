# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build

Built via GitHub Actions on push to main. Download the artifact from the Actions tab.

## Architecture

Two Swift files, no tests:

- `MacRecordWidgetApp.swift` - SwiftUI `@main` entry point, `.window`-style `MenuBarExtra` (popover panel). Single-row `HStack` with: a switch-style video toggle (camera icon label, `video`/`video.fill` reflects state), a `record.circle.fill` start button (red, plain style), a `stop.fill` stop button (plain style), and a `power` quit button. Panel stays open after Start/Stop; closes only when the user clicks the menu bar icon. Menu bar icon turns green while recording.
- `RecordingManager.swift` - `@Observable` class with `isRecording`, `videoEnabled`, and `isInFlight` state. `startRecording()` is `async throws`: quits Voice Memos first (if open) with a 1.5s wait using `Task { }` and structured concurrency, then fires `shortcuts://run-shortcut?name=Start`. If `videoEnabled`, also opens Photo Booth (does not go full-screen). `stopRecording()` fires `shortcuts://run-shortcut?name=Stop`. State is updated only after the shortcut URL opens successfully. An `isInFlight` guard prevents a second invocation while the first is still running.

Requires two user-created Shortcuts named exactly "Start" and "Stop". No Accessibility permission required (osascript full-screen call was removed). Minimum macOS deployment target is 14.0.

## Gotchas

- Voice Memos must be quit before firing the Start shortcut or macOS raises `VMAudioServiceErrorDomain` error 5. The quit + wait runs inside a `Task { }` using `async`/`await` so the UI doesn't block.
- Do not call `popover.close()` or `panel?.orderOut(nil)` after Start/Stop. The panel intentionally stays open during recording so the user can press Stop without re-opening the popover. The panel closes only via the menu bar icon click (native MenuBarExtra behavior).
- Photo Booth launches in video mode but does not go full-screen by design. The osascript full-screen call was removed to avoid the Accessibility permission prompt.
