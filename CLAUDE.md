# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build

Built via GitHub Actions on push to main. Download the artifact from the Actions tab.

## Architecture

Six Swift files, no tests:

- `MacRecordWidgetApp.swift` - SwiftUI `@main` entry point, `.window`-style `MenuBarExtra` (popover panel). Single row, left to right: a pin toggle, ONE audio toggle button (`mic.fill` in both states, plain while idle and on a red fill while recording; a mic rather than a record dot, because a red disc reads as video as readily as audio, and it pairs with the `video.fill` camera toggle. The glyph does **not** swap to `stop.fill` — every toggle in the row keeps its glyph and flips its fill, and this one used to be the exception. While recording it also carries a blinking amber `RecordingDot` on its bottom-right corner, giving the state a second, non-hue channel), a `RecordingTimer` showing MM:SS in a bordered box, grouped tight against the mic and faded while idle (`lineLimit(1)` + `fixedSize()` are load-bearing: at the small scale the row is tight enough that the value otherwise wraps mid-digit), then a **video record toggle** (`video.fill`) inside that same tight group, a spacer, the camera picker, three S/M/L preview-size toggles, and a bordered power button. The video button is grouped with the mic and timer, not with the camera picker, because it is a record control sharing that timer; filing it beside the picker would read as a preview setting, which is what it used to be and is no longer. Every control derives its glyph size, font, `controlSize`, spacing and corner radius from `PanelScale`, plus a constant 1pt outline, so an off toggle and an on toggle read as one control in two states and the whole row scales as a unit. Panel stays open after start/stop. By default it closes when the menu bar icon is clicked or when another app takes focus; the pin toggle suppresses the second of those. The menu bar icon is always `record.circle`; it turns green while recording and gains a small blinking amber dot (blink suppressed under Reduce Motion).
- `RecordingManager.swift` - `@MainActor @Observable` class with `isRecording`, `medium` (`.audio` / `.video` / nil), and `isInFlight` state, plus the recording clock: `startedAt` and `lastElapsed`. Elapsed time is **derived from a start `Date`, never accumulated by a ticking counter**, so it stays correct while the panel is closed and cannot drift; `RecordingTimer` renders it with a `TimelineView` and there is no timer to invalidate. The clock resets when a recording *starts*, not when it stops, so the previous duration stays readable until a new one begins. `startRecording()` is `async throws`: quits Voice Memos if it is running (a fallback now, see Gotchas), fires `shortcuts://run-shortcut?name=Start&input=text&text=Recording-<timestamp>`, then holds `isArming` for `armingDelay` before flipping to `isRecording`. `stopRecording()` fires `shortcuts://run-shortcut?name=Stop`, cancels any pending arming task, and quits Voice Memos a couple of seconds later. State is updated only after the shortcut URL opens successfully, and an `isInFlight` guard prevents a second invocation while the first is still running. `startVideoRecording(camera:)` / `stopVideoRecording(camera:)` drive the in-app movie capture through the *same* arming delay and the *same* clock.

**The two mediums are mutually exclusive.** `medium` is the whole of the mode state: it is claimed on button press, released on any failure path (via the `committed` flag and `defer` -- forget that and the app is stuck in a mode that never started), and each button is disabled while the other holds it. This is not a limitation to be lifted later: one shared timer cannot honestly describe two recordings that began at different moments, and that is exactly why the design is exclusive.

Requires two user-created Shortcuts named exactly "Start" and "Stop". No Accessibility permission required. Minimum macOS deployment target is 14.0.

**Video is captured in-app, not by Photo Booth.** Photo Booth is never launched or scripted -- it has no `sdef`, no `NSAppleScriptEnabled` and no URL scheme, so the only way to drive it would be UI scripting through System Events, and that would mean requesting Accessibility permission the app has deliberately never needed. Instead `AVCaptureMovieFileOutput` writes an H.264 + AAC `.mov` directly into Photo Booth’s library folder. See "Photo Booth library" below, and read it before touching that code.

## Gotchas

- Voice Memos must not be running when the Start shortcut fires, or macOS raises `VMAudioServiceErrorDomain` error 5. **The quit happens in `stopRecording()`, not before the next start.** The app still checks and quits at start as a fallback, but on the common path Voice Memos is already gone and that check costs nothing. Moving it took ~1.5s of dead time out of the moment the user is waiting to speak.
- **There is no signal for "Voice Memos is now capturing."** Measured 2026-09-06: the `.m4a` does not appear in `~/Library/Group Containers/group.com.apple.VoiceMemos.shared/Recordings/` until *after* Stop; the process is up 1.3s before audio flows; and the filename timestamp records when the shortcut fired, not when recording began. So none of those can drive a "recording is live" indicator, and `RecordingManager.armingDelay` is a measured constant instead.
- **Audio is lost between firing Start and actual capture.** Measured by firing Start, waiting a known interval, firing Stop, and comparing against the audio duration of the resulting file: 1.54s with Voice Memos quit first, 0.88-0.93s with it left running (n=3, spread 0.05s). This is why the first words of a recording used to be cut off. `isArming` holds the UI in a "starting" state so the user is not invited to speak into a mic that is not listening yet.
- **The "must quit or error 5" rule did not reproduce.** Four warm starts with Voice Memos running all recorded fine. The quit is kept anyway: four successes are not enough to delete a documented failure mode whose trigger conditions are unknown, and it is now free on the hot path.
- Do not call `popover.close()` or `panel?.orderOut(nil)` after Start/Stop. The panel intentionally stays open during recording so the user can press Stop without re-opening the popover. Closing is left to the native MenuBarExtra behavior: the menu bar icon click, plus focus loss unless the panel is pinned.
- `NSWorkspace.open` returns `true` whenever something claims the `shortcuts://` scheme, which the Shortcuts app always does. It says nothing about whether the "Start" Shortcut exists or ran, so the app cannot detect a missing or broken Shortcut. Do not read that return value as proof a recording started.

## Live camera preview

Shipped 2026-09-04, made permanent 2026-09-09. A live 16:9 preview sits below
the button row, sized by `PanelScale` (480x270pt at the default medium scale)
and running flush to the panel's left, right and bottom edges.

**There is no preview toggle and there must not be one.** The preview is the
app's resting state: the panel opens showing the camera, always. The
`video.fill` button that used to collapse it now records video instead. A
consequence worth knowing: the S/M/L toggles are mounted unconditionally now,
which incidentally fixed the old bug where leaving the scale on `large` and
closing the preview stranded an oversized button row with no visible control to
shrink it.

Three files implement it:

- `CameraManager.swift` - `@MainActor @Observable` owner of the `AVCaptureSession`
  *and* of movie capture (`startRecording()` / `stopRecording()`).
  `stopRecording()` awaits `didFinishRecordingTo` via `MovieRecordingDelegate`
  before returning: `AVCaptureMovieFileOutput` closes its file asynchronously,
  and a process that terminates first leaves an unplayable `.mov`. The quit
  button awaits it for exactly that reason. The microphone input is attached
  lazily on the first video recording, not at session setup, so merely opening
  the panel never triggers a mic permission prompt.
  Distinguishes every permission state; `restricted` deliberately offers no
  "Open Settings" action because that pane cannot resolve an MDM restriction.
  Camera choice persists in `UserDefaults`; the picker is disabled during a
  video recording, and `select()` refuses anyway, because reconfiguring the
  session mid-write truncates the movie. A disconnect falls back to another
  camera *without* clearing the stored preference, so reconnecting the preferred
  device restores it. Mirroring is hardcoded **off** (changed 2026-09-10):
  the preview and the saved movie show the scene the way everyone else sees it,
  so text held up to the camera reads correctly. There is no user-facing toggle
  and the stored preference is deliberately not read. `applyMirroring` is
  `nonisolated static` and runs on `sessionQueue`, never on the main actor --
  connection properties take the session lock. It also owns `previewLayer`, a
  single `AVCaptureVideoPreviewLayer` created at init and never released, and a
  watchdog that fails the start after 10s instead of spinning forever. See the
  deadlock note below.
- `CameraPreviewView.swift` - `AVCaptureVideoPreviewLayer` inside an
  `NSViewRepresentable`, because macOS 14 has no SwiftUI-native camera preview.
  The layer is **passed in, not created here**, and the view stays mounted in
  every state (message states draw over it while it sits at `opacity(0)`), for
  the deadlock reason below.
  `CameraControls` holds the picker, which lives in the button row rather than
  under the preview; its selected value doubles as the camera-name indicator,
  naming the device actually feeding the layer rather than the stored preference.
- `PanelSizer.swift` - drives the panel's `NSWindow` frame, and defines
  `PanelScale`. See the gotcha below.

**The session is configured once and kept configured for the app's lifetime.**
Closing the panel calls `CameraManager.pause()`, which only calls
`stopRunning()` -- inputs, outputs and the negotiated format all stay in place.
The camera activity light still cycles with the panel, which is the privacy
behaviour that matters, but reopening no longer pays for device discovery,
`AVCaptureDeviceInput` creation and format negotiation all over again.

`pause()` **refuses to stop while `isRecordingVideo` is true.** This is what
lets a video recording survive the panel closing: unlike audio, which lives in
another process, the movie file lives inside this session, so stopping it
mid-write truncates the recording.

### The "Starting camera…" hang was a deadlock, not slowness

Fixed 2026-09-10. Diagnosed from a `sample` of a hung build, not inferred:

- **Main thread:** CoreAnimation transaction commit ->
  `AVCaptureVideoPreviewLayer dealloc` -> `setSession:` ->
  `AVCaptureSession commitConfiguration` -> blocked on the session's `objc_sync`
  lock.
- **Session queue:** `CameraManager.configure(for:)` -> `commitConfiguration`
  -> `_stopAndTearDownGraph` -> `AVCaptureMovieFileOutput
  graphWillStopForSession:` -> `performSelector:onThread:waitUntilDone:YES`
  **waiting on the main thread**.

An ABBA deadlock between the session lock and the main thread. It fires when the
preview layer is deallocated (the panel closing, or the state leaving `.running`
unmounting the view) while the session queue is reconfiguring. Neither side can
proceed and the app has to be killed.

Three rules follow, and breaking any one of them brings the hang back:

- **The preview layer is created once, owned by `CameraManager`, and never
  deallocated.** A layer that cannot dealloc cannot take the session lock on the
  main thread. This is why `CameraPreviewLayerView` takes a layer instead of a
  session, and why the preview view is mounted in every state.
- **Nothing on the main actor touches `session`, `movieOutput` or their
  connections.** Not `session.isRunning` (mirrored in `isSessionRunning`), not
  `startRecording`/`stopRecording` on the movie output, not `beginConfiguration`
  for the mic input, not mirroring. Every one of those takes the session lock,
  which `startRunning()` can hold for an unbounded time on a contended external
  camera.
- **The start is bounded by a watchdog.** `AVCaptureSession` has no timeout
  anywhere: if a device never yields a frame, `.starting` lasts forever. After
  10s the state becomes `.failed` with a "Try Again" button wired to
  `CameraManager.retry()`.

Diagnostics go to `os.Logger(subsystem: "com.macrecordwidget", category: "camera")`:
device count, chosen device, `startRunning()` duration, first-frame latency,
watchdog trips, recording start and stop. Watch them with:

```
log stream --predicate 'subsystem == "com.macrecordwidget"' --info --debug
```

### Why the preview used to take 2-3 seconds

Two separate causes, both fixed 2026-09-09:

- **The main thread was blocked.** `AVCaptureDeviceInput(device:)` opens the
  hardware and `commitConfiguration()` negotiates a format, and both used to run
  on the main actor. Only `startRunning()` was dispatched to `sessionQueue`.
  All of it now happens on `sessionQueue`; only the resulting state hops back.
- **`.running` was set when `startRunning()` was *dispatched*,** not when frames
  arrived, so `CameraPreviewLayerView` mounted over an empty layer and the user
  watched black. There is now a `.starting` state held until a real sample
  buffer arrives, and the preview shows a spinner and "Starting camera…".

The first-frame signal comes from a `AVCaptureVideoDataOutput` whose only job is
`FirstFrameWatcher`. There is no callback for "the preview layer has something
to draw", and `startRunning()` returning is not the same thing, so a sample
buffer is the only honest signal. After the first one the delegate does nothing
but check a flag.

## Photo Booth library

Video recordings are written into `~/Pictures/Photo Booth Library/Pictures/` so
they appear in Photo Booth's filmstrip. Everything here was established by
measurement on 2026-09-09, not from documentation. `PhotoBoothLibrary.swift`
owns it.

- **`Recents.plist` is the filmstrip index, not a "recently viewed" list.**
  Measured: with three valid `.mov` files on disk and that array empty, Photo
  Booth showed *nothing at all*. Recording one movie added exactly one entry and
  exactly one thumbnail. Files present on disk but absent from the array are
  ignored entirely.
- **⚠️ Writing `Recents.plist` badly is destructive.** An external edit that
  added one entry caused Photo Booth, on next launch, to move **every file
  listed in the array** to the Trash and empty the array. Four files went to the
  Trash, three of them real user recordings. Do not experiment against a library
  that has anything in it worth keeping.
- **The app never writes the plist while Photo Booth is running.**
  `addToFilmstrip` returns `false` in that case and the movie is simply left on
  disk unindexed. Photo Booth holds its own copy of the array in memory and
  rewrites the file on quit, so writing underneath it either gets clobbered or
  clobbers its entries.
- **The filename separator before AM/PM is U+202F NARROW NO-BREAK SPACE,** not a
  plain space. Verified by hex dump of every movie Photo Booth has written. A
  name built with an ASCII space is a *different filename*; a `cp` using one
  fails with "No such file or directory" against a name that `ls` just printed.
  It is written into the `DateFormatter` format string literally rather than
  left to the locale, so an OS update that changes CLDR's time pattern cannot
  move it.
- Photo Booth's naming resolves only to the minute, so a second recording inside
  the same minute collides. `availableMovieURL` suffixes ` 2`, ` 3` rather than
  overwriting: losing a recording the user just made is the worst available
  outcome.

**Still unverified:** whether a movie written natively by
`AVCaptureMovieFileOutput` renders a correct thumbnail and duration in the
filmstrip. A file placed there by `cp` showed up as a blank 00:00 entry, but
that copy also carried a `com.apple.quarantine` flag and a
`com.apple.provenance` xattr the shell added, and had no Spotlight metadata
(`kMDItemDurationSeconds` was null where a native recording had a real value).
Those are artifacts of the test method, not necessarily of the approach. If
recordings show up blank, that xattr/Spotlight difference is the first place to
look.

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
- Camera contention with Photo Booth is **moot**: Photo Booth is still never
  launched, so nothing competes for the device. Video is captured by this app's
  own session, which is also why the preview and the recording cannot disagree
  about which camera is in use.

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

`INFOPLIST_KEY_NSMicrophoneUsageDescription` is set in **both** build
configurations. It is not optional: the moment the session adds an audio input
without it, macOS terminates the app on the spot. The camera key's text was
also rewritten, because it used to promise the preview "is never saved".

Adding a source file requires four `project.pbxproj` edits by hand
(`PBXBuildFile`, `PBXFileReference`, the group's `children`, and the sources
build phase). The project uses classic file references, not synchronized groups.
