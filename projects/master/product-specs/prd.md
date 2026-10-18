> Status: Draft (PM), pending human re-approval
> Last approved: 2026-09-04 (superseded by the revisions below)
> Updated: 2026-10-05

# PRD: MacRecordWidget (Master)

Consolidated product baseline. Describes the app **as it actually ships today**.

**Shipped:** production polish (2026-05-18), popover button layout (2026-05-21), live camera preview (2026-09-04), panel pinning and scaling (2026-09-05), recording timer and arming state (2026-09-06), in-app video recording and permanent preview (2026-09-09), preview mirror toggle and camera menu (2026-09-20), semantic capsules (2026-09-24), two-hue palette (2026-09-28), last recording playback (2026-10-15), playback seek, mirrored playback, deleted-file fallback, browse and delete (2026-10-18).

> **Reading this document:** every unmarked statement describes current, shipped behaviour, verified against the Swift sources on 2026-10-05. Criteria later revisions invalidated are kept in **Superseded acceptance criteria** with the reason and date, so the decision trail survives.

## Goals

**Product goal:** one-click audio or video recording from the macOS menu bar, with no window, no dock icon, and no context switch. A live camera preview is always on in the panel, so framing is checked before and during a video recording.

| Goal | Success metric |
|------|---------------|
| Zero-friction recording | Start or stop an audio or video recording in one click from the menu bar panel. |
| Chained sessions | Stop a recording and start a new one without reopening the widget. |
| No lost first words | The UI holds a "starting" state until capture is live, so the user is never invited to speak into a mic that is not listening. |
| One timer, one meaning | Audio and video are mutually exclusive, so the single MM:SS timer always describes exactly one recording. |
| One control per idea | Each control does exactly one thing. No control silently triggers a second effect. |
| Colour means one thing | Red means "you are being recorded". Blue means every other lit control. No third hue. |
| Fits any display | Three panel sizes. Every dimension derives from one choice, so the row and the preview never drift apart. |
| Stays put on demand | The panel can be pinned so another app taking focus does not fold it away. |
| Native macOS feel | Semantic system colours, correct in light and dark mode, honouring Reduce Motion and Increase Contrast. |
| Reliable lifecycle | Rapid or double taps never fire a duplicate shortcut. Failed launches never leave the UI in a false state. Quitting never leaves an unplayable movie. |
| Idiomatic Swift | No deprecated observation APIs. No raw `DispatchQueue` on the UI path. No optimistic state divergence. |

**Non-goals:**
- No backend, web frontend, or infrastructure
- No audio path other than the two Shortcuts ("Start", "Stop") into Voice Memos
- No simultaneous audio and video recording. Exclusivity is a design decision, not a limitation to lift later: one timer cannot describe two recordings that began at different moments
- No launching, scripting, or UI-automating Photo Booth (it would need Accessibility permission the app never asks for)
- No App Store submission prep (icons, metadata, entitlements)
- No XCUITest automation (manual smoke testing only)

---

## Two mediums, one timer

The app records **audio or video, never both at once**.

| | Audio | Video |
|---|---|---|
| Button | `mic.fill` (`recordToggle`) | `video.fill` (`videoRecordToggle`) |
| Captured by | Voice Memos, via the "Start" and "Stop" Shortcuts | This app's own `AVCaptureMovieFileOutput` (H.264 + AAC `.mov`) |
| Lands in | Voice Memos | `~/Pictures/Photo Booth Library/Pictures/`, indexed into Photo Booth's filmstrip |
| Timer | Shared | Shared |
| Survives the panel closing | Yes (another process) | Yes (the session refuses to stop mid-write) |

- Pressing either button claims the medium. The other button is disabled until it is released.
- Any failure releases the medium, so the app is never stuck in a mode that never started.
- Photo Booth is never launched. The app writes into its library folder only.

---

## Elevator pitch

MacRecordWidget is a menu bar app that records audio or video in one click. Audio fires two user-created Shortcuts ("Start" and "Stop") into Voice Memos. Video is captured in-app and written straight into Photo Booth's library. A live camera preview is always on below one row of icon controls, with a shared MM:SS timer. The panel has three sizes (S/M/L) and can be pinned so it survives losing focus.

---

## Problem

Starting a recording normally means finding an app, waiting for it to launch, and clicking through its UI. Voice Memos also blocks the Shortcuts audio path if it is already open, which produces a cryptic `VMAudioServiceErrorDomain` error 5.

Prior versions of the widget added their own friction:
- A recording-status dot in the popover flickered and carried no actionable information
- Start and Stop were two separate buttons, one of which was always disabled
- The popover dismissed itself after Start, so stopping required reopening it
- The video toggle overloaded two effects (preview plus a Photo Booth launch) onto one click
- The panel folded away as soon as another app was clicked
- One fixed panel size served every display
- The first ~1.5s of every audio recording was lost, because the UI said "recording" before Voice Memos was capturing
- There was no way to record video at all after the Photo Booth launch was removed
- A third hue (camera green) sat beside blue controls and read as an unexplained state

---

## Target audience

**Primary:** the developer and sole author, who uses the app daily and maintains it.
**Secondary:** anyone who installs the build and has the two Shortcuts configured.

---

## Features (shipped)

**Menu bar**
- Menu bar icon (`record.circle`) that turns green while either medium is recording, with a blinking amber badge dot that respects Reduce Motion
- The icon never changes glyph

**Button row (left to right)**
- Pin toggle (`pinToggle`): `pin.slash` off, `pin.fill` on, blue when on. Keeps the panel on screen when another app takes focus. Persisted
- **Record group**, packed at half the row spacing:
  - Audio toggle (`recordToggle`): `mic.fill` in both states. Red capsule while recording, with a blinking amber dot on its bottom-right corner
  - Timer (`recordingTimer`): MM:SS in a bordered box. Full strength while recording, faded (secondary, 65% opacity) while idle, still showing the last duration
  - Video toggle (`videoRecordToggle`): `video.fill` in both states. Same red capsule and amber dot as the mic
- Mirror toggle (`mirrorToggle`): Flip Horizontal glyph, blue when on. At full row spacing, outside the record group, because it acts on the preview, not on a recording
- A spacer
- Camera menu (`cameraPicker`): label names the camera actually feeding the preview, with a chevron in a blue well
- Three S/M/L size toggles (`panelScalePicker`), blue when selected
- Quit button (`quitButton`): `power` glyph, a permanent blue capsule. Finishes any recording, then terminates
- No text label anywhere in the row. Every control is a glyph, a single letter, the timer, or the camera name

**Tooltips and VoiceOver**

| Control | Tooltip | VoiceOver label |
|---------|---------|-----------------|
| Audio toggle | "Record audio to Voice Memos" / "Starting… wait to speak" / "Stop and save to Voice Memos" | same as tooltip |
| Video toggle | "Record video to Photo Booth" / "Starting… wait to perform" / "Stop and save to Photo Booth" / "Stop the audio recording first" / the camera's unavailable reason | same as tooltip |
| Timer | none | "Recording time" |
| Mirror toggle | "Mirror the preview" (off) / "Show the preview as others see it" (on) | same as tooltip |
| Pin toggle | "Keep panel open" / "Let panel close on its own" | "Keep panel open" |
| Camera menu | none | "Preview camera" |
| S/M/L | "Small preview" / "Medium preview" / "Large preview" | "Small preview size", and so on |
| Quit | "Quit" | "Quit MacRecordWidget" |

**Control chrome (semantic capsules)**
- Off: a rounded rect at the scale's corner radius, `controlBackgroundColor` fill, 1pt `separatorColor` outline, glyph in `labelColor`
- On: a fully round capsule filled with a semantic hue, white glyph, no outline (the fill is the edge)
- Two hues only: red `#FF383C` for a live recording (audio and video alike); blue `#007AFF` for every other lit control (pin, mirror, S/M/L, camera chevron well, Quit)
- The user's accent colour is not honoured in the row
- Width never changes between off and on: `controlPaddingH` is 4pt in both states
- Every control, including the timer and camera menu, is pinned to `PanelScale.controlHeight`
- Every size, font, spacing, and radius derives from the chosen panel scale
- No focus ring on any control (`focusEffectDisabled`)

**Live Ember**
- A capturing record button wears an animated red gradient instead of the flat fill: a 3.4s drift with a breathing outer glow
- Driven by `TimelineView(.animation)`, so nothing needs invalidating when recording stops
- Collapses to the flat red fill under Reduce Motion, and separately under Increase Contrast
- Shown only while genuinely capturing, not while arming

**Audio recording**
- Voice Memos is quit after Stop (about 2s later), so it is usually gone before the next Start. If it is still running at Start, it is quit with a 1.5s wait as a fallback
- Start fires `shortcuts://run-shortcut?name=Start` with a timestamped recording name as text input
- Stop fires `shortcuts://run-shortcut?name=Stop`
- In-flight guard prevents a duplicate shortcut invocation
- A failed shortcut launch throws `shortcutLaunchFailed` and surfaces through an `NSAlert`

**Arming**
- After either button is pressed, the UI holds an "arming" state for a measured 3s before showing "recording"
- During arming the pressed button's glyph dims to 35%, it is disabled, and its tooltip says "Starting… wait to speak" (audio) or "Starting… wait to perform" (video)
- The red fill, amber dot, ember, and running timer all arrive together when arming ends: that is the "speak now" signal

**Video recording**
- Captured by the app's own session into `~/Pictures/Photo Booth Library/Pictures/`, named the way Photo Booth names movies
- Added to Photo Booth's filmstrip index only while Photo Booth is not running; otherwise the movie is left on disk unindexed
- A name collision within the same minute is suffixed (" 2", " 3"), never overwritten
- The recording is never mirrored, whatever the preview shows
- Microphone access is requested on the first video recording, not when the panel opens. Denied shows an alert pointing to System Settings
- Available only while the preview is running; otherwise the button is disabled and its tooltip says why
- The camera menu is disabled while a video recording is in progress

**Camera preview**
- Always on. There is no preview toggle: the panel always opens showing the camera
- Live 16:9 preview below the button row, as wide as the panel (480x270pt at medium)
- Flush to the panel's left, right, and bottom edges. Only its bottom corners are rounded
- Mirror toggle, default on, persisted. Preview only; never disabled
- Camera menu across all connected video devices, persisted, with fallback when the stored device is missing
- A "Starting camera…" state until the first real frame arrives, with a 10s watchdog that fails to a "Try Again" action
- Distinct inline states for permission not determined, denied, restricted, no camera, and failure

**Panel**
- Three sizes, chosen with the S/M/L toggles and persisted: small, medium (default), large
- Width is the scale's preview width: 380 / 480 / half the screen's visible width (never below 480)
- Flush against the right edge of the screen's visible frame (zero margin)
- Not draggable, and the resize is not animated

**Panel lifecycle**
- The panel stays open through Start and Stop
- Unpinned (default): it closes on a menu bar icon click, or when another app takes focus
- Pinned: only a menu bar icon click closes it
- Closing the panel pauses the camera (activity light off) but keeps the session configured, so reopening is fast. It does not pause during a video recording

---

## Last recording playback

Mocks: [playback.html](../mocks/playback.html).

- The timer box is also the play button. Its glyph names the medium (`waveform` audio, `play.rectangle.fill` video, disabled `play.fill` when nothing exists) and its digits show the recording length, the playback position while playing, or the recording clock while recording.
- Audio plays in place with a scrubber along the bottom of the live camera preview. Audio is play/stop only, no pause.
- Video plays over the preview surface with pause, scrubber and "Live Camera". It is drawn the same way round as the preview: mirrored by default, flipped with the mirror toggle. The file itself is never mirrored.
- Both scrubbers end in a trash button.
- Right-clicking the timer box offers Play Last Recording, Previous Recording, Next Recording and Move to Trash….
- Previous/Next walk every `.mov` in Photo Booth's library and every `.m4a` in Voice Memos by creation date, including recordings made outside the app.
- If the shown recording has been deleted, the box falls back to the newest recording left, audio or video, or disables if none remain. Checked on panel open and after a failed play, not by a file watcher.

**Open risk:** Move to Trash removes only the file. Photo Booth's `Recents.plist` and Voice Memos' library are not updated; how each app reacts has not been tested.

## Conceptual data model

- One **Recording state** in memory, never persisted: idle, arming, or recording; a **medium** (audio, video, or none); in flight or settled.
- The medium is the whole of the mode state. At most one medium is held at a time.
- A **Recording clock** holds a start time and the last elapsed duration. Elapsed time is derived from the start time, never counted up. It resets when a recording starts, not when it stops.
- Audio drives two **Shortcuts** by name: "Start" and "Stop". Both must exist in the user's Shortcuts app.
- One **Capture session** lives for the app's lifetime. It feeds the preview and, while video records, a **Movie file**.
- A Movie file is written into the **Photo Booth library** and optionally listed in its filmstrip index.
- The session shows exactly one **Camera device**: a stable unique identifier, a display name, a connected status.
- The session has a **status**: idle, starting, running, or a message state (not determined, denied, restricted, no camera, failed).
- Four **Preferences** outlive a launch: selected camera identifier, mirror flag, pinned flag, panel scale. One **Last recording** also persists: medium, file URL, duration.
- A **Panel scale** is small, medium, or large, and derives every dimension in the panel.

---

## Roadmap

### Shipped

| Phase | Date | Contents |
|-------|------|----------|
| Production polish | 2026-05-18 | HIG pass on controls, `@Observable` migration, macOS 14 target, structured concurrency, typed errors, in-flight guard, non-optimistic state |
| Popover button layout | 2026-05-21 | Popover status dot removed, single horizontal row, popover stays open through Start and Stop |
| Live camera preview | 2026-09-04 | Preview surface, `PanelSizer`, camera picker in the row, permission and failure states, camera-ID persistence |
| Post-ship UI revisions | 2026-09-04 | Record and Stop merged into one toggle, Photo Booth launch deleted, mirror toggle removed, control strip removed |
| Pinning and scaling | 2026-09-05 | Pin toggle, S/M/L scaling via `PanelScale`, edge-to-edge preview, panel flush to the screen edge, `mic.fill` glyph, "Audio" label removed |
| Timer and arming | 2026-09-06 | MM:SS timer derived from a start date, 3s arming state, Voice Memos quit moved to Stop |
| In-app video | 2026-09-09 | `video.fill` records video into the Photo Booth library, mutual exclusion with audio, preview made permanent, session kept configured across panel close |
| Deadlock fix | 2026-09-10 | Preview layer owned and never deallocated, session work off the main actor, 10s start watchdog |
| Mirror and camera menu | 2026-09-20 | Preview-only mirror toggle (default on), movie output pinned unmirrored, camera picker rebuilt as a Menu of Buttons, small width 320 to 380 |
| Semantic capsules | 2026-09-24 | Off/on capsule chrome, Live Ember, `controlHeight` on every control, large re-sized for Photo Booth parity |
| Two-hue palette | 2026-09-28 | Camera green removed; red for capture, blue for everything else; constant control width |
| Last recording playback | 2026-10-15 | Timer box becomes the play button; audio plays in place, video over the preview surface |
| Playback extensions | 2026-10-18 | Audio scrubber, video playback follows the mirror toggle, fallback when the last recording is deleted, Previous/Next and Move to Trash |

### Deferred

| Item | Why deferred |
|------|-------------|
| XCUITest automation | Manual smoke testing covers the row |
| App Store submission (icons, metadata, entitlements) | Distribution is via GitHub Actions artifact |
| Additional audio modes or Shortcuts | No demand yet; would expand the single-row UI |
| Preview snapshot or still capture | No demand; video covers capture |
| Detached or full-screen preview window | Contradicts the menu-bar-only product shape |
| Keeping the camera running while the panel is closed (outside video recording) | The activity light cycling with the panel is the privacy behaviour that matters |
| Multi-camera simultaneous preview | Would not fit the panel at any scale |
| A user-resizable panel (drag handle) | Three fixed scales cover the need; a drag handle fights AppKit's anchoring |
| Honouring the user's accent colour in the row | Blue and red carry fixed meanings; an accent colour could collide with red |
| Re-sizing small and medium to match large's 2026-09-24 pass | To be measured on hardware first; the three scales do not currently step evenly |

---

## App flows

### Site map

| Surface | Purpose |
|---------|---------|
| Menu bar icon | Always-visible status. Green while either medium records. Click toggles the panel. |
| Panel, button row | Pin, record group (mic, timer, video), mirror, camera menu, S/M/L, Quit. |
| Panel, preview area | Always present. Live image or an inline state message. Flush to the panel's left, right, and bottom edges. |
| Photo Booth | External. Where video recordings appear. Never launched by the app. |
| System Settings, Privacy & Security, Camera / Microphone | External. Reached from the denied-camera state or the microphone-denied alert. |

### User roles and access

| Role | Access |
|------|--------|
| App user (single role) | Every control. No auth, no multi-user concept. |

### User journeys

**1. Record audio**
1. Click the menu bar icon; the panel opens with the live preview
2. Click the mic; it dims and says "Starting… wait to speak", then turns red with an ember, dot, and running timer
3. Click it again to stop; the timer freezes faded on the final duration and the panel stays open

**2. Record video**
1. With the preview running, click the video button; the mic disables
2. After arming, the video button turns red with an ember and the timer runs; the movie is written in-app
3. Click it again to stop; the movie lands in Photo Booth's library

**3. Frame the shot**
1. Open the panel; the preview starts ("Starting camera…" until the first frame)
2. Toggle mirror, pick a camera from the menu, or pick S/M/L
3. Choices persist across launches

**4. Keep the panel open while working**
1. Click the pin; it turns blue and the glyph becomes `pin.fill`
2. Click into another app; the panel stays on screen
3. Click the menu bar icon to close it, or unpin

**5. Quit while recording**
1. Click Quit during a recording
2. Audio: the Stop shortcut fires. Video: the app waits for the movie file to finish writing
3. The app terminates

**6. First-ever panel open (permission)**
1. The preview shows a waiting state while macOS asks for camera access
2. Allow starts the preview; Deny shows an inline message with "Open Settings"
3. The mic stays usable either way; the video button stays disabled until the preview runs

**7. Camera unplugged mid-session**
1. The preview is running on an external camera and the user unplugs it
2. The app falls back to another camera without discarding the stored preference
3. If none remains, the no-camera message shows; the mic stays usable

---

## Preview states

In **every** state below, the mic, mirror, pin, S/M/L, and Quit remain usable. The video button is enabled only in **Running**.

| State | Trigger | Preview area shows | Actions offered |
|-------|---------|--------------------|-----------------|
| Starting | Session started, no frame yet | Spinner and "Starting camera…" | None |
| Not determined | Permission never requested | Waiting message while the macOS prompt is up | None (the system prompt owns it) |
| Denied | User denied camera access | "Camera access is turned off for MacRecordWidget." | "Open Settings" opens Privacy & Security, Camera |
| Restricted | Blocked by policy (MDM, parental controls) | "Camera access is restricted on this Mac and cannot be changed here." | **None by design.** The Settings pane cannot resolve an MDM restriction |
| No camera connected | Zero video devices | "No camera connected." | None; clears when a camera appears |
| Failed | Session or device error, or 10s with no frame | The reason, inline | "Try Again" |
| Running | Permission granted, frames arriving | Live image, mirrored if the mirror toggle is on | Camera menu, video recording |

**Fallback rule:** if the stored device ID matches no connected device, the app selects another. The stored ID is **not** overwritten, so reconnecting the preferred camera restores it.

**Camera-name indicator:** the camera menu's label names the device actually feeding the preview. There is no separate name label.

---

## Acceptance criteria

All criteria below describe shipped behaviour as of 2026-10-05. Invalidated criteria are in **Superseded acceptance criteria**.

### Panel layout

- **AC-L-1:** The panel content is a `VStack` with zero spacing: one `HStack` button row, with the preview always below it.
- **AC-L-2:** The row is ordered: pin, record group (mic, timer, video), mirror, spacer, camera menu, S/M/L, Quit. Every item is always mounted.
- **AC-L-2b:** The record group's internal spacing is half the row spacing. The mirror toggle sits at full row spacing, outside the group.
- **AC-L-3:** No recording-status dot appears in the panel except the amber dot on a recording button's corner.
- **AC-L-4:** Every control is a glyph, a single letter, the timer, or the camera name, with an `accessibilityLabel`. There is no text label in the row.
- **AC-L-5:** No control shows a focus ring.
- **AC-L-6:** Every control's glyph size, glyph font, corner radius, height, and `ControlSize` come from the current `PanelScale`. No view hardcodes them.
- **AC-L-7:** An off control is a rounded rect at the scale's corner radius, filled `controlBackgroundColor`, with a 1pt `separatorColor` outline. An on control is a fully round capsule filled with its hue, a white glyph, and no outline.
- **AC-L-7b:** A control's width is identical off and on. Starting a recording or toggling pin or mirror moves no other control.
- **AC-L-7c:** Every control, the timer, and the camera menu are exactly `PanelScale.controlHeight` tall (17 / 20 / 22pt).
- **AC-L-8:** Padding is applied to the button row, not the panel, so the preview reaches the panel's edges. Top and bottom padding are set separately.
- **AC-L-9:** There is no control strip below the preview.
- **AC-L-10:** The preview runs flush to the panel's left, right, and bottom edges. No inset, no border.
- **AC-L-11:** Only the preview's bottom two corners are rounded, matching the panel. Its top corners are square.

### Colour

- **AC-COL-1:** The row uses exactly two fill hues: red `#FF383C` and blue `#007AFF`. No green or other hue appears on any control.
- **AC-COL-2:** Red appears only on a recording button (mic or video) while that medium is recording.
- **AC-COL-3:** Blue is the lit colour for pin, mirror, the selected S/M/L toggle, the camera menu's chevron well, and Quit.
- **AC-COL-4:** Quit is always drawn lit (blue). It has no off state.
- **AC-COL-5:** White glyphs on both hues clear 3:1 contrast (3.57:1 on red, 4.02:1 on blue).

### Controls

- **AC-C-1:** A **single** audio toggle (`recordToggle`) starts and stops audio. There is no separate Stop button.
- **AC-C-2:** The audio toggle shows `mic.fill` in **both** states. Idle it is an off capsule; recording it is a red capsule with a white glyph. The glyph never swaps.
- **AC-C-2b:** `stop.fill` appears nowhere in the app. The idle mic is **not** red.
- **AC-C-3:** The audio toggle is disabled while an invocation is in flight, while arming, and while video holds the medium.
- **AC-C-4:** The video toggle (`videoRecordToggle`) shows `video.fill` in both states and starts and stops an in-app video recording. It is grouped with the mic and timer.
- **AC-C-5:** The video toggle is disabled while audio holds the medium, while in flight or arming, and whenever the preview is not running. Its tooltip names the reason.
- **AC-C-6:** Quit (`quitButton`) shows `power`, has the tooltip "Quit", and is never disabled.
- **AC-C-7:** The camera menu is always in the row, capped at the scale's width (110 / 200 / 260pt).
- **AC-C-8:** A pin toggle (`pinToggle`) is the leftmost control. It shows `pin.slash` off and `pin.fill` on, and is never disabled.
- **AC-C-9:** The panel sizes are three separate toggles labelled S, M, L. They are **not** a segmented `Picker`, because `NSSegmentedControl` ignores SwiftUI's `.font()`.
- **AC-C-10:** The S/M/L toggles are always mounted, immediately after the camera menu.
- **AC-C-11:** Turning on a size toggle selects that size. Turning off the selected one is ignored: exactly one size is always selected.
- **AC-C-12:** Each control's tooltip matches the Tooltips and VoiceOver table, and changes with state where the table lists several values.
- **AC-C-13:** The mirror toggle (`mirrorToggle`) uses Apple's Flip Horizontal glyph (`arrow.left.and.right.righttriangle.left.righttriangle.right`) and is never disabled, including during a video recording.
- **AC-C-14:** While recording, the recording button carries a blinking amber dot on its bottom-right corner, offset mostly onto the panel background.

### Timer

- **AC-T-1:** The timer (`recordingTimer`) shows MM:SS in a box with a 1pt `separatorColor` border at the scale's corner radius.
- **AC-T-2:** While recording it is full strength; while idle it is secondary-coloured at 65% opacity.
- **AC-T-3:** Elapsed time is derived from the recording's start date, so it stays correct while the panel is closed.
- **AC-T-4:** The timer resets when a recording starts, not when it stops. After Stop it keeps showing the final duration.
- **AC-T-5:** The value never wraps onto two lines at any scale, and its digits are monospaced so the box does not twitch.
- **AC-T-6:** Audio and video share the one timer.

### Live Ember

- **AC-E-1:** A recording button wears an animated red gradient with a breathing glow on a 3.4s period while its medium is capturing.
- **AC-E-2:** The ember is not shown during arming.
- **AC-E-3:** Under Reduce Motion the ember is replaced by the flat red fill.
- **AC-E-4:** Under Increase Contrast the ember is replaced by the flat red fill.
- **AC-E-5:** Both record buttons use the same ember hue.

### Menu bar icon

- **AC-M-1:** The icon is `record.circle`, rendered hierarchically, primary-coloured when idle and green while either medium records.
- **AC-M-2:** While recording, an amber badge dot blinks at the bottom trailing corner.
- **AC-M-3:** With Reduce Motion enabled, the badge dot is fully opaque and does not blink.
- **AC-M-4:** The badge dot is hidden from accessibility.
- **AC-M-5:** The icon glyph never changes to a mic or camera symbol.

### Panel lifecycle

- **AC-P-1:** The panel stays open after starting a recording.
- **AC-P-2:** The panel stays open after stopping a recording.
- **AC-P-3:** Unpinned, the panel closes on a menu bar icon click or when another app takes focus. Pinned, only the icon click closes it.
- **AC-P-4:** No code path calls `popover.close()` or `panel?.orderOut(nil)` after start or stop.
- **AC-P-5:** While pinned, the window is re-shown on `didResignKeyNotification`, twice: once synchronously and once on the next runloop pass.
- **AC-P-6:** `hidesOnDeactivate` is forced off on the panel window.
- **AC-P-7:** The pinned state persists under `panelPinned` and is restored on launch.

### Recording behaviour

- **AC-R-1:** If Voice Memos is running at Start, it is terminated and the app waits 1.5s before firing the Start shortcut.
- **AC-R-1b:** Stop quits Voice Memos about 2s after firing the Stop shortcut.
- **AC-R-2:** Start fires `shortcuts://run-shortcut?name=Start` with a timestamped recording name as text input.
- **AC-R-3:** Stop fires `shortcuts://run-shortcut?name=Stop`.
- **AC-R-4:** **No code path launches, scripts, or UI-automates Photo Booth.**
- **AC-R-5:** Quit stops an in-progress audio recording, or waits for an in-progress movie file to finish writing, before terminating.
- **AC-R-6:** Audio and video are mutually exclusive. Pressing one disables the other until its recording ends or fails.
- **AC-R-7:** Any failure to start releases the medium, so both buttons return to their idle state.
- **AC-R-8:** After a button is pressed, the app shows an arming state for 3s before showing "recording". During arming the pressed button is disabled, its glyph is at 35% opacity, and its tooltip reads "Starting…".

### Video recording

- **AC-V-1:** Video is written by the app's `AVCaptureMovieFileOutput` as an H.264 + AAC `.mov` into `~/Pictures/Photo Booth Library/Pictures/`.
- **AC-V-2:** File names follow Photo Booth's pattern, with U+202F before AM/PM. A same-minute collision gets a " 2", " 3" suffix; nothing is overwritten.
- **AC-V-3:** The movie is added to Photo Booth's `Recents.plist` only when Photo Booth is not running. Otherwise it is left on disk unindexed.
- **AC-V-4:** The recorded movie is never mirrored, whatever the mirror toggle says.
- **AC-V-5:** The microphone input is attached on the first video recording. Opening the panel never prompts for microphone access.
- **AC-V-6:** If microphone access is denied, an alert titled "Microphone Access Needed" points to System Settings.
- **AC-V-7:** The camera menu is disabled during a video recording.
- **AC-V-8:** Closing the panel during a video recording does not stop or truncate it.

### Swift and reliability

- **AC-SW-1:** `RecordingManager` and `CameraManager` are `@MainActor @Observable`. No `ObservableObject`, `@StateObject`, or `@ObservedObject` remain.
- **AC-SW-2:** The deployment target is macOS 14.0 in the project file and in CI.
- **AC-SW-3:** No raw `DispatchQueue` calls remain on the UI path. Capture session work runs on the session queue, never the main actor.
- **AC-SW-4:** A failed shortcut launch throws `RecordingError.shortcutLaunchFailed` and surfaces as an `NSAlert`.
- **AC-SW-5:** Tapping a record button while an invocation is in flight produces no second invocation.
- **AC-SW-6:** `isRecording` changes only after the start succeeds (the shortcut URL opens, or the movie output starts). A failure leaves it unchanged.
- **AC-SW-7:** `RecordingError` has exactly one case, `shortcutLaunchFailed`. Video errors live in a separate `VideoRecordingError`.
- **AC-SW-8:** `MacRecordWidgetApp`, `MenuBarIcon`, `CameraPreviewPanel`, and `CameraPreviewLayerView` carry explicit `@MainActor` annotations (Swift 5.9 in CI does not infer it).
- **AC-SW-9:** The preview layer is created once by `CameraManager` and never deallocated.

### Preview surface

- **AC-PV-1:** The preview sits **below** the button row.
- **AC-PV-2:** The preview is 16:9 at every scale, as wide as the panel. At medium that is 480x270pt.
- **AC-PV-3:** The preview is always mounted. There is no control that hides it.
- **AC-PV-4:** The preview stream is never written anywhere. Only the movie output writes a file, and only during a video recording.
- **AC-PV-5:** Starting or stopping a recording does not stop, pause, or restart the preview.
- **AC-PV-6:** The camera menu's label names the device being shown. There is no separate name label.
- **AC-PV-7:** The camera menu uses neutral styling: no warning colour, no caution icon, no error copy.
- **AC-PV-8:** The preview area renders correctly in light and dark mode.

### Panel sizing

- **AC-PNL-1:** The panel width is the current scale's preview width. It changes only when the scale changes.
- **AC-PNL-2:** The panel's trailing edge sits flush against the right of the screen's visible frame (zero margin).
- **AC-PNL-3:** The resize is **not** animated.
- **AC-PNL-4:** The panel is not draggable: `isMovable` and `isMovableByWindowBackground` are both false.
- **AC-PNL-5:** No panel size change causes row controls to reorder.
- **AC-PNL-6:** Size and corrected origin are applied under `disableScreenUpdatesUntilFlush()` and flushed once, so the anchored intermediate frame is never painted.
- **AC-PNL-8:** Changing the scale moves only the left edge.

### Panel scale

- **AC-SC-1:** Three sizes: small, medium, large. Medium is the default on first launch.
- **AC-SC-2:** One `PanelScale` enum owns every derived dimension: preview size, glyph size and font, control font, size-label font, `ControlSize`, control height, control horizontal padding, row spacing, horizontal and top/bottom padding, corner radius, timer padding, recording-dot size, chevron well, and camera menu width.
- **AC-SC-3:** `ControlSize` maps to `.mini` at small, `.small` at medium, `.regular` at large.
- **AC-SC-4:** Small is 380pt wide and medium is 480pt wide.
- **AC-SC-5:** Large is half the screen's visible width, rounded down, never below 480.
- **AC-SC-6:** Large measures the **panel**, so it never laps a window tiled to the left half.
- **AC-SC-7:** Preview height is preview width times 9/16, rounded.
- **AC-SC-8:** The scale persists under `panelScale` as the enum's raw string. An unrecognised value falls back to medium.
- **AC-SC-9:** Changing the scale resizes the row and the preview together.
- **AC-SC-10:** Large uses control height 22pt, glyph 17pt in a 14pt font, control and size-label fonts 13pt, top padding 7pt, bottom padding 6pt.

### Camera menu

- **AC-CAM-1:** The menu lists every connected video device by display name, with a checkmark on the active one.
- **AC-CAM-2:** Choosing a device switches the preview to it.
- **AC-CAM-3:** The chosen device's identifier persists under `preview.cameraDeviceID`.
- **AC-CAM-4:** If the stored identifier matches no device, the app falls back to another and leaves the stored identifier unchanged.
- **AC-CAM-5:** Reconnecting the stored device restores it.
- **AC-CAM-6:** It is a `Menu` of `Button`s, **not** a `Picker`. Choosing a camera never switches back on its own a moment later.
- **AC-CAM-7:** The menu is usable in every non-running state where a device exists, and disabled when no device exists.
- **AC-CAM-8:** A long device name truncates within the scale's menu width and pushes no control out of the panel.

### Mirroring

- **AC-MIR-1:** A mirror toggle controls whether the preview is mirrored. It defaults to **on**.
- **AC-MIR-2:** The choice persists under `preview.mirrored`.
- **AC-MIR-3:** Mirroring never affects the movie output. The movie connection is pinned unmirrored at configure time and again before each recording.
- **AC-MIR-4:** Flipping the toggle during a video recording changes the preview only and cannot disturb the file being written.

### Session lifecycle

- **AC-LC-1:** The capture session starts when the panel opens.
- **AC-LC-2:** Closing the panel stops the session running (camera light off) but keeps inputs, outputs, and format configured.
- **AC-LC-3:** Reopening resumes without rediscovering devices.
- **AC-LC-4:** Closing the panel during a video recording does not stop the session.
- **AC-LC-5:** If no frame arrives within 10s of starting, the state becomes Failed with "Try Again".
- **AC-LC-6:** The preview shows "Starting camera…" until the first real frame arrives, never a black layer.

### Permission and failure states

- **AC-ST-1:** On the first panel open with permission not determined, the app requests camera access and shows a neutral waiting state.
- **AC-ST-2:** Denied shows an inline message plus "Open Settings".
- **AC-ST-3:** Restricted shows an inline message and **no** settings action.
- **AC-ST-4:** No device shows an inline no-camera message.
- **AC-ST-5:** On disconnect, the app falls back to another device if one exists, else shows the no-camera message.
- **AC-ST-6:** `starting`, `denied`, `restricted`, `notDetermined`, `noCamera`, and `failed` are distinct states with distinct copy.
- **AC-ST-7:** In every state, the mic keeps its normal behaviour.
- **AC-ST-8:** In every state, mirror, pin, S/M/L, and Quit keep their normal behaviour. The video button is disabled outside Running, with the state's reason as its tooltip.
- **AC-ST-9:** No preview failure presents a modal alert.
- **AC-ST-10:** State messages are clear, non-blaming, sentence case, no exclamation marks.

### Playback

- **AC-PB-1:** Clicking the timer box plays the shown recording; clicking it while playing stops it. It is disabled while recording or arming and when no recording exists.
- **AC-PB-2:** During audio playback a scrubber with elapsed and total time sits along the bottom of the live preview, with no pause button. Dragging seeks.
- **AC-PB-3:** Video playback is mirrored when the mirror toggle is on (the default) and unmirrored when off. The toggle stays enabled during playback. The badge reads "mirrored" or "as others see it".
- **AC-PB-4:** Both scrubbers end in a trash button (`trashRecordingButton`). It stops playback, asks for confirmation, moves the file to the Trash, then shows the next older recording (or the newer one if none is older).
- **AC-PB-5:** The timer box's context menu offers Play Last Recording, Previous Recording, Next Recording and Move to Trash…. All are disabled while playing; Previous and Next are disabled at the oldest and newest recording.
- **AC-PB-6:** Previous/Next order is creation date across Photo Booth `.mov` and Voice Memos `.m4a` files.
- **AC-PB-7:** On panel open and after a failed play, a deleted shown recording is replaced by the newest remaining one, or the box disables if none remain. An audio recording not yet matched to its file is not treated as deleted within its first minute.

### Accessibility

- **AC-AX-1:** Pin, mic, timer, video, mirror, camera menu, and Quit carry an `accessibilityLabel` and a stable `accessibilityIdentifier` (`pinToggle`, `recordToggle`, `recordingTimer`, `videoRecordToggle`, `mirrorToggle`, `cameraPicker`, `quitButton`).
- **AC-AX-1b:** The S/M/L toggles carry spelled-out labels ("Small preview size", and so on). `panelScalePicker` is on their container.
- **AC-AX-2:** The mic and video labels reflect their current state, including "Starting…" during arming.
- **AC-AX-3:** The preview carries the label "Camera preview" and identifier `cameraPreview`.
- **AC-AX-4:** Every inline state message is readable by VoiceOver.
- **AC-AX-5:** The preview area introduces no focus ring.
- **AC-AX-6:** Where a tooltip is too terse for speech, the label is written out: Quit reads "Quit MacRecordWidget".
- **AC-AX-7:** Recording state is distinguishable **without hue**: the button's silhouette changes (rounded rect to full capsule), its fill changes luminance, and an amber dot appears on its corner.
- **AC-AX-8:** Recording state is also carried by the tooltip, the VoiceOver label, the running timer, and the menu bar icon (green plus a blinking dot), which is visible with the panel closed.
- **AC-AX-9:** All motion (ember, both amber dots) stops under Reduce Motion.

### Persistence

- **AC-PS-1:** Exactly **five** values persist: `preview.cameraDeviceID`, `preview.mirrored`, `panelPinned`, `panelScale`, and `lastRecording` (medium, file URL, duration, as JSON).
- **AC-PS-2:** Persistence uses `UserDefaults`. No SwiftData model container (a recorded deviation from `tech-config.md`).
- **AC-PS-3:** A first launch with no stored camera uses a connected default camera.
- **AC-PS-4:** No other state persists. Recording state resets on each launch; the idle timer shows the persisted last recording's length.
- **AC-PS-5:** The panel scale is stored as the enum's raw string.
- **AC-PS-6:** A missing mirror value reads as on (the default), not as off.

---

## Superseded acceptance criteria

Kept for the decision trail. **Do not test against any criterion below.** Each was correct when approved and was invalidated by a later decision.

| Superseded AC | What it said | Superseded by | Reason | Date |
|---|---|---|---|---|
| AC-L-1 (old) | The popover is a single `HStack` row, 200pt wide, ordered: video toggle, Start, Stop, Quit | AC-L-1, AC-L-2, AC-PNL-1 | Record and Stop merged into one toggle; the panel is a fixed 504pt wide in both states | 2026-09-04 |
| AC-C-1 (old) | The video toggle uses `.toggleStyle(.switch)` | AC-C-4 | A switch is a wide capsule beside round glyphs and never reads as part of the same control family. Replaced with a `.button`-style toggle | 2026-09-04 |
| AC-C-2 (old) | The video toggle is disabled while recording | AC-C-5 | The camera toggle no longer affects what is recorded, so disabling it had no justification | 2026-09-04 |
| AC-C-3 (old) | Start renders as a red `record.circle.fill` and is disabled while recording | AC-C-1, AC-C-2, AC-C-3 | Start and Stop were mutually exclusive with one always disabled. Merged into one toggle | 2026-09-04 |
| AC-C-4 (old) | Stop renders as `stop.fill` and is disabled when not recording | AC-C-1, AC-C-2 | Same merge | 2026-09-04 |
| AC-R-3 (old) | Stop does not close Photo Booth | AC-R-4 | Photo Booth is never launched, so there is nothing to leave open | 2026-09-04 |
| AC-R-4 (old) | Photo Booth opens on Start when video mode is on, and does not go full screen | AC-R-4 | **Photo Booth launch deleted.** The overloaded toggle (preview plus a hidden app launch) surprised the human. Decision: the toggle controls the preview only, and video capture is dropped | 2026-09-04 |
| AC-PV-5 note (old) | Preview stays live during recording, *depending on camera contention with Photo Booth* | AC-PV-5 | The dependency is gone: nothing else opens the camera | 2026-09-04 |
| AC-PV-6 (old) | A separate passive text indicator names the camera | AC-PV-6 | The picker's selected value already names the device. A second label duplicated it | 2026-09-04 |
| AC-PNL-1 / AC-PNL-2 (old) | Panel is 200pt wide when off and 504x346pt when on | AC-PNL-1 | Fixed 504pt in both states. A width change forces AppKit to reposition as well as resize, and the anchored position is painted before the correction lands | 2026-09-04 |
| AC-PNL-3 (old) | The width change animates between 200pt and 504pt | AC-PNL-3 | No width change exists, and animating `setFrame` animates the reverted origin too, sliding the panel across the screen | 2026-09-04 |
| AC-PNL-4 (old) | With Reduce Motion, the panel changes size with no animation | AC-PNL-3 | Nothing animates for anyone, so the Reduce Motion branch is moot | 2026-09-04 |
| AC-PNL-6 (old) | The button row is trailing-aligned so it stays pinned as the panel grows leftward | AC-PNL-2, AC-PNL-5 | The panel never grows leftward. `PanelSizer` imposes right-alignment on the window instead | 2026-09-04 |
| AC-MIR-1 to AC-MIR-5 (old) | A user-facing mirror control, default on, persisted, preview-only | AC-MIR-1 to AC-MIR-4 | **Mirror toggle removed.** One hardcoded orientation is right for every observed use, and the control cost a slot in a five-control row | 2026-09-04 |
| AC-ST-6 (old) | A distinct "camera busy" state when another app holds the device | AC-ST-6 | No other app in this product opens the camera, so the state is unreachable by design. Not implemented | 2026-09-04 |
| AC-AX-1 (old) | The camera picker **and mirror toggle** each carry a label and identifier | AC-AX-1 | No mirror toggle exists | 2026-09-04 |
| AC-PS-1 (old) | Exactly two values persist: camera ID and the mirror flag | AC-PS-1, AC-MIR-3 | Only the camera ID persists. Any stored mirror flag is deliberately not read | 2026-09-04 |
| AC-PR-1 to AC-PR-4 (old) | Engineering prerequisites (actor isolation, `NSCameraUsageDescription`, persistence, remove `accessibilityDenied`) | n/a | All four are done. AC-SW-1, AC-SW-7, AC-PS-2 now cover them as shipped behaviour | 2026-09-04 |
| AC-L-2 (2026-09-04) | The row is ordered: "Audio" label, audio toggle, spacer, camera toggle, camera picker, Quit | AC-L-2 | A pin toggle joined at the head of the row and three S/M/L size toggles after the picker. The "Audio" label was removed | 2026-09-05 |
| AC-L-4 (2026-09-04) | Every control is icon-only **except the "Audio" text label** | AC-L-4 | The label is gone. A row-level "Audio" caption implied a "Video" counterpart that this product does not have | 2026-09-05 |
| AC-L-6 (2026-09-04) | Every control renders at `.controlSize(.small)` with a 13pt glyph in a 16pt frame | AC-L-6, AC-SC-2, AC-SC-3 | Those numbers are now the *medium* scale only. Every dimension derives from `PanelScale` | 2026-09-05 |
| AC-L-8 (2026-09-04) | The "Audio" label renders at 11pt secondary and is hidden from accessibility | n/a | The label was deleted | 2026-09-05 |
| AC-C-2 (2026-09-04) | The audio toggle shows `record.circle.fill` when idle and `stop.fill` while recording | AC-C-2 | A red disc is the generic record mark and reads as video as readily as audio. `mic.fill` names the medium and pairs with `video.fill` beside it. It also survives the 11pt small scale, which thinner audio symbols do not | 2026-09-05 |
| AC-C-2 (interim, 2026-09-05) | The audio toggle shows a **red** `mic.fill` when idle and `stop.fill` while recording | AC-C-2, AC-C-2b, AC-AX-7 | Swapping the glyph made this the only control in the row that changed shape rather than fill. One glyph, fill flips. The idle glyph also lost its red, so red now means exactly one thing: recording | 2026-09-05 |
| Any AC arguing recording state "survives greyscale because the glyph swaps" | Colour-independence justified by the `record.circle.fill` to `stop.fill` shape change | AC-AX-7, AC-AX-8 | **False as of 2026-09-05.** The shapes are identical now. The argument was rewritten around fill luminance, tooltip, VoiceOver label, and the menu bar icon | 2026-09-05 |
| AC-C-7 (2026-09-04) | The camera picker is at most 200pt wide | AC-C-7 | 200pt is the medium width. The cap now follows the scale (150 / 200 / 260) | 2026-09-05 |
| AC-P-3 (2026-09-04) | The popover closes **only** when the user clicks the menu bar icon | AC-P-3, AC-C-8 | Incorrect as written: the panel always also closed on focus loss. The pin toggle makes that behaviour opt-out and the AC now states both paths | 2026-09-05 |
| AC-PV-2 (2026-09-04) | The preview image is 480x270pt | AC-PV-2, AC-SC-4 to AC-SC-7 | 480x270 is the medium scale. The preview is 16:9 at three widths | 2026-09-05 |
| AC-PNL-1 (2026-09-04) | The panel is a fixed 504pt wide in both states | AC-PNL-1, AC-PNL-8, AC-SC-4 to AC-SC-6 | Width now follows the scale. The rule that survived is narrower: the width does not change when the *camera* toggles, only when the *scale* does | 2026-09-05 |
| AC-PNL-2 (2026-09-04) | The panel's trailing edge sits 8pt from the right of the visible frame | AC-PNL-2 | Margin dropped to zero. With an edge-to-edge preview, an 8pt gap read as a misalignment rather than a margin | 2026-09-05 |
| AC-CAM-8 (2026-09-04) | A long name does not push a control out of the **504pt** panel; the picker caps at 200pt | AC-CAM-8 | Both numbers were scale-specific | 2026-09-05 |
| AC-AX-1 (2026-09-04) | Audio toggle, camera toggle, picker, and Quit carry a label and identifier | AC-AX-1, AC-AX-1b | The pin toggle joined the row; the size toggles carry labels but share a container identifier | 2026-09-05 |
| AC-AX-6 (2026-09-04) | The decorative "Audio" label is hidden from accessibility | AC-AX-6 | No such label exists. The slot now holds the rule that actually matters: VoiceOver labels are written out where the tooltip is too terse | 2026-09-05 |
| AC-PS-1 (2026-09-04) | Exactly **one** value persists: the camera ID | AC-PS-1 | Two more preferences joined: `panelPinned` and `panelScale` | 2026-09-05 |
| Deferred: "a variable-width panel" (2026-09-04) | A variable width was ruled out because AppKit repositions as well as resizes | AC-PNL-8, AC-SC-1 | Superseded by measurement: the repositioning is survivable when the panel is right-anchored and painting is suppressed until the corrected frame lands. Only the left edge moves | 2026-09-05 |
| AC-L-1 (2026-09-05) | The preview sits below the row **when the camera toggle is on** | AC-L-1, AC-PV-3 | The preview toggle was removed; the preview is permanent | 2026-09-09 |
| AC-L-2 (2026-09-05) | Order: pin, audio, spacer, camera toggle, picker, S/M/L, Quit; picker and S/M/L only while the camera is on | AC-L-2, AC-L-2b | `video.fill` became a record button grouped with the mic and a new timer; mirror joined; everything is always mounted | 2026-09-20 |
| AC-L-7 (2026-09-05) | Every control carries a constant 1pt outline, on or off | AC-L-7, AC-L-7b, AC-L-7c | Semantic capsules: the outline is the off state only; on is a filled full capsule | 2026-09-24 |
| AC-C-2 (2026-09-05) | `.toggleStyle(.button)`, tinted red; plain chrome idle, red fill recording | AC-C-2, AC-L-7 | Replaced by the capsule toggle style | 2026-09-24 |
| AC-C-3 (2026-09-05) | The audio toggle is disabled only while in flight | AC-C-3, AC-R-6, AC-R-8 | Arming and mutual exclusion with video added two more disabled conditions | 2026-09-09 |
| AC-C-4 (2026-09-05) | The camera toggle (`videoModeToggle`) shows or hides the preview | AC-C-4, AC-V-1 | `video.fill` now records video in-app; the preview has no toggle | 2026-09-09 |
| AC-C-5 (2026-09-05) | The camera toggle is never disabled by recording state | AC-C-5 | The video button is a record control and follows the medium | 2026-09-09 |
| AC-C-6 (2026-09-05) | Quit uses `.buttonStyle(.bordered)` | AC-C-6, AC-COL-4 | Quit is a permanent blue capsule | 2026-09-24 |
| AC-C-7 (2026-09-05) | The picker is present only while the camera is on; capped at 150 / 200 / 260pt | AC-C-7 | Always mounted; small cap is 110pt after the row gained the timer, video, and mirror | 2026-09-20 |
| AC-C-9 (2026-09-05) | S/M/L are `.toggleStyle(.button)` controls | AC-C-9 | Same rule (no segmented Picker), now drawn with the capsule style | 2026-09-24 |
| AC-C-10 (2026-09-05) | S/M/L are mounted only while the camera is on | AC-C-10 | The preview is permanent, so they are too. Fixes the stranded oversized row at large | 2026-09-09 |
| AC-C-12 (2026-09-05) | Camera tooltip toggles "Show / Hide camera preview"; S/M/L read "Small panel" | AC-C-12 | No camera toggle exists; S/M/L now say "preview" | 2026-09-20 |
| AC-R-4 (2026-09-04) | Recording is audio only; no code path launches a capture app | AC-R-4, AC-V-1 | Video is captured in-app. The "never launch Photo Booth" half survives as AC-R-4 | 2026-09-09 |
| AC-R-6 (2026-09-04) | The camera toggle's state has no effect on what is recorded | AC-R-6, AC-MIR-3 | No camera toggle exists. The surviving idea (preview settings never change the file) is AC-MIR-3 | 2026-09-09 |
| AC-PV-3 (2026-09-05) | The preview is visible only while the camera toggle is on | AC-PV-3 | The preview is permanent | 2026-09-09 |
| AC-PV-4 (2026-09-04) | The preview is display-only; nothing writes a file | AC-PV-4, AC-V-1 | The movie output writes files during a video recording | 2026-09-09 |
| AC-PV-6 (2026-09-04) | The picker's selected value names the device | AC-PV-6, AC-CAM-6 | The Picker became a Menu of Buttons; its label names the active device | 2026-09-20 |
| AC-PNL-1 (2026-09-05) | Width is the same whether the camera is on or off | AC-PNL-1 | No camera toggle exists | 2026-09-09 |
| AC-PNL-7 (2026-09-04) | Closing the preview shrinks the panel back | n/a | The preview cannot be closed | 2026-09-09 |
| AC-SC-2 (2026-09-05) | `PanelScale` owns preview, glyph, fonts, `ControlSize`, spacing, padding, radius, picker width | AC-SC-2 | Gained control height, control padding, split vertical padding, timer padding, dot size, chevron well | 2026-09-24 |
| AC-SC-4 (2026-09-05) | Small is 320pt wide | AC-SC-4 | At 320 the camera picker was left about 6pt wide after the mirror toggle joined. Widened to 380 | 2026-09-20 |
| AC-CAM-1 to AC-CAM-8 (2026-09-05) | A camera **picker** (`Picker`) | AC-CAM-1 to AC-CAM-8 | The `Picker` read its binding back before the async switch landed and switched the camera back about 2s later. Rebuilt as a Menu of Buttons | 2026-09-20 |
| AC-MIR-1 to AC-MIR-4 (2026-09-04) | Mirroring hardcoded on; no mirror control; stored preference not read | AC-MIR-1 to AC-MIR-4 | A mirrored recording has backwards text, so the movie was pinned unmirrored and mirroring became a preview-only toggle, default on | 2026-09-20 |
| AC-LC-1 to AC-LC-5 (2026-09-04) | The session starts with the camera toggle, stops with the panel, none runs while the toggle is off | AC-LC-1 to AC-LC-6 | No toggle; the session starts with the panel, stays configured, and survives close during video | 2026-09-09 |
| AC-ST-1 (2026-09-04) | Permission is requested on the first camera **toggle-on** | AC-ST-1 | No toggle; requested on first panel open | 2026-09-09 |
| AC-ST-8 (2026-09-04) | The camera toggle keeps its behaviour in every state | AC-ST-8 | No camera toggle; the video button is deliberately disabled outside Running | 2026-09-09 |
| AC-AX-1 (2026-09-05) | Identifiers include `videoModeToggle`; no timer, video, or mirror identifiers | AC-AX-1 | `videoRecordToggle`, `mirrorToggle`, `recordingTimer` added | 2026-09-20 |
| AC-AX-7 (2026-09-05) | Recording state differs by button fill alone | AC-AX-7 | The capsule adds a silhouette change, and the amber corner dot adds a non-hue channel | 2026-09-24 |
| AC-PS-1 (2026-09-05) | Exactly three values persist | AC-PS-1 | `preview.mirrored` joined | 2026-09-20 |
| AC-PS-4 (2026-09-05) | The camera toggle resets on each launch | AC-PS-4 | No camera toggle exists | 2026-09-09 |
| "Product gap: no video capture" section | The app cannot record video; Photo Booth never launched | Two mediums, one timer | Video is captured in-app into Photo Booth's library | 2026-09-09 |
| Any mention of camera green `#3AD862` on mirror, S/M/L, or the chevron | A third hue for camera controls | AC-COL-1 to AC-COL-3 | It read as an unexplained third state and carried the row's one contrast failure | 2026-09-28 |

---

## Risks and mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| The two Shortcuts are missing or renamed | Medium | High | `NSWorkspace.open` returns true whenever Shortcuts claims the scheme, so a missing Shortcut cannot be detected. The alert names the required Shortcuts on any launch failure |
| The 3s arming delay is wrong on another Mac | Medium | Medium | It is a measured constant (no "now capturing" signal exists). Lengthen if first words are lost |
| Voice Memos takes longer than 1.5s to exit at Start | Low | Medium | It is normally quit at Stop already; the Start check is a fallback |
| Writing Photo Booth's `Recents.plist` badly trashes the user's library | Low | **High** | Never written while Photo Booth runs; a measured external edit once moved every listed file to the Trash |
| Video recordings show a blank 00:00 filmstrip thumbnail | Unknown | Medium | Unverified for native writes. Check xattrs and Spotlight metadata first if seen |
| Quitting mid-video leaves an unplayable `.mov` | Low | High | Quit awaits `didFinishRecordingTo` before terminating |
| Microphone usage description missing | Low | High | macOS kills the app when the audio input is added. The key is set in both build configurations |
| Icon-only controls are unlearnable for a new user | **High** | Medium | Every control has a tooltip and VoiceOver label. Accepted for a solo-use app |
| Red ember gradient's bright point is under 3:1 (`#FF7A3D`, 2.59:1) | Certain | Low | Lasts a fraction of each 3.4s sweep; flat fill under Increase Contrast |
| Small and medium scales do not step evenly with large | Certain | Low | Deliberate until measured on hardware |
| A new button starves the camera menu at small | Medium | Medium | The menu is the only flexible item; check the arithmetic before adding a row control |
| Camera activity light cycling with the panel confuses the user | Medium | Low | Accepted; it is the privacy behaviour that matters |
| A preview failure blocks a recording the user needed | Low | High | The mic works in every state (AC-ST-7); no modal alerts (AC-ST-9) |
| An ad-hoc CI build re-prompts for camera permission on every rebuild | High | Low | `scripts/install-latest.sh` re-signs with a stable self-signed certificate |
| Removing `@MainActor` annotations builds locally but fails in CI | Medium | Medium | AC-SW-8 makes them testable |
| The capture-session deadlock returns | Low | High | AC-SW-9 and AC-SW-3 encode the three rules from the 2026-09-10 fix |

---

## Known limitations

- **Known defect: the mic lights up during a video recording.** The mic toggle reads `isRecording`, which is true for either medium, so during video it shows the red fill, ember, amber dot, and "Stop and save to Voice Memos" tooltip (while disabled). It also dims during video arming. Violates AC-C-2 and AC-COL-2. Filed to `BACKLOG.md` triage.
- **No simultaneous audio and video.** By design.
- **Video depends on the preview.** If the camera is not running, video cannot start.
- **Filmstrip indexing is skipped while Photo Booth is open.** The movie is on disk but not in the filmstrip.
- **The camera activity light cycles with the panel** outside video recording.
- **The panel cannot be moved.** It is fixed flush against the right of the screen.
- **The record buttons' glyphs never change.** Shape, fill, dot, timer, tooltip, and menu bar icon carry the state.
- **The user's accent colour is ignored** in the row.

---

## Assumptions: resolved

Every assumption recorded as open before implementation is now settled.

| # | Assumption | Outcome |
|---|------------|---------|
| U-1 | The `MenuBarExtra` panel keeps its trailing edge pinned and grows leftward | **Wrong.** `MenuBarExtraWindow` anchors to the status item and reverts origin changes made inside `setFrame` (asking for x=1072 landed at x=848). Right-alignment is imposed by `PanelSizer` via a `setFrameOrigin` immediately after `setFrame` |
| U-2 | The width change can be animated | **No.** Animating the frame animates the reverted origin too, sliding the panel across the screen (AC-PNL-3). Width changes with the scale are applied unanimated under suppressed screen updates |
| U-3 | This app and Photo Booth can hold the same camera at once | **Moot.** Photo Booth is still never launched. Video is captured by this app's own session, so the preview and the recording cannot disagree about which camera is in use |

**New constraints discovered during implementation:**

- AppKit grows the panel to fit content but never shrinks it back, stranding a full-size panel when content shrinks (for example a smaller scale). Fixed by driving the window frame explicitly in `PanelSizer` (AC-PNL-6).
- Xcode 15.2 (Swift 5.9, used by CI) does not infer `@MainActor` on `App` or on view bodies, so explicit annotations are required (AC-SW-8).

---

## Platform notes

**Framework note:** `AVFoundation` (`AVCaptureSession`, `AVCaptureVideoPreviewLayer`, `AVCaptureMovieFileOutput`, `AVCaptureDevice.DiscoverySession`) is a first-party platform framework, not a third-party dependency. No library or SPM package is introduced.

**AppKit interop:** there is no SwiftUI-native camera preview on macOS 14, so `CameraPreviewView` wraps `AVCaptureVideoPreviewLayer` in an `NSViewRepresentable`. Mandatory, not stylistic.

**Distribution and camera permission:** CI builds are ad-hoc signed. For an ad-hoc app macOS pins the camera TCC grant to the **binary hash**, so every new build is a new app to TCC and the permission prompt reappears on each install. `scripts/install-latest.sh` therefore downloads the CI artifact and re-signs it locally with a stable self-signed certificate (created once by `scripts/create-signing-cert.sh`) before installing to `/Applications`. With a stable identity the grant survives rebuilds. A repeated prompt after that means the certificate changed, not that permissions are broken.

**Path exception (recorded):** Swift sources stay in `MacRecordWidget/`, not under `src/` as `tech-config.md` lists. Confirmed by the human on 2026-09-04 as a deliberate exception, not drift.

**Permission prerequisite (done):** `MacRecordWidget/Info.plist` contains `NSCameraUsageDescription`. Without it the first `AVCaptureDevice.requestAccess(for: .video)` call crashes rather than producing a denial.

**Microphone prerequisite (done):** `INFOPLIST_KEY_NSMicrophoneUsageDescription` is set in **both** build configurations. Without it macOS terminates the app the moment the session adds an audio input.
