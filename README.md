# MacVoiceRecordWidget

A macOS menu bar app for quick voice recording control.

## Features

- Menu bar mic icon (green when recording)
- Start/Stop recording via existing macOS Shortcuts
- Auto-generated timestamp for recording names

## Requirements

- macOS 13.0+
- Two Shortcuts named "Start" and "Stop" that control Voice Memos recording

## Installation

1. Download `MacVoiceRecordWidget.zip` from [GitHub Actions](../../actions)
2. Unzip and move `.app` to Applications
3. Right-click > Open to bypass Gatekeeper on first launch

## Usage

Click the mic icon in menu bar:
- **Start** - begins recording with timestamp name
- **Stop** - stops current recording

First run will prompt to allow Shortcuts access.

## Building

Built automatically via GitHub Actions on push to main.
