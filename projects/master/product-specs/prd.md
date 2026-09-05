> Status: Approved — Human
> Approved: 2026-09-04

# PRD: MacRecordWidget (Master)

Consolidated product baseline. Describes the app **as it actually ships today**.

**Shipped:** production polish (2026-05-18), popover button layout (2026-05-21), live camera preview (2026-09-04).

> **Reading this document:** every unmarked statement describes current, shipped behaviour. The live camera preview shipped on 2026-09-04 and then went through several rounds of UI revision with the human on the same day. Criteria that the revisions invalidated are kept in **Superseded acceptance criteria** with the reason and date, so the decision trail survives.

## Goals

**Product goal:** one-click audio recording from the macOS menu bar, with no window, no dock icon, and no context switch. An optional in-popover camera preview lets the user check framing before recording.

| Goal | Success metric |
|------|---------------|
| Zero-friction recording | Start or stop a recording in one click from the menu bar. |
| Chained sessions | Stop a recording and start a new one without reopening the widget. |
| One control per idea | Each control does exactly one thing. No control silently triggers a second effect. |
| Native macOS feel | Controls use standard macOS control types and sizing. Correct in light and dark mode. |
| Reliable lifecycle | Rapid or double taps never fire a duplicate shortcut. Failed launches never leave the UI in a false state. |
| Idiomatic Swift | No deprecated observation APIs. No raw `DispatchQueue` on the UI path. No optimistic state divergence. |

**Non-goals:**
- No backend, web frontend, or infrastructure
- No recording modes beyond the two Shortcuts ("Start", "Stop")
- No video capture of any kind (see **Product gap: no video capture** below)
- No App Store submission prep (icons, metadata, entitlements)
- No XCUITest automation (manual smoke testing only)

---

## Product gap: no video capture

**The product cannot record video at all.** This is a real gap, stated here so no reader has to infer it.

- Recording is **audio only**, via the "Start" Shortcut into Voice Memos.
- Photo Booth is **never launched**. That code was deleted on 2026-09-04.
- The camera toggle and the preview are **display-only**. Nothing in the app writes a video file, a frame buffer, or a pasteboard image.

**Why:** the video toggle used to do two things at once (open the preview *and* launch Photo Booth). That surprised the human, who could not tell which effect a click would produce. The decision was to keep the toggle honest (preview only) and drop the Photo Booth launch entirely rather than split it into a second control.

**Consequence:** a user who wants video must open a capture app themselves. Restoring video capture is an unscoped future feature, not a defect against current specs.

---

## Elevator pitch

MacRecordWidget is a menu bar app that starts and stops an audio recording in one click. It fires two user-created Shortcuts ("Start" and "Stop") and quits Voice Memos first so macOS does not throw an audio-service error. A second toggle opens a live 480x270pt camera preview inside the popover, purely so the user can check framing. The whole UI is one row of small icon controls plus an optional preview below it.

---

## Problem

Starting a recording normally means finding an app, waiting for it to launch, and clicking through its UI. Voice Memos also blocks the Shortcuts audio path if it is already open, which produces a cryptic `VMAudioServiceErrorDomain` error 5.

Prior versions of the widget added their own friction:
- A recording-status dot in the popover flickered and carried no actionable information
- Start and Stop were stacked vertically, making the popover taller than its content needed
- The popover dismissed itself after Start, so stopping required reopening it from the menu bar
- Start and Stop were two separate buttons, one of which was always disabled
- The video toggle overloaded two effects (preview plus a Photo Booth launch) onto one click

---

## Target audience

**Primary:** the developer and sole author, who uses the app daily and maintains it.
**Secondary:** anyone who installs the build and has the two Shortcuts configured. They get a native-looking, non-blocking audio recorder.

---

## Features (shipped)

**Menu bar**
- Menu bar icon (`record.circle`) that turns green while recording, with a blinking amber badge dot that respects Reduce Motion
- The icon never changes glyph (no mic or camera swap)

**Popover row (left to right)**
- A small secondary "Audio" text label at 11pt, hidden from accessibility
- **One** audio toggle (`recordToggle`): `.toggleStyle(.button)`, `.controlSize(.small)`, tinted red. `record.circle.fill` when idle, `stop.fill` while recording. Click starts, click again stops
- A spacer
- Camera toggle (`videoModeToggle`): `.toggleStyle(.button)`, glyph `video.fill`. Shows and hides the preview. Never disabled by recording state
- Camera picker (`cameraPicker`), max 200pt wide, visible **only** while the camera toggle is on
- Quit button (`quitButton`): `.buttonStyle(.bordered)`, glyph `power`. Stops an in-progress recording, then terminates

**Control chrome**
- Every control is `.controlSize(.small)` with a 13pt glyph in a 16pt frame
- Every control carries a constant 1pt separator-coloured outline, so an off toggle and an on toggle read as one control in two states rather than two different objects
- No focus ring on any control (`focusEffectDisabled`)

**Recording**
- Voice Memos is quit before the Start shortcut fires, with a 1.5s wait
- Start fires `shortcuts://run-shortcut?name=Start` with a timestamped recording name as text input
- Stop fires `shortcuts://run-shortcut?name=Stop`
- In-flight guard prevents a duplicate shortcut invocation
- A failed shortcut launch throws `shortcutLaunchFailed` and surfaces through an `NSAlert`

**Camera preview**
- Live 480x270pt (16:9) preview below the button row, visible only while the camera toggle is on
- Display-only: never writes a file, buffer, or pasteboard image
- Mirroring is hardcoded on (selfie orientation); no user-facing mirror control
- Camera picker across all connected video devices, persisted across launches
- Distinct inline states for permission not determined, denied, restricted, no camera, and generic failure
- The audio toggle stays usable in every preview state

**Panel**
- Fixed 504pt wide in both states; only the height changes
- Right-aligned 8pt from the screen's visible frame
- Not draggable, and the resize is not animated

**Popover lifecycle**
- Popover stays open through Start and Stop; it closes only when the user clicks the menu bar icon
- The capture session starts when the camera toggle turns on and stops when the popover closes

---

## Conceptual data model

- The app holds one **Recording session** state, in memory only, never persisted.
- A Recording session has three flags: recording or idle, camera preview shown or hidden, and in flight or settled.
- A Recording session drives two **Shortcuts** by name: "Start" and "Stop". Both must exist in the user's Shortcuts app.
- A Recording session owns **no** capture process. Nothing captures video.
- One **Preview session** exists in memory, separate from the Recording session, never writing a file.
- A Preview session shows exactly one **Camera device**, chosen from the connected video devices. A Camera device has a stable unique identifier, a display name, and a connected status.
- One **Preference** outlives a launch: the selected camera's unique identifier. Mirroring is a constant, not a preference.
- A Preview session has a **status**: idle, running, or a message state (permission not determined, denied, restricted, no camera, generic failure).

---

## Roadmap

### Shipped

| Phase | Date | Contents |
|-------|------|----------|
| Production polish | 2026-05-18 | HIG pass on controls, `@Observable` migration, macOS 14 target, structured concurrency, typed errors, in-flight guard, non-optimistic state |
| Popover button layout | 2026-05-21 | Popover status dot removed, single horizontal row, popover stays open through Start and Stop |
| Live camera preview | 2026-09-04 | Preview surface, fixed 504pt panel driven by `PanelSizer`, camera picker in the button row, hardcoded mirroring, permission and failure states, camera-ID persistence |
| Post-ship UI revisions | 2026-09-04 | Record and Stop merged into one toggle, Photo Booth launch deleted, mirror toggle removed, control strip removed, uniform control chrome, dead `accessibilityDenied` case removed |

### Deferred

| Item | Why deferred |
|------|-------------|
| Video capture of any kind | Removed with the Photo Booth launch on 2026-09-04. Restoring it needs its own explicit control and its own spec |
| Persisting the camera-toggle state | Low value for a solo user; resets are cheap |
| A user-facing mirror control | Removed after ship. One hardcoded orientation is correct for every observed use, and the toggle cost a control slot |
| XCUITest automation | Manual smoke testing covers a five-control UI |
| App Store submission (icons, metadata, entitlements) | Distribution is via GitHub Actions artifact |
| Additional recording modes or Shortcuts | No demand yet; would expand the single-row UI |
| Preview snapshot or still capture | Would be the app's first capture path; out of scope for a framing aid |
| Detached or full-screen preview window | Contradicts the no-window, menu-bar-only product shape |
| Keeping the capture session alive while the popover is closed | Human accepted the camera activity light cycling instead |
| Multi-camera simultaneous preview | No demand; would not fit a 504pt panel |
| A variable-width panel | AppKit repositions as well as resizes on a width change, and paints the anchored position before the correction lands |

---

## App flows

### Site map

| Surface | Purpose |
|---------|---------|
| Menu bar icon | Always-visible status. Green while recording. Click toggles the popover. |
| Popover, button row | "Audio" label, audio toggle, camera toggle, camera picker (when on), Quit. |
| Popover, preview area | Visible only while the camera toggle is on. Holds the live image or an inline state message. |
| System Settings → Privacy & Security → Camera | External. Reached from the denied-permission state's "Open Settings" action. |

### User roles and access

| Role | Access |
|------|--------|
| App user (single role) | Every control. No auth, no multi-user concept. |

### User journeys

**1. Record audio**
1. Click the menu bar icon; the popover opens
2. Click the red audio toggle; Voice Memos quits and the Start shortcut fires
3. Click the same toggle again to stop; the popover stays open throughout

**2. Check framing (no recording involved)**
1. Click the camera toggle; the panel grows downward and the preview starts
2. Pick a different camera from the picker if needed
3. Click the camera toggle again; the preview collapses and the session stops

**3. Quit while recording**
1. Click the Quit (power) button during a recording
2. The Stop shortcut fires first
3. The app terminates

**4. First-ever camera toggle-on (permission)**
1. Click the camera toggle; the preview area shows a waiting state while macOS presents the prompt
2. Allow starts the preview; Deny shows an inline message with an "Open Settings" action
3. The audio toggle stays usable either way

**5. Camera unplugged mid-session**
1. The preview is running on an external camera and the user unplugs it
2. The app falls back to another connected camera without discarding the stored preference
3. If no camera remains, the no-camera message shows; the audio toggle stays usable throughout

---

## Preview states

In **every** state below, the audio toggle, the camera toggle, and Quit remain fully usable.

| State | Trigger | Preview area shows | Actions offered |
|-------|---------|--------------------|-----------------|
| Not determined | First toggle-on, permission never requested | "Waiting for camera access…" while the macOS prompt is up | None (system prompt owns the interaction) |
| Denied | User denied camera access, or previously denied | "Camera access is turned off for MacRecordWidget." | "Open Settings" opens Privacy & Security → Camera |
| Restricted | Access blocked by policy (MDM, parental controls) | "Camera access is restricted on this Mac and cannot be changed here." | **None by design.** The Settings pane cannot resolve an MDM restriction, so offering it would be a dead end |
| No camera connected | Zero video devices discovered | "No camera connected." | None; clears when a camera appears |
| Failed | Session or device error | The underlying reason, inline | Picker remains available |
| Running | Permission granted, device available | Live image, mirrored, with the picker naming the device | Camera picker |

**Fallback rule:** if the stored device ID matches no connected device, the app selects another connected device. The stored ID is **not** overwritten, so reconnecting the preferred camera restores it.

**Camera-name indicator:** the picker's selected value doubles as the name indicator. There is no separate name label.

---

## Acceptance criteria

All criteria below describe shipped behaviour. Criteria invalidated by the 2026-09-04 revisions are in **Superseded acceptance criteria**.

### Popover layout

- **AC-L-1:** The popover content is a `VStack`: a single `HStack` button row, with the preview below it when the camera toggle is on.
- **AC-L-2:** The button row is ordered: "Audio" label, audio toggle, spacer, camera toggle, camera picker (only when the camera toggle is on), Quit.
- **AC-L-3:** No recording-status dot appears anywhere in the popover, in any state.
- **AC-L-4:** Every control is icon-only (except the "Audio" text label) with an `accessibilityLabel` and a stable `accessibilityIdentifier`.
- **AC-L-5:** No control shows a focus ring.
- **AC-L-6:** Every control renders at `.controlSize(.small)` with a 13pt glyph inside a 16pt frame.
- **AC-L-7:** Every control carries a constant 1pt separator-coloured outline, present whether the control is on or off.
- **AC-L-8:** The "Audio" label renders at 11pt in the secondary foreground style and is hidden from accessibility.
- **AC-L-9:** There is no control strip below the preview. The camera picker lives in the button row.

### Controls

- **AC-C-1:** A **single** audio toggle (`recordToggle`) starts and stops recording. There is no separate Stop button.
- **AC-C-2:** The audio toggle uses `.toggleStyle(.button)`, is tinted red, and shows `record.circle.fill` when idle and `stop.fill` while recording.
- **AC-C-3:** The audio toggle is disabled only while an invocation is in flight.
- **AC-C-4:** The camera toggle (`videoModeToggle`) uses `.toggleStyle(.button)` with the `video.fill` glyph and shows or hides the preview.
- **AC-C-5:** The camera toggle is **never** disabled by recording state. It has no bearing on what is recorded.
- **AC-C-6:** Quit (`quitButton`) uses `.buttonStyle(.bordered)` with the `power` glyph, carries a tooltip, and is never disabled.
- **AC-C-7:** The camera picker is present in the button row only while the camera toggle is on, and is at most 200pt wide.

### Menu bar icon

- **AC-M-1:** The icon is `record.circle`, rendered hierarchically, primary-coloured when idle and green while recording.
- **AC-M-2:** While recording, an amber badge dot blinks at the bottom trailing corner.
- **AC-M-3:** With Reduce Motion enabled, the badge dot is fully opaque and does not blink.
- **AC-M-4:** The badge dot is hidden from accessibility.
- **AC-M-5:** The icon glyph never changes to a mic or camera symbol.

### Popover lifecycle

- **AC-P-1:** The popover stays open after starting a recording.
- **AC-P-2:** The popover stays open after stopping a recording.
- **AC-P-3:** The popover closes only when the user clicks the menu bar icon.
- **AC-P-4:** No code path calls `popover.close()` or `panel?.orderOut(nil)` after start or stop.

### Recording behaviour

- **AC-R-1:** If Voice Memos is running, it is terminated and the app waits 1.5s before firing the Start shortcut.
- **AC-R-2:** Start fires `shortcuts://run-shortcut?name=Start` with a timestamped recording name as text input.
- **AC-R-3:** Stop fires `shortcuts://run-shortcut?name=Stop`.
- **AC-R-4:** Recording is audio only. **No code path launches Photo Booth or any other capture app**, in any state of the camera toggle.
- **AC-R-5:** Quit stops an in-progress recording before terminating.
- **AC-R-6:** The camera toggle's state has no effect on what is recorded.

### Swift and reliability

- **AC-SW-1:** `RecordingManager` is `@MainActor @Observable` and held with `@State`. No `ObservableObject`, `@StateObject`, or `@ObservedObject` remain.
- **AC-SW-2:** The deployment target is macOS 14.0 in the project file and in CI.
- **AC-SW-3:** No raw `DispatchQueue` calls remain on the UI path. Background work uses `async`/`await` inside `Task { }`.
- **AC-SW-4:** A failed shortcut launch throws `RecordingError.shortcutLaunchFailed` and surfaces as an `NSAlert`.
- **AC-SW-5:** Tapping the audio toggle while an invocation is in flight produces no second shortcut invocation.
- **AC-SW-6:** `isRecording` changes only after the shortcut URL opens successfully. A failed open leaves it unchanged.
- **AC-SW-7:** `RecordingError` has exactly one case, `shortcutLaunchFailed`. There is no `accessibilityDenied` case and no alert branch for it.
- **AC-SW-8:** `MacRecordWidgetApp`, `MenuBarIcon`, `CameraPreviewPanel`, and `CameraPreviewLayerView` carry explicit `@MainActor` annotations, because Xcode 15.2 (Swift 5.9, used by CI) does not infer it.

### Preview surface

- **AC-PV-1:** The preview area sits **below** the button row, never above it and never beside it.
- **AC-PV-2:** The preview image is 480x270pt at a 16:9 aspect ratio.
- **AC-PV-3:** The preview area is visible only while the camera toggle is on, and is fully removed from the layout when it is off.
- **AC-PV-4:** The preview is display-only: no code path writes the preview stream to a file, a buffer on disk, or the pasteboard.
- **AC-PV-5:** The preview keeps rendering while `isRecording` is true. Starting or stopping a recording does not stop, pause, or restart the session.
- **AC-PV-6:** The camera picker's selected value names the device being shown. There is no separate name label.
- **AC-PV-7:** The picker uses neutral styling only: no warning colour, no caution icon, no error copy.
- **AC-PV-8:** The preview area renders correctly in both light and dark mode.

### Panel sizing

- **AC-PNL-1:** The panel is a fixed 504pt wide in **both** states. Toggling the preview changes the height only.
- **AC-PNL-2:** The panel's trailing edge sits 8pt from the right of the screen's visible frame, imposed by `PanelSizer`.
- **AC-PNL-3:** The resize is **not** animated. No `animator().setFrame` or `NSAnimationContext` drives the panel frame.
- **AC-PNL-4:** The panel is not draggable: `isMovable` and `isMovableByWindowBackground` are both false.
- **AC-PNL-5:** No panel size change causes the button row controls to reflow, reorder, or change size.
- **AC-PNL-6:** The anchored intermediate position is never painted. Size and corrected origin are applied under `disableScreenUpdatesUntilFlush()` and flushed once.
- **AC-PNL-7:** Closing the preview shrinks the panel back. No empty full-height panel is left stranded.

### Camera picker

- **AC-CAM-1:** The picker lists every connected video device discovered on the system, by display name.
- **AC-CAM-2:** Selecting a device switches the preview to it.
- **AC-CAM-3:** The selected device's unique identifier is persisted in `UserDefaults` and restored on the next launch.
- **AC-CAM-4:** If the stored identifier matches no connected device, the app falls back to another connected device and the stored identifier is left unchanged.
- **AC-CAM-5:** Reconnecting the stored device after a fallback restores it as the previewed camera.
- **AC-CAM-6:** The picker changes the preview only. No code path attempts to drive any other app's camera.
- **AC-CAM-7:** The picker remains usable in every non-running preview state where a device exists.
- **AC-CAM-8:** A long device name does not push any control out of the 504pt panel; the picker is capped at 200pt and truncates.

### Mirroring

- **AC-MIR-1:** Mirroring is hardcoded on. `isMirrored` is a constant, not a stored or user-settable value.
- **AC-MIR-2:** No mirror control appears anywhere in the UI.
- **AC-MIR-3:** Any previously stored mirror preference is **deliberately not read**, so an earlier saved `false` cannot strand the preview unmirrored.
- **AC-MIR-4:** Mirroring is applied by setting `isVideoMirrored` on the preview connection with `automaticallyAdjustsVideoMirroring` off.

### Session lifecycle

- **AC-LC-1:** The capture session starts when the camera toggle is turned on while the popover is open.
- **AC-LC-2:** The capture session stops when the popover closes.
- **AC-LC-3:** The capture session resumes when the popover reopens with the camera toggle still on.
- **AC-LC-4:** No capture session is running while the camera toggle is off.
- **AC-LC-5:** Rapidly toggling the camera on and off leaves at most one capture session running and no orphaned session.

### Permission and failure states

- **AC-ST-1:** On the first toggle-on with permission not determined, the app requests camera access and the preview area shows a neutral waiting state.
- **AC-ST-2:** When access is denied, the preview area shows an inline message plus an "Open Settings" action that opens the macOS camera privacy pane.
- **AC-ST-3:** When access is restricted by system policy, the preview area shows an inline message and **offers no settings action**, because that pane cannot resolve an MDM or parental-controls restriction.
- **AC-ST-4:** When no video device is connected, the preview area shows an inline no-camera message.
- **AC-ST-5:** When the previewed camera disconnects mid-session, the app falls back to another connected device if one exists, and shows the no-camera message if none does.
- **AC-ST-6:** `denied`, `restricted`, `notDetermined`, `noCamera`, and `failed` are distinct states with distinct copy and distinct symbols. None collapses into a generic error.
- **AC-ST-7:** In **every** state in this group, the audio toggle keeps its normal behaviour. A preview failure never disables it.
- **AC-ST-8:** In **every** state in this group, the camera toggle keeps its normal behaviour. A preview failure never disables it.
- **AC-ST-9:** No preview failure presents a modal alert. All preview state messaging is inline in the preview area.
- **AC-ST-10:** All state messages follow the product's voice: clear, non-blaming, sentence case, no exclamation marks.

### Accessibility

- **AC-AX-1:** The audio toggle, camera toggle, camera picker, and Quit each carry an `accessibilityLabel` and a stable `accessibilityIdentifier` (`recordToggle`, `videoModeToggle`, `cameraPicker`, `quitButton`).
- **AC-AX-2:** The audio toggle's label and tooltip reflect its current state ("Start recording" / "Stop recording").
- **AC-AX-3:** The preview area carries an accessibility label describing what it is (`cameraPreview`).
- **AC-AX-4:** Every inline state message is readable by VoiceOver.
- **AC-AX-5:** The preview area and its controls introduce no focus ring, consistent with the button row.
- **AC-AX-6:** The decorative "Audio" label is hidden from accessibility, since the toggle it labels carries its own label.

### Persistence

- **AC-PS-1:** Exactly **one** value persists: the selected camera's unique identifier (string), under `preview.cameraDeviceID`.
- **AC-PS-2:** Persistence uses `UserDefaults`. No SwiftData model container is introduced. This is a recorded deviation from `tech-config.md`, which lists SwiftData for the macOS layer.
- **AC-PS-3:** A first launch with no stored value uses a connected default camera.
- **AC-PS-4:** No other UI state persists. The camera toggle and the recording state both reset on each launch.

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

---

## Risks and mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| The two Shortcuts are missing or renamed | Medium | High | `NSWorkspace.open` failure throws a typed error and the alert names the required Shortcut |
| Voice Memos takes longer than 1.5s to exit | Low | Medium | `VMAudioServiceErrorDomain` error 5 surfaces in Shortcuts; the wait is documented in CLAUDE.md and can be lengthened |
| A user expects the camera toggle to record video | **High** | Medium | The toggle's label and tooltip both say "Show camera preview". The gap is stated at the top of this PRD. Accepted, not solved |
| One toggle for start and stop hides the "stop" affordance | Low | Medium | The glyph changes to `stop.fill` and the tooltip changes to "Stop audio recording" while recording |
| Icon-only controls are unlearnable for a new user | Medium | Medium | Every control carries an accessibility label and a tooltip; the audio toggle also carries a visible "Audio" text label |
| Popover staying open is mistaken for a hung UI | Low | Low | The menu bar icon turns green and the badge blinks, so recording state is visible outside the popover |
| macOS 14 minimum excludes macOS 13 users | Low | High | Documented minimum; solo-use app |
| A 504pt panel feels oversized at rest, even with the preview closed | Medium | Low | Accepted deliberately. A variable width made the panel jump horizontally, which was worse than a wide empty row |
| Camera activity light cycling with the popover confuses the user | Medium | Low | Accepted trade-off; the alternative is holding the camera open in the background |
| A preview failure blocks a recording the user needed | Low | High | AC-ST-7 and AC-ST-8 make non-blocking behaviour testable in every failure state; AC-ST-9 forbids modal alerts |
| CI's unsigned build re-prompts for camera permission on every rebuild | High | Low | Documented in the CI note so a repeated prompt is not mistaken for a permission bug |
| Long external camera names overflow the picker | Medium | Low | AC-CAM-8 caps the picker at 200pt and requires truncation |
| Removing `@MainActor` annotations builds locally but fails in CI | Medium | Medium | AC-SW-8 makes the annotations a testable requirement; the reason is recorded in CLAUDE.md |

---

## Known limitations

- **No video capture.** See the dedicated section above. This is the largest single gap in the product.
- **Mirroring is not user-adjustable.** It is hardcoded on. A user who wants an unmirrored view has no way to get one.
- **The camera activity light cycles with the popover.** The session stops on close and resumes on open. Accepted by the human in exchange for not holding the camera open in the background.
- **The panel is a fixed 504pt wide even with the preview closed.** Chosen over a variable width because a width change made the panel visibly jump.
- **The panel cannot be moved.** It is pinned 8pt from the right of the screen's visible frame.
- **Nothing but the camera ID persists.** The camera toggle resets on every launch.

---

## Assumptions: resolved

Every assumption recorded as open before implementation is now settled.

| # | Assumption | Outcome |
|---|------------|---------|
| U-1 | The `MenuBarExtra` panel keeps its trailing edge pinned and grows leftward | **Wrong.** `MenuBarExtraWindow` anchors to the status item and reverts origin changes made inside `setFrame` (asking for x=1072 landed at x=848). Right-alignment is imposed by `PanelSizer` via a `setFrameOrigin` immediately after `setFrame` |
| U-2 | The width change can be animated | **Moot.** The panel no longer changes width. Animating the frame is also actively harmful: `animator().setFrame` animates the reverted origin, sliding the panel across the screen (AC-PNL-3) |
| U-3 | This app and Photo Booth can hold the same camera at once | **MOOT. Photo Booth is never launched**, so no second process contends for the camera. The question cannot arise in the shipped product. The related "camera busy" state was dropped as unreachable. If video capture is ever restored, this becomes an open question again |

**New constraints discovered during implementation:**

- AppKit grows the panel to fit content but never shrinks it back, stranding a full-size empty panel when the preview closes. Fixed by driving the window frame explicitly in `PanelSizer` (AC-PNL-7).
- Xcode 15.2 (Swift 5.9, used by CI) does not infer `@MainActor` on `App` or on view bodies, so explicit annotations are required (AC-SW-8).

---

## Platform notes

**Framework note:** `AVFoundation` (`AVCaptureSession`, `AVCaptureVideoPreviewLayer`, `AVCaptureDevice.DiscoverySession`) is a first-party platform framework, not a third-party dependency. No library or SPM package is introduced.

**AppKit interop:** there is no SwiftUI-native camera preview on macOS 14, so `CameraPreviewView` wraps `AVCaptureVideoPreviewLayer` in an `NSViewRepresentable`. Mandatory, not stylistic.

**CI and permission note:** CI builds unsigned. macOS ties the camera TCC grant to the signing identity and path, so **the camera permission prompt reappears on every rebuild and reinstall.** Expected for an unsigned artifact, not a defect.

**Path exception (recorded):** Swift sources stay in `MacRecordWidget/`, not under `src/` as `tech-config.md` lists. Confirmed by the human on 2026-09-04 as a deliberate exception, not drift.

**Permission prerequisite (done):** `MacRecordWidget/Info.plist` contains `NSCameraUsageDescription`. Without it the first `AVCaptureDevice.requestAccess(for: .video)` call crashes rather than producing a denial.
