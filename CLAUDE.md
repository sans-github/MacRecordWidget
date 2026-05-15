# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build

Built via GitHub Actions on push to main. Download the artifact from the Actions tab.

## Architecture

Two Swift files, no tests:

- `MacRecordWidgetApp.swift` - SwiftUI `@main` entry point, `.window`-style `MenuBarExtra` (popover panel). Contains a `Toggle` switch for video mode, vertically-stacked Start/Stop buttons, and a power-icon Quit button. Menu bar icon switches between `mic`/`mic.fill` (audio-only) and `video`/`video.fill` (video on), green while recording.
- `RecordingManager.swift` - `ObservableObject` with `isRecording` and `videoEnabled` state. `startRecording()` quits Voice Memos first (if open) on a background thread with a 1.5s wait, then fires `shortcuts://run-shortcut?name=Start`. If `videoEnabled`, also opens Photo Booth and uses `osascript` after 2s to full-screen it. `stopRecording()` fires `shortcuts://run-shortcut?name=Stop`. State is optimistic -- set immediately on tap.

Requires two user-created Shortcuts named exactly "Start" and "Stop". Video mode requires Accessibility permission (for the osascript full-screen call) -- macOS prompts on first use.

## Gotchas

- Voice Memos must be quit before firing the Start shortcut or macOS raises `VMAudioServiceErrorDomain` error 5. The quit + wait happens on a background thread so the UI doesn't block.
- Do not call `popover.close()` manually after Start/Stop -- it breaks the popover double-click to reopen while recording.
