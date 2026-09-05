> Status: Approved — Human
> Approved: 2026-09-04

# PRD: MacRecordWidget (Master)

Consolidated product baseline.

**Shipped:** production polish (2026-05-18), popover button layout (2026-05-21).

**Shipped 2026-09-04:** live camera preview (2026-09-04). Specified and mocked only. Stages 3, 4 and 5 were skipped by decision, so **no preview code exists in the app**. Everything in this document tagged `[SHIPPED 2026-09-04]` describes intended behaviour, not current behaviour.

> **Reading this document:** shipped behaviour is unmarked. Anything marked `[SHIPPED 2026-09-04]` has never been built and none of its acceptance criteria have been verified.

## Goals

**Product goal:** one-click voice and video recording from the macOS menu bar, with no window, no dock icon, and no context switch.

| Goal | Success metric |
|------|---------------|
| Zero-friction recording | Start or stop a recording in one click from the menu bar. |
| Chained sessions | Stop a recording and start a new one without reopening the widget or relaunching Photo Booth. |
| Native macOS feel | Controls use standard macOS control types and sizing. Correct in light and dark mode. |
| Reliable lifecycle | Rapid or double taps never fire a duplicate shortcut. Failed launches never leave the UI in a false state. |
| Idiomatic Swift | No deprecated observation APIs. No raw `DispatchQueue`. No optimistic state divergence. |

**Non-goals:**
- No backend, web frontend, or infrastructure
- No recording modes beyond the two Shortcuts ("Start", "Stop")
- No settings persistence (video mode resets each launch). The approved-but-unshipped preview design would add two persisted preferences; nothing persists today.
- No App Store submission prep (icons, metadata, entitlements)
- No XCUITest automation (manual smoke testing only)

---

## Elevator pitch

MacRecordWidget is a menu bar app that starts and stops a recording session in one click. It fires two user-created Shortcuts ("Start" and "Stop"), quits Voice Memos first so macOS does not throw an audio-service error, and optionally opens Photo Booth for video. The whole UI is a single 200pt row of four icon controls.

`[SHIPPED 2026-09-04]` An approved design extends the video toggle with a live 480x270pt camera preview inside the popover, plus a persisted camera picker and mirror toggle. None of it is implemented.

---

## Problem

Starting a recording normally means finding an app, waiting for it to launch, and clicking through its UI. Voice Memos also blocks the Shortcuts audio path if it is already open, which produces a cryptic `VMAudioServiceErrorDomain` error 5.

Prior versions of the widget added their own friction:
- A recording-status dot in the popover flickered and carried no actionable information
- Start and Stop were stacked vertically, making the popover taller than its content needed
- The popover dismissed itself after Start, so stopping required reopening it from the menu bar

---

## Target audience

**Primary:** the developer and sole author, who uses the app daily and maintains it.
**Secondary:** anyone who installs the build and has the two Shortcuts configured. They get a native-looking, non-blocking recorder.

---

## Features (shipped)

- Menu bar icon (`record.circle`) that turns green while recording, with a blinking amber badge dot that respects Reduce Motion
- `.window`-style `MenuBarExtra` popover, single horizontal row, 200pt wide
- Switch-style video toggle with a camera icon label (`video` / `video.fill`), disabled while recording
- Red `record.circle.fill` Start button, plain style
- `stop.fill` Stop button, plain style
- `power` Quit button, which stops an in-progress recording then terminates the app
- Voice Memos is quit before the Start shortcut fires, with a 1.5s wait
- Photo Booth opens on Start when video mode is on, in window mode (not full screen)
- In-flight guard prevents a duplicate shortcut invocation
- Typed errors (`shortcutLaunchFailed`, `accessibilityDenied`) surfaced through an `NSAlert`
- Popover stays open through Start and Stop; it closes only when the user clicks the menu bar icon
- No focus ring on any control (`focusEffectDisabled`)

---

## Features (approved design, NOT shipped)

`[SHIPPED 2026-09-04]` Approved 2026-09-04. No code exists for any bullet below.

- Live camera preview inside the popover, 480x270pt (16:9), **below** the existing button row
- Preview appears when the video toggle is on, collapses when it is off
- Panel grows 200pt → 504pt wide on toggle, animated, gated on `accessibilityReduceMotion` (see Unverified assumptions — AppKit may snap the resize)
- Camera picker across all connected video devices, persisted across launches
- Mirror toggle, user-facing, default on, persisted, preview-only
- Passive camera-name indicator naming the device being shown (e.g. "Logitech BRIO"), neutral styling
- Preview intended to stay live throughout recording (depends on an unverified camera-contention assumption)
- Capture session stops when the popover closes, resumes on reopen
- Inline states for: permission not determined, denied, restricted, no camera, camera disconnected mid-session, camera busy
- Start and Stop remain usable in every preview failure state

---

## Conceptual data model

- The app holds one **Recording session** state, in memory only, never persisted.
- A Recording session has three flags: recording or idle, video enabled or audio only, and in flight or settled.
- A Recording session drives two **Shortcuts** by name: "Start" and "Stop". Both must exist in the user's Shortcuts app.
- A Recording session may own one **Photo Booth** launch, only when video is enabled.

`[SHIPPED 2026-09-04]` The approved preview design adds:

- One **Preview session**, in memory only, separate from the Recording session, never writing a file.
- A Preview session shows exactly one **Camera device**, chosen from the connected video devices. A Camera device has a stable unique identifier, a display name, and a connected status.
- Two **Preferences** that outlive a launch: the selected camera's unique identifier, and mirroring on or off. **The shipped app persists nothing.**
- A Preview session has a **status**: idle, running, or a failure state (permission not determined, denied, restricted, no camera, device disconnected, device busy).
- Preview and Recording sessions are independent. Photo Booth's own camera choice is invisible to the app, so the two may show different devices.

---

## Roadmap

### Shipped

| Phase | Date | Contents |
|-------|------|----------|
| Production polish | 2026-05-18 | HIG pass on controls, `@Observable` migration, macOS 14 target, structured concurrency, typed errors, in-flight guard, non-optimistic state |
| Popover button layout | 2026-05-21 | Popover status dot removed, single horizontal row, popover stays open through Start and Stop, Photo Booth left running on Stop |

### Shipped 2026-09-04

| Phase | Approved | Contents | State |
|-------|----------|----------|-------|
| Live camera preview | 2026-09-04 | Preview surface, panel growth to 504pt, camera picker, mirror toggle, camera-name indicator, full failure-state set, persistence of two preferences | **Design and mocks only. No implementation. Stages 3 (technical planning), 4 (engineering) and 5 (QA) were skipped by decision. AC groups AC-PV, AC-PNL, AC-CAM, AC-MIR, AC-LC, AC-ST, AC-AX, AC-PS, AC-PR are all unverified.** |

Before this can ship, a future pass must complete technical planning, satisfy the Engineering prerequisites section, and resolve the Unverified assumptions section.

### Deferred

| Item | Why deferred |
|------|-------------|
| Settings persistence (remember video mode) | Low value for a solo user; resets are cheap |
| XCUITest automation | Manual smoke testing covers a four-control UI |
| App Store submission (icons, metadata, entitlements) | Distribution is via GitHub Actions artifact |
| Additional recording modes or Shortcuts | No demand yet; would expand the single-row UI |
| Full-screen Photo Booth | Removed deliberately to avoid the Accessibility permission prompt |
| Implementation of the live camera preview | Design-only pass by decision; stages 3, 4, 5 skipped |
| Driving Photo Booth's camera selection | Not possible: the app can neither read nor set Photo Booth's device |
| Preview snapshot or still capture | Photo Booth is the capturer; a second capture path duplicates it |
| Detached or full-screen preview window | Contradicts the no-window, menu-bar-only product shape |
| Keeping the capture session alive while the popover is closed | Human accepted the camera activity light cycling instead |
| Multi-camera simultaneous preview | No demand; would not fit a 504pt panel |

---

## App flows

### Site map

| Surface | Purpose |
|---------|---------|
| Menu bar icon | Always-visible status. Green while recording. Click toggles the popover. |
| Popover | The entire UI: one 200pt row with video toggle, Start, Stop, Quit. |
| Popover, preview area | `[SHIPPED 2026-09-04]` Visible only when the video toggle is on. Holds the live image or an inline state message. |
| Preview overlay controls | `[SHIPPED 2026-09-04]` Camera picker, mirror toggle, passive camera-name indicator. |
| System Settings → Privacy & Security → Camera | `[SHIPPED 2026-09-04]` External. Reached from the denied-permission state's open-settings action. |

### User roles and access

| Role | Access |
|------|--------|
| App user (single role) | All four controls. No auth, no multi-user concept. |

### User journeys

**1. Start a recording**
1. Click the menu bar icon; the popover opens
2. Optionally flip the video toggle on
3. Tap Start; Voice Memos quits, the Start shortcut fires, Photo Booth opens if video is on, the popover stays open

**2. Stop and immediately restart**
1. With the popover already open, tap Stop; the Stop shortcut fires
2. Photo Booth stays open and the popover stays open
3. Tap Start again for the next session, without touching the menu bar icon

**3. Quit while recording**
1. Tap the Quit (power) button during a recording
2. The Stop shortcut fires first
3. The app terminates

`[SHIPPED 2026-09-04]` Designed journeys for the preview:

**4. Frame the shot, then record**
1. Click the menu bar icon and flip the video toggle on; the panel grows and the preview starts
2. Adjust framing; switch camera or mirroring if needed
3. Tap Start; the preview keeps running and Photo Booth opens

**5. First-ever toggle-on (permission)**
1. Flip the video toggle on; the preview area shows a waiting state while macOS presents the camera prompt
2. Allow starts the preview; Deny shows an inline message with an "Open Settings" action
3. Start and Stop remain usable either way

**6. Camera unplugged mid-session**
1. The preview is running on the external camera and the user unplugs it
2. The preview area states the camera disconnected and falls back to another connected camera, updating the name indicator
3. If no camera remains, the no-camera message shows; recording controls stay usable throughout

---

## Preview states (approved design, NOT shipped)

`[SHIPPED 2026-09-04]` Mocked in Stage 2, never built. In **all** states below, Start, Stop, Quit, and the video toggle are intended to remain fully usable.

| State | Trigger | Preview area shows | Actions offered |
|-------|---------|--------------------|-----------------|
| Not determined | First toggle-on, permission never requested | Neutral waiting state while the macOS prompt is up | None (system prompt owns the interaction) |
| Denied | User denied camera access, or previously denied | Inline message explaining the preview needs camera access | "Open Settings" opens Privacy & Security → Camera |
| Restricted | Access blocked by policy (e.g. MDM, parental controls) | Inline message stating access is blocked by system policy | None; the user cannot change it |
| No camera connected | Zero video devices discovered | Inline message that no camera is connected | None; clears automatically when a camera appears |
| Selected camera disconnected | Saved or active device unplugged | Inline message naming the lost camera, then automatic fallback to another connected device | Picker remains available |
| Camera busy | Device in use and unavailable to this app | Inline message that the camera is in use by another app | Picker remains available so the user can switch device |
| Running | Permission granted, device available | Live image, mirrored per the setting, with the camera-name indicator | Camera picker, mirror toggle |

**Fallback rule (designed, unimplemented):** if the persisted device ID is not among the connected devices at startup or toggle-on, the app selects the system default video device and updates the name indicator. The persisted ID is **not** overwritten, so reconnecting the preferred camera restores it.

---

## Acceptance criteria

Groups `AC-L`, `AC-C`, `AC-M`, `AC-P`, `AC-R`, `AC-SW` describe **shipped, verified** behaviour. The `Live camera preview` block at the end of this section is **approved design only and entirely unverified**.

### Popover layout (shipped)

- **AC-L-1:** The popover is a single `HStack` row, 200pt wide, ordered: video toggle, Start, Stop, Quit.
- **AC-L-2:** No recording-status dot appears anywhere in the popover, in any state.
- **AC-L-3:** Every control is icon-only with an `accessibilityLabel` and a stable `accessibilityIdentifier`.
- **AC-L-4:** No control shows a focus ring.
- **AC-L-5:** Control icons are visually even in size and spacing across the row.

### Controls

- **AC-C-1:** The video toggle uses `.toggleStyle(.switch)` at `.controlSize(.small)`, labelled with `video` when off and `video.fill` when on.
- **AC-C-2:** The video toggle is disabled while recording.
- **AC-C-3:** Start renders as a red `record.circle.fill` and is disabled while recording or while an invocation is in flight.
- **AC-C-4:** Stop renders as `stop.fill` and is disabled when not recording or while an invocation is in flight.
- **AC-C-5:** Quit renders as `power`, carries a tooltip, and is never disabled.

### Menu bar icon

- **AC-M-1:** The icon is `record.circle`, rendered hierarchically, primary-coloured when idle and green while recording.
- **AC-M-2:** While recording, an amber badge dot blinks at the bottom trailing corner.
- **AC-M-3:** With Reduce Motion enabled, the badge dot is fully opaque and does not blink.
- **AC-M-4:** The badge dot is hidden from accessibility.

### Popover lifecycle

- **AC-P-1:** The popover stays open after Start.
- **AC-P-2:** The popover stays open after Stop.
- **AC-P-3:** The popover closes only when the user clicks the menu bar icon.
- **AC-P-4:** No code path calls `popover.close()` or `panel?.orderOut(nil)` after Start or Stop.

### Recording behaviour

- **AC-R-1:** If Voice Memos is running, it is terminated and the app waits 1.5s before firing the Start shortcut.
- **AC-R-2:** Start fires `shortcuts://run-shortcut?name=Start` with a timestamped recording name as text input.
- **AC-R-3:** Stop fires `shortcuts://run-shortcut?name=Stop` and does not close Photo Booth.
- **AC-R-4:** Photo Booth opens on Start only when video mode is on, and does not go full screen.
- **AC-R-5:** Quit stops an in-progress recording before terminating.

### Swift and reliability

- **AC-SW-1:** `RecordingManager` is `@Observable` and held with `@State`. No `ObservableObject`, `@StateObject`, or `@ObservedObject` remain.
- **AC-SW-2:** The deployment target is macOS 14.0 in the project file and in CI.
- **AC-SW-3:** No raw `DispatchQueue` calls remain. Background work uses `async`/`await` inside `Task { }`.
- **AC-SW-4:** A failed shortcut launch throws `RecordingError.shortcutLaunchFailed` and surfaces as an `NSAlert`.
- **AC-SW-5:** Tapping Start or Stop while an invocation is in flight produces no second shortcut invocation.
- **AC-SW-6:** `isRecording` changes only after the shortcut URL opens successfully. A failed open leaves it unchanged.

### Live camera preview — SHIPPED 2026-09-04

> `[SHIPPED 2026-09-04]` **Every criterion in the nine groups below (AC-PV, AC-PNL, AC-CAM, AC-MIR, AC-LC, AC-ST, AC-AX, AC-PS, AC-PR) is unimplemented and unverified.** They describe intended behaviour for a future implementation pass. Do not read any of them as a statement about the app as it exists. Group prefixes were chosen not to collide with the shipped `AC-L`, `AC-C`, `AC-M`, `AC-P`, `AC-R`, `AC-SW` groups.

#### Preview surface (shipped)

- **AC-PV-1:** The preview area sits **below** the existing button row, never above it and never beside it.
- **AC-PV-2:** The preview image is 480x270pt at a 16:9 aspect ratio.
- **AC-PV-3:** The preview area is visible only while the video toggle is on, and is fully removed from the layout when it is off.
- **AC-PV-4:** The preview is display-only: no code path writes the preview stream to a file, a buffer on disk, or the pasteboard.
- **AC-PV-5:** The preview keeps rendering while `isRecording` is true; Start and Stop do not stop, pause, or restart the session. (Depends on the unverified camera-contention assumption below.)
- **AC-PV-6:** The preview carries a passive text indicator naming the camera being shown, using the device's display name.
- **AC-PV-7:** The camera-name indicator uses neutral styling only: no warning colour, no caution icon, no error copy.
- **AC-PV-8:** The preview area renders correctly in both light and dark mode.

#### Panel sizing and animation (shipped)

- **AC-PNL-1:** With the video toggle off, the panel is 200pt wide and unchanged from the shipped layout.
- **AC-PNL-2:** With the video toggle on, the panel is 504x346pt.
- **AC-PNL-3:** The width change animates between 200pt and 504pt on toggle. **Unverified:** AppKit may snap the window resize instead of animating it. The animation is the intent, not a confirmed capability.
- **AC-PNL-4:** With `accessibilityReduceMotion` enabled, the panel changes size with no animation.
- **AC-PNL-5:** No panel size change causes the button row controls to reflow, reorder, or change size.
- **AC-PNL-6:** The button row is trailing-aligned so it stays pinned to the right edge as the panel grows leftward. **Certain:** an `HStack` row does not self-anchor and will re-centre unless explicitly trailing-aligned. **Unverified:** that the `MenuBarExtra` panel itself keeps its trailing edge pinned and grows leftward (~304pt of new width). This needs a human to confirm on a real machine before implementation.

#### Camera picker (shipped)

- **AC-CAM-1:** The picker lists every connected video device discovered on the system, by display name.
- **AC-CAM-2:** Selecting a device switches the preview to it and updates the camera-name indicator.
- **AC-CAM-3:** The selected device's unique identifier is persisted and restored on the next launch.
- **AC-CAM-4:** If the persisted identifier matches no connected device, the app falls back to the system default video device and the persisted identifier is left unchanged.
- **AC-CAM-5:** Reconnecting the persisted device after a fallback restores it as the previewed camera.
- **AC-CAM-6:** The picker changes the preview only. No code path attempts to read or set Photo Booth's camera.
- **AC-CAM-7:** The picker remains usable in the camera-busy and device-disconnected states.
- **AC-CAM-8:** A long device name does not push any control out of the 504pt panel; it truncates.

#### Mirror toggle (shipped)

- **AC-MIR-1:** A user-facing mirror control is visible whenever the preview area is visible.
- **AC-MIR-2:** Mirroring defaults to on for a user who has never set it.
- **AC-MIR-3:** Toggling mirroring flips the preview image horizontally, immediately.
- **AC-MIR-4:** The mirror setting is persisted and restored on the next launch.
- **AC-MIR-5:** The mirror setting affects the preview only and does not alter what Photo Booth records.

#### Session lifecycle (shipped)

- **AC-LC-1:** The capture session starts when the video toggle is turned on while the popover is open.
- **AC-LC-2:** The capture session stops when the popover closes.
- **AC-LC-3:** The capture session resumes when the popover reopens with the video toggle still on.
- **AC-LC-4:** No capture session is running while the video toggle is off.
- **AC-LC-5:** Rapidly toggling video on and off leaves at most one capture session running and no orphaned session.

#### Permission and failure states (shipped)

- **AC-ST-1:** On the first toggle-on with permission not determined, the app requests camera access and the preview area shows a neutral waiting state.
- **AC-ST-2:** When access is denied, the preview area shows an inline message plus an action that opens the macOS camera privacy settings.
- **AC-ST-3:** When access is restricted by system policy, the preview area shows an inline message and offers no settings action.
- **AC-ST-4:** When no video device is connected, the preview area shows an inline no-camera message.
- **AC-ST-5:** When the previewed camera disconnects mid-session, the preview area states that it disconnected and falls back to another connected device if one exists.
- **AC-ST-6:** When the camera is in use by another app, the preview area states that the camera is busy. **Unverified:** macOS generally permits multiple processes to read one camera, so this state may be unreachable in practice. Kept in the spec by human decision on 2026-09-04, pending verification.
- **AC-ST-7:** In **every** state in this group, Start and Stop keep their normal enabled/disabled behaviour based on recording state alone. A preview failure never disables them.
- **AC-ST-8:** In **every** state in this group, the video toggle keeps its normal enabled/disabled behaviour. A preview failure never disables it.
- **AC-ST-9:** No preview failure presents a modal alert. All preview state messaging is inline in the preview area.
- **AC-ST-10:** All state messages follow the product's voice: clear, non-blaming, sentence case, no exclamation marks.

#### Accessibility (shipped)

- **AC-AX-1:** The camera picker and mirror toggle each carry an `accessibilityLabel` and a stable `accessibilityIdentifier`.
- **AC-AX-2:** The preview area carries an accessibility label describing what it is and which camera it is showing.
- **AC-AX-3:** Every inline state message is readable by VoiceOver.
- **AC-AX-4:** The preview area and its controls introduce no focus ring, consistent with the shipped popover.

#### Persistence (shipped)

- **AC-PS-1:** Exactly two values persist: the selected camera's unique identifier (string) and the mirror flag (boolean).
- **AC-PS-2:** Persistence uses `@AppStorage` / `UserDefaults`. No SwiftData model container is introduced. This is a recorded deviation from `tech-config.md`, which lists SwiftData for the macOS layer.
- **AC-PS-3:** A first launch with no stored values uses the system default camera and mirroring on.
- **AC-PS-4:** No other UI state persists. The video toggle still resets on each launch, unchanged from today.

#### Engineering prerequisites (shipped)

- **AC-PR-1:** `RecordingManager`'s actor isolation is fixed and lands **before** any preview code.
- **AC-PR-2:** `MacRecordWidget/Info.plist` contains `NSCameraUsageDescription` with copy explaining why the app needs the camera.
- **AC-PR-3:** A persistence mechanism exists before the camera and mirror settings are wired to it.
- **AC-PR-4:** `RecordingError.accessibilityDenied` is removed.

---

## Risks and mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| The two Shortcuts are missing or renamed | Medium | High | `NSWorkspace.open` failure throws a typed error and the alert names the required Shortcut |
| Voice Memos takes longer than 1.5s to exit | Low | Medium | `VMAudioServiceErrorDomain` error 5 surfaces in Shortcuts; the wait is documented in CLAUDE.md and can be lengthened |
| Icon-only controls are unlearnable for a new user | Medium | Medium | Every control carries an accessibility label; Quit carries a tooltip |
| Popover staying open is mistaken for a hung UI | Low | Low | The menu bar icon turns green and the badge blinks, so recording state is visible outside the popover |
| macOS 14 minimum excludes macOS 13 users | Low | High | Documented minimum; solo-use app |
| No settings persistence means video mode resets each launch | Low | Low | Accepted; the toggle is one click |

`[SHIPPED 2026-09-04]` Risks carried over from the approved live camera preview design. They apply to a future implementation pass, not to the app today.

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| The preview shows a different camera than Photo Booth records | High | Medium | Passive camera-name indicator makes the mismatch visible. The app cannot read Photo Booth's setting, so this is the full extent of the mitigation |
| Implementing the preview on a `RecordingManager` that is not `@MainActor` produces intermittent UI bugs | High | High | P-1 is a hard prerequisite that must land before the preview, not alongside it. AC-PR-1 verifies the sequencing |
| Missing `NSCameraUsageDescription` crashes the app on first access request | High if forgotten | High | P-2 and AC-PR-2. Called out twice because the failure mode is a crash, not a denial |
| A 504x346pt panel feels oversized for a menu bar widget | Medium | Low | Human chose size L knowingly after the size study. The panel is 200pt at rest |
| The 200pt → 504pt resize reads as jarring, or AppKit snaps it instead of animating | Medium | Low | Animation gated on `accessibilityReduceMotion` (AC-PNL-3, AC-PNL-4). Animation feasibility is unverified |
| The panel grows in an unexpected direction, or the button row re-centres | Medium | Medium | AC-PNL-6. Row alignment is a certain requirement; window pin-edge behaviour needs on-machine confirmation first |
| Camera activity light cycling with the popover confuses the user | Medium | Low | Accepted trade-off; the alternative is holding the camera open in the background |
| A preview failure blocks a recording the user needed | Low | High | AC-ST-7 and AC-ST-8 make non-blocking behaviour testable in every failure state; AC-ST-9 forbids modal alerts |
| CI's unsigned build re-prompts for camera permission on every rebuild | High | Low | Documented in the CI note so a repeated prompt is not mistaken for a permission bug |
| Design-only pass leaves ACs unverified indefinitely | Medium | Medium | All preview ACs are explicitly scoped to a future implementation pass, and the prerequisites are recorded so that pass does not rediscover them |
| Long external camera names overflow the picker | Medium | Low | AC-CAM-8 requires truncation within the 504pt panel |

---

## Known limitations of the approved preview design (NOT SHIPPED)

`[SHIPPED 2026-09-04]`

- **The preview and Photo Booth may show different cameras.** The picker changes the preview only. The app cannot read or set Photo Booth's device. Mitigated by a passive name indicator, deliberately not a warning (no alert colour, no caution icon, no error copy).
- **The camera activity light cycles with the popover.** The session stops on close and resumes on open. Accepted by the human in exchange for not holding the camera open in the background.
- **The mirror setting affects the preview only.** What Photo Booth records is unaffected.
- **The panel is large while video is on.** 504x346pt is roughly 13% of a 1440x932pt screen. Human chose size L over the Designer's M recommendation.

---

## Unverified assumptions (must be resolved before implementation)

`[SHIPPED 2026-09-04]` These are open questions, not facts. Each needs confirmation before or during a future implementation pass.

| # | Assumption | Confidence | How to resolve |
|---|------------|-----------|----------------|
| U-1 | The `MenuBarExtra` panel keeps its **trailing edge pinned** and grows leftward by ~304pt when the preview opens | **Unverified.** The related claim that an `HStack` row does not self-anchor and must be explicitly trailing-aligned **is certain** | A human must observe the real panel resizing on a real machine. Do not design around an assumed growth direction until then |
| U-2 | The 200pt → 504pt width change can be **animated**; AppKit may snap the window resize instead | Unverified; animation is the intent, not a confirmed capability | Prototype the resize in a scratch build and observe |
| U-3 | The preview and Photo Booth can hold the **same camera simultaneously** on macOS 14, so the preview can keep running during recording (AC-PV-5) | Unverified. AC-ST-6 (camera busy) may therefore be unreachable, or AC-PV-5 may be unachievable | Test both apps against one device on macOS 14. If contention exists, AC-PV-5 must be revisited |

---

## Implementation prerequisites for the preview (NOT DONE)

`[SHIPPED 2026-09-04]` None of these exist in the app today. They are hard sequencing constraints on any future implementation pass.

| # | Prerequisite | Why it must land first |
|---|--------------|------------------------|
| P-1 | Make `RecordingManager` `@MainActor` (or otherwise fix its actor isolation) | It already mutates `isRecording` and `isInFlight` off the main actor. Adding an `AVCaptureSession` plus new observable state to the same class produces intermittent, hard-to-reproduce UI bugs. **Must land BEFORE the preview, not alongside it.** |
| P-2 | Add `NSCameraUsageDescription` to `MacRecordWidget/Info.plist` | The plist contains only `LSUIElement` today. Without it, the first `AVCaptureDevice.requestAccess(for: .video)` call crashes the app rather than producing a denial |
| P-3 | Confirm the app's camera entitlement is in place for the build configuration | Camera access must be granted to the app bundle before any device can be opened |
| P-4 | Build an `NSViewRepresentable` wrapping `AVCaptureVideoPreviewLayer` | There is **no SwiftUI-native camera preview on macOS 14**. AppKit interop is mandatory, not a stylistic choice |
| P-5 | Introduce a persistence mechanism (`@AppStorage` / `UserDefaults`) | The app persists nothing today. This deviates from `tech-config.md`, which lists SwiftData for the macOS layer; the deviation was confirmed by the human on 2026-09-04 because the feature persists two scalars and there is no growth path to a relational model |
| P-6 | Remove the dead `RecordingError.accessibilityDenied` case | A stale accessibility-denied case sitting next to a new camera-denied path invites confused error copy |

**Framework note:** `AVFoundation` (`AVCaptureSession`, `AVCaptureVideoPreviewLayer`, `AVCaptureDevice.DiscoverySession`) is a first-party platform framework, not a third-party dependency. No new library or SPM package is introduced.

**CI and permission note:** CI builds unsigned. macOS ties the camera TCC grant to the signing identity and path, so **the camera permission prompt will reappear on every rebuild and reinstall.** Expected for an unsigned artifact, not a defect.

**Path exception (pre-existing, recorded):** Swift sources stay in `MacRecordWidget/`, not under `src/` as `tech-config.md` lists. Confirmed by the human on 2026-09-04 as a deliberate exception, not drift.


## Implementation findings (2026-09-04)

The feature shipped the same day it was designed. Three assumptions recorded as
unverified were settled by building it, and one of them was wrong.

| ID | Assumption | Outcome |
|---|---|---|
| U-1 | Panel pins its own trailing edge and grows ~304pt leftward | **Wrong.** `MenuBarExtraWindow` anchors to the status item and reverts origin changes made inside `setFrame`. Right-alignment is imposed by `PanelSizer`, which reasserts the origin on the next runloop pass, 8pt from the screen's visible frame. |
| U-2 | AppKit may snap rather than animate the width change | **Resolved: it animates**, via `NSAnimationContext` on the window. |
| U-3 | This app and Photo Booth can hold the same camera at once | **Still untested.** The preview is left running during recording on this assumption. `AC-PV-5` and `AC-ST-6` both depend on it. |

Two defects found during implementation that the design did not anticipate:

- AppKit grows the panel to fit content but never shrinks it back, stranding a
  full-size empty panel when the preview closes. Fixed by driving the window
  frame explicitly.
- Xcode 15.2 (Swift 5.9, used by CI) does not infer `@MainActor` on `App` or on
  view bodies, so explicit annotations are required. This is a build constraint,
  not a design one, but it is why `AC-PR-1` mattered.
