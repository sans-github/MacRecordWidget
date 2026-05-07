# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build

Built via GitHub Actions on push to main. Download the artifact from the Actions tab.

## Architecture

Two Swift files, no tests:

- `MacRecordWidgetApp.swift` - SwiftUI `@main` entry point, `.window`-style `MenuBarExtra` (popover panel). Contains a `Toggle` switch for video mode, bordered Start/Stop buttons, and Quit. Menu bar icon switches between `mic`/`mic.fill` (audio-only) and `video`/`video.fill` (video on), green while recording.
- `RecordingManager.swift` - `ObservableObject` with `isRecording` and `videoEnabled` state. `startRecording()` fires a `shortcuts://run-shortcut?name=Start` URL (Voice Memos via Shortcuts) and, if `videoEnabled`, opens Photo Booth then uses `osascript` after a 2s delay to full-screen it. `stopRecording()` fires `shortcuts://run-shortcut?name=Stop`. State is optimistic -- set immediately on tap.

Requires two user-created Shortcuts named exactly "Start" and "Stop". Video mode requires Accessibility permission (for the osascript full-screen call) -- macOS prompts on first use.
