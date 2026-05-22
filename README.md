# MacRecordWidget

A macOS menu bar app for quick audio and video recording.

## Features

- Menu bar icon (green when recording, mic or camera depending on mode)
- Start/Stop audio recording via macOS Shortcuts (Voice Memos)
- Optional video mode: opens Photo Booth alongside audio
- Toggle between audio-only and audio+video before each session
- Auto-generated timestamp for recording names

## Requirements

- macOS 14.0+
- Two Shortcuts named "Start" and "Stop" that control Voice Memos recording
- Photo Booth (built into macOS) for video mode

## Installation

1. Download `MacRecordWidget.zip` from [GitHub Actions](../../actions) into a `tmp/` folder
2. Unzip and move `.app` to Applications
3. Remove the `tmp/` folder
4. Right-click > Open to bypass Gatekeeper on first launch

## Usage

Click the icon in the menu bar to open the panel. A single row of controls:
- **Video toggle** (camera icon + slider) - enable to open Photo Booth on start; disabled while recording
- **Record button** (red circle) - begins audio recording; opens Photo Booth if video is on
- **Stop button** (square) - stops recording
- **Power button** - quits the app

The panel stays open after starting or stopping. Click the menu bar icon to close it.

First run will prompt to allow Shortcuts access. No Accessibility permission is required.

## Building

Built automatically via GitHub Actions on push to main.
