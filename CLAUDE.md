# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build

Built via GitHub Actions on push to main. Download the artifact from the Actions tab.

## Architecture

Five Swift files, no tests:

- `MacRecordWidgetApp.swift` - SwiftUI `@main` entry point, `.window`-style `MenuBarExtra` (popover panel). Single row, left to right: a pin toggle, ONE audio toggle button (`mic.fill` in red while idle / `stop.fill` on a red fill while recording; a mic rather than a record dot, because a red disc reads as video as readily as audio, and it pairs with the `video.fill` camera toggle), a spacer, a camera toggle button (`video.fill`), then the camera picker and three S/M/L size toggles (all only while the camera is on), and a bordered power button. Every control derives its glyph size, font, `controlSize`, spacing and corner radius from `PanelScale`, plus a constant 1pt outline, so an off toggle and an on toggle read as one control in two states and the whole row scales as a unit. Panel stays open after start/stop. By default it closes when the menu bar icon is clicked or when another app takes focus; the pin toggle suppresses the second of those. The menu bar icon is always `record.circle`; it turns green while recording and gains a small blinking amber dot (blink suppressed under Reduce Motion).
- `RecordingManager.swift` - `@MainActor @Observable` class with `isRecording`, `videoEnabled`, and `isInFlight` state. `startRecording()` is `async throws`: quits Voice Memos first (if open) with a 1.5s wait, then fires `shortcuts://run-shortcut?name=Start&input=text&text=Recording-<timestamp>`. `stopRecording()` fires `shortcuts://run-shortcut?name=Stop`. State is updated only after the shortcut URL opens successfully, and an `isInFlight` guard prevents a second invocation while the first is still running. **Recording is audio only.** Photo Booth is never launched.

Requires two user-created Shortcuts named exactly "Start" and "Stop". No Accessibility permission required. Minimum macOS deployment target is 14.0.

**The app has no video capture.** The camera toggle drives an on-screen preview and nothing else; recording produces an audio memo in Voice Memos. Photo Booth used to be launched for video and that was removed deliberately, because one toggle was silently doing two jobs.

## Gotchas

- Voice Memos must be quit before firing the Start shortcut or macOS raises `VMAudioServiceErrorDomain` error 5. The quit + wait runs inside a `Task { }` using `async`/`await` so the UI doesn't block.
- Do not call `popover.close()` or `panel?.orderOut(nil)` after Start/Stop. The panel intentionally stays open during recording so the user can press Stop without re-opening the popover. Closing is left to the native MenuBarExtra behavior: the menu bar icon click, plus focus loss unless the panel is pinned.
- `NSWorkspace.open` returns `true` whenever something claims the `shortcuts://` scheme, which the Shortcuts app always does. It says nothing about whether the "Start" Shortcut exists or ran, so the app cannot detect a missing or broken Shortcut. Do not read that return value as proof a recording started.

## Live camera preview

Shipped 2026-09-04. The camera toggle opens a live 16:9 preview below the button
row, sized by `PanelScale` (480x270pt at the default medium scale) and running
flush to the panel's left, right and bottom edges. It is display-only: it never
writes a file, and nothing else
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
- `PanelSizer.swift` - drives the panel's `NSWindow` frame, and defines
  `PanelScale`. See the gotcha below.

The session starts when the toggle turns on and stops when the popover closes,
so the camera activity light cycles with the panel by design.

Design artifacts: `projects/20260904-live-camera-preview/` (PRD and mocks), merged
into `projects/master/`.

### Panel scale

`PanelScale` (in `PanelSizer.swift`) owns every dimension that follows from the
S/M/L choice: preview size, glyph size and font, `ControlSize`, row spacing,
padding, corner radius, picker width, and two text fonts. It is one enum on
purpose, because the row and the preview have to scale together and spreading
the numbers across the views is how they drift apart. The choice persists in
`UserDefaults` under `panelScale`.

The preview runs the full width of the panel, so `previewWidth` *is* the panel
width, and `large` is half the screen exactly. It is clamped to at least the
medium width, so a narrow display cannot put the three sizes out of order.

**Three fonts, not one, and they are not interchangeable:**

- `glyphFont` sizes the SF Symbols in the icon buttons.
- `controlFont` sizes text inside AppKit-backed controls, currently the camera
  name. `ControlSize` does **not** carry text size with it: `.regular` still
  draws 13pt, which reads as too small beside 20pt glyphs.
- `scaleLabelFont` sizes the S/M/L letters, and is a point smaller than
  `controlFont` at the small scale. A letter fills its box more solidly than a
  glyph does, so equal point sizes do not give equal visual weight. Matching
  them made S look wrong while the numbers looked consistent.

The size buttons are **`Toggle`s, not a segmented `Picker`**.
`.pickerStyle(.segmented)` is an `NSSegmentedControl` underneath and ignores
SwiftUI's `.font()`, so its labels stayed at 13pt while everything around them
scaled. Do not "simplify" them back into a `Picker` without solving that.

They are only mounted while the preview is open. A consequence worth knowing:
leaving the scale on `large` and closing the preview leaves an oversized button
row with no visible control to shrink it until the camera goes back on.

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
- **The panel width is constant across camera on/off, but not across scales.**
  Toggling the camera only ever changes the height. Changing S/M/L does change
  the width, and that is fine: the panel is right-anchored, so only the left
  edge moves, and the screen-update suppression above covers a width change the
  same way it covers a height change. An earlier version of this file claimed
  the width could never change; that rule predated the suppression fix
  (`c718a9d` froze the width, `13ac77e` fixed the flicker afterwards) and was
  never revisited.
- **AppKit grows the panel to fit content but never shrinks it back.** Without an
  explicit frame the panel strands at full size with the collapsed row floating
  in the middle of it.
- **Padding order matters.** `.frame(width:)` must size the content *before*
  `.padding` is added outside it, or the row is squeezed by the padding.
- **Padding belongs to the button row, not to the panel.** The outer `VStack`
  has `spacing: 0` and no padding, so the preview runs flush to the panel's
  left, right and bottom edges. Only the preview's bottom corners are rounded,
  matching the window; square ones poke out past it.
- The button row is leading-aligned (`.frame(maxWidth: .infinity, alignment: .leading)`).
  An `HStack` in a fixed-width frame with no alignment argument centers, so the
  row slides instead of filling the panel.
- **The pin toggle fights an undocumented behaviour too.** `MenuBarExtra(.window)`
  closes its panel by ordering it out when the window resigns key, and there is
  no public switch for that. `PanelSizer.keepVisibleIfPinned` re-shows the
  window on `didResignKeyNotification`, twice: once synchronously (in case the
  order-out already ran) and once on the next runloop pass (in case it has not).
  `hidesOnDeactivate` is also forced off, because the app is `LSUIElement` and
  deactivates the moment another app is clicked. The pinned state persists in
  `UserDefaults` under `panelPinned`.

### Verified on hardware (these were open questions in the design)

- The panel does **not** pin its own trailing edge, contrary to what the design
  assumed. It anchors to the status item; right-alignment is something
  `PanelSizer` imposes, flush against the screen's visible frame
  (`screenMargin` is 0).
- The resize is **not** animated. Animating it animates the reverted origin too,
  which slides the panel across the screen before the correction lands.
- Camera contention with Photo Booth is **moot**: Photo Booth is no longer
  launched, so nothing competes for the device.

### Swift 5.9 (CI builds with Xcode 15.2)

The local toolchain on a current Mac is newer than CI's and accepts things CI
rejects. This has cost a red build twice, so check against 5.9 rules rather than
against what compiles locally.

- **`@MainActor` is not inferred** on `App` or on view bodies.
  `MacRecordWidgetApp`, `MenuBarIcon`, `CameraPreviewPanel` and
  `CameraPreviewLayerView` carry explicit annotations for that reason.
- **Switch expressions do not mix with switch statements.** Adding a case that
  needs more than one statement turns the whole `switch` into a statement, and
  the remaining one-line cases stop being implicit returns. Either every case
  is a bare expression, or every case says `return`. See
  `PanelScale.previewWidth`.

A local `swiftc -typecheck` will not catch either of these. Only CI will.

### Source layout exception

Swift sources live in `MacRecordWidget/`, not `src/`. This is a deliberate,
standing exception to the `src/` convention documented in `.claude/tech-config.md`:
the directory name is the Xcode target's group and changing it means
restructuring `MacRecordWidget.xcodeproj`. Do not "fix" it by moving files.

Adding a source file requires four `project.pbxproj` edits by hand
(`PBXBuildFile`, `PBXFileReference`, the group's `children`, and the sources
build phase). The project uses classic file references, not synchronized groups.
