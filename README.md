# MacRecordWidget

A macOS menu bar app for starting and stopping audio recordings without leaving
whatever you are working on.

The app records **audio only**, through the Shortcuts app, into Voice Memos.
There is a live camera preview, but it is display-only: it exists so you can see
yourself while recording, and it never writes a video file.

## Features

- One-click audio recording from the menu bar, saved to Voice Memos with a
  timestamped name
- Menu bar icon turns green with a blinking dot while recording
- Live camera preview inside the panel, with a picker for which camera to show
- A pin toggle that keeps the panel open when you click into another app
- Three panel sizes (S/M/L) that scale the whole UI, not just the preview

## Requirements

- macOS 14.0 or later
- Two Shortcuts named exactly `Start` and `Stop` that begin and end a Voice
  Memos recording. The app does not create these for you.

No Accessibility permission is needed. Turning on the camera preview prompts for
camera access the first time.

## Installation

Run once, to create a local signing certificate:

```bash
scripts/create-signing-cert.sh
```

Then, for this and every later build:

```bash
scripts/install-latest.sh
```

That downloads the latest successful CI build, signs it, installs it to
`/Applications` and launches it.

### Why the certificate

CI builds are ad-hoc signed, with no Team ID and no certificate. macOS has
nothing stable to attach a permission grant to, so it pins your camera approval
to that one binary's hash. Every new build has a different hash, the grant stops
matching, and you get asked for camera access again.

Signing each build with the same local certificate gives the app a stable code
identity, so one grant covers later builds.

### Manual install

If you would rather not use the scripts: download `MacRecordWidget.zip` from the
[Actions tab](../../actions), unzip it, move `MacRecordWidget.app` to
`/Applications`, and right-click > **Open** on first launch. You will be
re-asked for camera access after every build.

## Usage

Click the menu bar icon to open the panel. The controls run left to right:

| Control | What it does |
|---|---|
| **Pin toggle** (pin icon) | Off, the panel closes when you click another app. On, it stays open. The setting persists across launches. |
| **Audio toggle** (red record circle / stop square) | Starts and stops the audio recording. One button in two states, not two buttons. |
| **Size picker** (S / M / L) | Scales the entire panel: controls, spacing and preview. At L the panel is half your screen wide, so it sits alongside a window tiled to the other half. Only appears while the preview is on. The choice persists across launches. |
| **Camera toggle** (video icon) | Shows or hides the live preview below the row. It has no effect on what is recorded. |
| **Camera picker** | Chooses which camera feeds the preview. Only appears while the preview is on. |
| **Power button** | Stops any recording in progress, then quits. |

The panel stays open after you start or stop a recording, so you can press stop
without reopening it. Clicking the menu bar icon closes it either way, pinned or
not.

The first recording will prompt you to allow the app to run Shortcuts.

### A caveat about the Shortcuts

The app fires a `shortcuts://` URL and macOS reports success as long as
something claims that URL scheme, which the Shortcuts app always does. It cannot
tell whether your `Start` shortcut actually exists or ran. If the shortcut is
missing or broken, the app will still show itself as recording. Check Voice
Memos if you are unsure.

## Building

Pushes to `main` build the app in GitHub Actions. There is no supported local
build path; download the artifact from the Actions tab.

Developer notes, including the AppKit behaviours the panel positioning and pin
depend on, are in [CLAUDE.md](CLAUDE.md).
