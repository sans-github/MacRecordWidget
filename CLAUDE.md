# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build

Built via GitHub Actions on push to main. Download the artifact from the Actions tab.

Open in Xcode for local development: `open MacVoiceRecordWidget.xcodeproj`

## Architecture

Two Swift files, no tests:

- `MacVoiceRecordWidgetApp.swift` - SwiftUI `@main` entry point, `MenuBarExtra` scene with Start/Stop/Quit buttons; menu bar icon switches between `mic` and `mic.fill` (green) based on `isRecording`
- `RecordingManager.swift` - `ObservableObject` that drives recording state; triggers macOS Shortcuts via `shortcuts://run-shortcut?name=Start&input=text&text=<timestamp>` and `shortcuts://run-shortcut?name=Stop` using `NSWorkspace.shared.open`

The app has no audio capture itself. It delegates to two user-created Shortcuts named exactly "Start" and "Stop" which control Voice Memos. The `isRecording` flag is optimistic (set immediately on button tap, not confirmed by actual recording state).

CI builds on push to main via GitHub Actions and uploads a zipped `.app` artifact.
