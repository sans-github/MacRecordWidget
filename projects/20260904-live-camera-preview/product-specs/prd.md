> Status: Approved — Human
> Approved: 2026-09-04

# PRD: Live Camera Preview

**Feature folder:** `projects/20260904-live-camera-preview`
**Author:** PM
**Date:** 2026-09-04
**Baseline:** extends `projects/master/product-specs/prd.md` (approved 2026-05-21)

> **This is a design-only pass.** Stages 3 (Technical Planning), 4 (Engineering), and 5 (QA) are skipped per the approved kickoff plan. No Swift code, no detailed design, no HLD, and no tests are produced. The deliverables are this PRD and an approved set of mocks. Every acceptance criterion below is written to be verified in a **future implementation pass**, not in this one.

## Goals

**Feature goal:** let the user frame the shot before recording, inside the popover, instead of discovering a bad angle once Photo Booth is already rolling.

| Goal | Success metric |
|------|---------------|
| Frame before recording | Flipping the video toggle on shows a live camera image without leaving the popover. |
| Never block recording | In every permission, hardware, and error state, Start and Stop stay usable. |
| Stable device choice | Camera selection and mirror setting survive an app relaunch. |
| Honest about what is shown | The preview always names the camera it is displaying, so a mismatch with Photo Booth is visible. |
| Native macOS feel | Standard controls, correct in light and dark mode, animation gated on Reduce Motion. |

**Non-goals:**
- No recording from the preview. The preview never writes a file; Photo Booth remains the sole capturer.
- No full-screen or detached preview window. The preview lives only in the popover.
- No control over Photo Booth's own camera selection. The app cannot read or set it.
- No audio monitoring, level meters, or microphone selection.
- No resolution, frame-rate, exposure, or white-balance controls.
- No implementation in this pass (see the design-only note above).

---

## Elevator pitch

Today the video toggle only decides whether Start also launches Photo Booth. This feature gives it a second, immediate effect: it opens a 480x270pt live camera preview directly below the button row, so the user can check framing and lighting before recording. The preview is display-only. Two new persisted controls come with it: a camera picker across connected devices and a mirror toggle (on by default). The preview keeps running while recording. It stops when the popover closes and resumes on reopen. Permission and hardware failures degrade to an inline message and never block Start or Stop.

---

## Problem

- The user finds out the camera angle was wrong only after Photo Booth is already recording. The take is wasted.
- Photo Booth's own window is the only way to check framing, which defeats the point of a no-context-switch menu bar widget.
- The user owns more than one camera (built-in FaceTime plus an external Logitech BRIO). There is no way to see which one is live without opening another app.
- Mirroring expectations differ per person, and there is nothing to set today.

Who feels it: the daily user, on every video session where framing matters.

---

## Target audience

**Primary:** the developer and sole author, recording video sessions daily from the menu bar.
**Secondary:** anyone who installs the build with the two Shortcuts configured and at least one camera attached.

---

## Features (this feature, MVP)

- Live camera preview inside the popover, 480x270pt (16:9), positioned **below** the existing button row
- Preview appears when the video toggle is on and collapses when it is off
- Panel animates 200pt → 504pt wide on toggle, animation gated on `accessibilityReduceMotion`
- Camera picker across all connected video devices, persisted across launches
- Mirror toggle, user-facing, default on, persisted across launches, applies to the preview only
- Passive camera-name indicator on the preview naming the device being shown (e.g. "Logitech BRIO")
- Preview stays live throughout recording
- Capture session stops when the popover closes and resumes on reopen
- Explicit inline states for: permission not determined, denied or restricted, no camera connected, selected camera disconnected mid-session, camera busy
- Record and Stop remain usable in every failure state

---

## Conceptual data model

- The app holds one **Preview session**, in memory only. It is separate from the Recording session and never writes a file.
- A Preview session shows exactly one **Camera device** at a time, chosen from the list of connected video devices.
- A Camera device has a stable unique identifier, a display name, and a connected/disconnected status.
- The app holds two **Preferences** that outlive a launch: the selected camera's unique identifier, and mirroring on or off.
- A Preview session has a **status**: idle, running, or one of the failure states (permission not determined, denied, restricted, no camera, device disconnected, device busy).
- A Preview session is independent of the Recording session. Neither can block the other. Photo Booth's own camera choice is invisible to the app, so the Preview session and the recording may show different devices.

---

## Roadmap

### MVP (this pass, design only)

| In | Rationale |
|----|-----------|
| Preview below the button row, size L (480x270pt) | Chosen by the human from the size study, over the Designer's M recommendation. |
| Animated panel resize, gated on Reduce Motion | Keeps the idle panel small while making the growth legible. |
| Camera picker, persisted | The user owns multiple cameras; picking one every launch is friction. |
| Mirror toggle, persisted, default on | Matches Photo Booth's default so the preview does not surprise. |
| Passive camera-name indicator | Makes a preview/Photo Booth mismatch visible without alarming the user. |
| All failure states designed | A broken preview must never cost the user a recording. |

### Deferred

| Item | Why deferred |
|------|-------------|
| Swift implementation of everything above | Stages 3, 4, 5 are skipped in this pass. Design-only by decision. |
| Driving Photo Booth's camera selection | Not possible: the app can neither read nor set Photo Booth's device. |
| Preview snapshot or still capture | Photo Booth is the capturer; adding a second capture path duplicates it. |
| Detached or full-screen preview window | Contradicts the no-window, menu-bar-only product shape. |
| Keeping the session alive while the popover is closed | The human accepted the camera activity light cycling instead of holding the camera open. |
| Multi-camera simultaneous preview | No demand; would not fit a 504pt panel. |

---

## App flows

### Site map

| Surface | Purpose |
|---------|---------|
| Menu bar icon | Unchanged. Status, green while recording. Click toggles the popover. |
| Popover, button row | Unchanged 4 controls: video toggle, Start, Stop, Quit. |
| Popover, preview area | New. Visible only when the video toggle is on. Holds the live image or an inline state message. |
| Preview overlay controls | New. Camera picker, mirror toggle, and the passive camera-name indicator. |
| System Settings → Privacy & Security → Camera | External. Reached from the denied-permission state's open-settings action. |

### User roles and access

| Role | Access |
|------|--------|
| App user (single role) | All controls. No auth, no multi-user concept. |

### User journeys

**1. Frame the shot, then record**
1. Click the menu bar icon and flip the video toggle on; the panel grows and the preview starts
2. Adjust framing while watching the preview; switch camera or mirroring if needed
3. Tap Start; the preview keeps running and Photo Booth opens

**2. First-ever toggle-on (permission)**
1. Flip the video toggle on; the preview area shows a waiting state and macOS presents the camera prompt
2. Allow: the preview starts. Deny: the preview area shows an inline message with an "Open Settings" action
3. In either case, Start and Stop remain usable

**3. Camera unplugged mid-session**
1. The preview is running on the external camera and the user unplugs it
2. The preview area states that the camera disconnected and falls back to another connected camera, updating the name indicator
3. If no camera remains, the preview shows the no-camera message; recording controls stay usable throughout

---

## Preview states

Every state below must be mocked in Stage 2. In **all** of them, Start, Stop, Quit, and the video toggle remain fully usable.

| State | Trigger | Preview area shows | Actions offered |
|-------|---------|--------------------|-----------------|
| Not determined | First toggle-on, permission never requested | Neutral waiting state while the macOS prompt is up | None (system prompt owns the interaction) |
| Denied | User denied camera access, or previously denied | Inline message explaining the preview needs camera access | "Open Settings" opens Privacy & Security → Camera |
| Restricted | Access blocked by policy (e.g. MDM, parental controls) | Inline message stating access is blocked by system policy | None; no settings action, since the user cannot change it |
| No camera connected | Zero video devices discovered | Inline message that no camera is connected | None; state clears automatically when a camera appears |
| Selected camera disconnected | Saved or active device unplugged | Inline message naming the lost camera, then automatic fallback to another connected device | Picker remains available |
| Camera busy | Device in use and unavailable to this app | Inline message that the camera is in use by another app | Picker remains available so the user can switch device |
| Running | Permission granted, device available | Live image, mirrored per the setting, with the camera-name indicator | Camera picker, mirror toggle |

**Fallback rule:** if the persisted device ID is not among the connected devices at startup or at toggle-on, the app selects the system default video device and updates the name indicator. The persisted ID is **not** overwritten by a fallback, so reconnecting the preferred camera restores it.

---

## Known limitations

- **The preview and Photo Booth may show different cameras.** The camera picker changes the preview only. The app cannot read or set Photo Booth's device. Mitigation: the preview carries a **passive indicator naming the camera it is showing** (e.g. "Logitech BRIO"), so a mismatch is visible at a glance. This is deliberately not a warning (no alert colour, no caution icon, no error copy). It is a plain label.
  *(This supersedes the earlier requirements capture, which stated the mismatch would carry no user-facing affordance at all. Changed by human decision on 2026-09-04.)*
- **The camera activity light cycles with the popover.** The session stops on close and resumes on open, so the light blinks off and on as the user opens the panel. Accepted by the human in exchange for not holding the camera open in the background.
- **The mirror setting affects the preview only.** What Photo Booth records is unaffected.
- **The panel is large while video is on.** 504x346pt is roughly 13% of a 1440x932pt screen. Accepted by the human, who chose size L over the Designer's M recommendation.

---

## Engineering prerequisites

Recorded here, **not done in this pass**. Stage 4 is off. A future implementation pass inherits these as hard sequencing constraints.

| # | Prerequisite | Why it must land first |
|---|--------------|------------------------|
| **P-1** | Make `RecordingManager` `@MainActor` (or otherwise fix its actor isolation) | It already mutates `isRecording` and `isInFlight` off the main actor. The preview adds an `AVCaptureSession` plus new observable state to the same class. Building on a class that already races produces intermittent, hard-to-reproduce UI bugs. **This must be fixed BEFORE the preview is implemented, not alongside it.** |
| **P-2** | Add `NSCameraUsageDescription` to `MacRecordWidget/Info.plist` | The plist contains only `LSUIElement` today. Without the usage description, the first `AVCaptureDevice.requestAccess(for: .video)` call crashes the app rather than producing a denial. Not optional. |
| **P-3** | Introduce a persistence layer | The app persists nothing today. The camera ID and mirror flag both must survive relaunch. |
| **P-4** | Remove the dead `RecordingError.accessibilityDenied` case | This feature introduces a real permission-denied path. A stale accessibility-denied case sitting next to a new camera-denied path invites confused error copy. Cheap to remove while the error surface is being touched. |

### Recorded deviations from `tech-config.md`

| Deviation | Decision | Rationale |
|-----------|----------|-----------|
| Persistence uses `@AppStorage` / `UserDefaults`, **not** SwiftData as listed for the macOS layer | Confirmed by human, 2026-09-04 | The feature persists two scalars: a device unique-ID string and a boolean. SwiftData means a model container, a schema, migration concerns, and startup cost for a two-key preference store. There is no growth path from two preferences to a relational model. |
| Swift sources stay in `MacRecordWidget/`, **not** under `src/` | Confirmed by human, 2026-09-04 | Standard Xcode layout alongside `MacRecordWidget.xcodeproj`. Relocating would require rewriting the project's file references for no functional gain. Predates this feature; recorded as a deliberate exception, not drift. |

Both deviations are to be logged to `BACKLOG.md` triage and reflected in `tech-config.md` at a later point.

### CI and permission note

CI builds unsigned. macOS ties the camera TCC grant to the app's signing identity and path, so **the camera permission prompt reappears on every rebuild and reinstall.** This is expected behaviour for an unsigned artifact, not a defect. Testers should not read a repeated prompt as a bug in the permission flow.

### Framework note

`AVFoundation` (`AVCaptureSession`, `AVCaptureVideoPreviewLayer`, `AVCaptureDevice.DiscoverySession`) is required. It is a first-party framework in the platform SDK, not a third-party dependency, and is the only way to render a live camera preview on macOS. No new library, package, or SPM dependency is introduced.

---

## Acceptance criteria

Written in the master PRD's `AC-*` group style and numbered so they merge into master cleanly. Group prefixes are new and do not collide with the existing `AC-L`, `AC-C`, `AC-M`, `AC-P`, `AC-R`, `AC-SW` groups.

**All criteria below are verified in a future implementation pass. None are verified in this design-only pass.**

### Preview surface

- **AC-PV-1:** The preview area sits **below** the existing button row, never above it and never beside it.
- **AC-PV-2:** The preview image is 480x270pt at a 16:9 aspect ratio.
- **AC-PV-3:** The preview area is visible only while the video toggle is on, and is fully removed from the layout when it is off.
- **AC-PV-4:** The preview is display-only: no code path writes the preview stream to a file, a buffer on disk, or the pasteboard.
- **AC-PV-5:** The preview keeps rendering while `isRecording` is true; Start and Stop do not stop, pause, or restart the session.
- **AC-PV-6:** The preview carries a passive text indicator naming the camera being shown, using the device's display name.
- **AC-PV-7:** The camera-name indicator uses neutral styling only: no warning colour, no caution icon, no error copy.
- **AC-PV-8:** The preview area renders correctly in both light and dark mode.

### Panel sizing and animation

- **AC-PNL-1:** With the video toggle off, the panel is 200pt wide and unchanged from the shipped layout.
- **AC-PNL-2:** With the video toggle on, the panel is 504x346pt.
- **AC-PNL-3:** The width change animates between 200pt and 504pt on toggle.
- **AC-PNL-4:** With `accessibilityReduceMotion` enabled, the panel changes size with no animation.
- **AC-PNL-5:** No panel size change causes the button row controls to reflow, reorder, or change size.

### Camera picker

- **AC-CAM-1:** The picker lists every connected video device discovered on the system, by display name.
- **AC-CAM-2:** Selecting a device switches the preview to it and updates the camera-name indicator.
- **AC-CAM-3:** The selected device's unique identifier is persisted and restored on the next launch.
- **AC-CAM-4:** If the persisted identifier matches no connected device, the app falls back to the system default video device and the persisted identifier is left unchanged.
- **AC-CAM-5:** Reconnecting the persisted device after a fallback restores it as the previewed camera.
- **AC-CAM-6:** The picker changes the preview only. No code path attempts to read or set Photo Booth's camera.
- **AC-CAM-7:** The picker remains usable in the camera-busy and device-disconnected states.
- **AC-CAM-8:** A long device name does not push any control out of the 504pt panel; it truncates.

### Mirror toggle

- **AC-MIR-1:** A user-facing mirror control is visible whenever the preview area is visible.
- **AC-MIR-2:** Mirroring defaults to on for a user who has never set it.
- **AC-MIR-3:** Toggling mirroring flips the preview image horizontally, immediately.
- **AC-MIR-4:** The mirror setting is persisted and restored on the next launch.
- **AC-MIR-5:** The mirror setting affects the preview only and does not alter what Photo Booth records.

### Session lifecycle

- **AC-LC-1:** The capture session starts when the video toggle is turned on while the popover is open.
- **AC-LC-2:** The capture session stops when the popover closes.
- **AC-LC-3:** The capture session resumes when the popover reopens with the video toggle still on.
- **AC-LC-4:** No capture session is running while the video toggle is off.
- **AC-LC-5:** Rapidly toggling video on and off leaves at most one capture session running and no orphaned session.

### Permission and failure states

- **AC-ST-1:** On the first toggle-on with permission not determined, the app requests camera access and the preview area shows a neutral waiting state.
- **AC-ST-2:** When access is denied, the preview area shows an inline message plus an action that opens the macOS camera privacy settings.
- **AC-ST-3:** When access is restricted by system policy, the preview area shows an inline message and offers no settings action.
- **AC-ST-4:** When no video device is connected, the preview area shows an inline no-camera message.
- **AC-ST-5:** When the previewed camera disconnects mid-session, the preview area states that it disconnected and falls back to another connected device if one exists.
- **AC-ST-6:** When the camera is in use by another app, the preview area states that the camera is busy. UNVERIFIED: macOS generally permits multiple processes to read one camera, so this state may be unreachable in practice. Confirmed by the human on 2026-09-04 to stay in the spec and be designed for, pending verification during implementation.
- **AC-ST-7:** In **every** state in this group, the Start and Stop buttons keep their normal enabled/disabled behaviour based on recording state alone. A preview failure never disables them.
- **AC-ST-8:** In **every** state in this group, the video toggle keeps its normal enabled/disabled behaviour. A preview failure never disables it.
- **AC-ST-9:** No preview failure presents a modal alert. All preview state messaging is inline in the preview area.
- **AC-ST-10:** All state messages follow the product's voice: clear, non-blaming, sentence case, no exclamation marks.

### Accessibility

- **AC-AX-1:** The camera picker and mirror toggle each carry an `accessibilityLabel` and a stable `accessibilityIdentifier`.
- **AC-AX-2:** The preview area carries an accessibility label describing what it is and which camera it is showing.
- **AC-AX-3:** Every inline state message is readable by VoiceOver.
- **AC-AX-4:** The preview area and its controls introduce no focus ring, consistent with the shipped popover.

### Persistence

- **AC-PS-1:** Exactly two values persist: the selected camera's unique identifier (string) and the mirror flag (boolean).
- **AC-PS-2:** Persistence uses `@AppStorage` / `UserDefaults`. No SwiftData model container is introduced.
- **AC-PS-3:** A first launch with no stored values uses the system default camera and mirroring on.
- **AC-PS-4:** No other UI state persists. The video toggle itself still resets on each launch, unchanged from today.

### Engineering prerequisites (verified at implementation time)

- **AC-PR-1:** `RecordingManager`'s actor isolation is fixed and lands **before** any preview code.
- **AC-PR-2:** `MacRecordWidget/Info.plist` contains `NSCameraUsageDescription` with copy explaining why the app needs the camera.
- **AC-PR-3:** A persistence mechanism exists before the camera and mirror settings are wired to it.
- **AC-PR-4:** `RecordingError.accessibilityDenied` is removed.

---

## Risks and mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| The preview shows a different camera than Photo Booth records | High | Medium | Passive camera-name indicator on the preview makes the mismatch visible. Documented as a known limitation. The app cannot read Photo Booth's setting, so this is the full extent of the mitigation. |
| Implementing the preview on a `RecordingManager` that is not `@MainActor` produces intermittent UI bugs | High | High | P-1 makes the isolation fix a hard prerequisite that must land before the preview, not alongside it. AC-PR-1 verifies the sequencing. |
| Missing `NSCameraUsageDescription` crashes the app on first access request | High if forgotten | High | P-2 and AC-PR-2. Called out twice in this PRD because the failure mode is a crash, not a denial. |
| A 504x346pt panel feels oversized for a menu bar widget | Medium | Low | Human chose size L knowingly after the size study. The panel is 200pt at rest and only grows while video is on. |
| The 200pt → 504pt resize on every toggle reads as jarring | Medium | Low | Animated, gated on `accessibilityReduceMotion` (AC-PNL-3, AC-PNL-4). |
| Camera activity light cycling with the popover confuses the user | Medium | Low | Accepted trade-off; the alternative is holding the camera open in the background, which is worse. Documented as a known limitation. |
| A preview failure blocks a recording the user needed | Low | High | AC-ST-7 and AC-ST-8 make non-blocking behaviour testable across every failure state. AC-ST-9 forbids modal alerts. |
| CI's unsigned build re-prompts for camera permission on every rebuild | High | Low | Documented in the CI note so a repeated prompt is not mistaken for a permission bug. |
| Design-only pass leaves ACs unverified indefinitely | Medium | Medium | All ACs are explicitly scoped to a future implementation pass, and the prerequisites are recorded so that pass does not rediscover them. Stage 8 is design sign-off, not release. |
| Long external camera names overflow the picker | Medium | Low | AC-CAM-8 requires truncation within the 504pt panel. |

---

## Decision provenance

Every decision recorded in the original requirements frontmatter and in the approved kickoff plan, preserved here. None are reopened.

| Decision | Source | Status |
|----------|--------|--------|
| Preview sits below the button row, not above | Requirements capture | Binding |
| Preview keeps running during recording; Photo Booth is the sole capturer | Requirements capture | Binding |
| Session stops on popover close, resumes on reopen; activity light cycling accepted | Requirements capture | Binding |
| Mirror toggle is user-facing, default on, persisted | Requirements capture | Binding |
| Camera picker in scope, persisted, graceful fallback if unplugged | Requirements capture | Binding |
| Picker affects the preview only, not Photo Booth | Requirements capture | Binding |
| Preview size L: 480x270pt, panel 504x346pt, ~13% of a 1440x932pt screen | Human, after the size study; Designer recommended M | Binding |
| At 480pt wide, picker and mirror toggle fit as visible controls, not an overflow menu | Size study | Binding |
| Panel animates 200pt → 504pt, gated on `accessibilityReduceMotion` | Kickoff Q2, resolved 2026-09-04 | Binding |
| Preview carries a passive camera-name indicator; no alarming warning | Kickoff Q6, resolved 2026-09-04 | **Supersedes** the frontmatter's "does not warn the user" wording |
| `@AppStorage` / `UserDefaults`, not SwiftData | Kickoff Q5, resolved 2026-09-04 | Binding; deviation recorded |
| Swift sources stay in `MacRecordWidget/`, not `src/` | Kickoff Q7, resolved 2026-09-04 | Binding; exception recorded |
| `RecordingManager` backlog items deferred; `@MainActor` fix recorded as a prerequisite | Kickoff Q4, resolved 2026-09-04 | Binding |
| Stage 7 documents design intent only; Stage 8 is design sign-off, not release | Kickoff Q3, resolved 2026-09-04 | Binding |
| Master baseline backfilled before this PRD | Kickoff Q1, resolved 2026-09-04 | Done; this PRD extends the current master |

**Superseded:** the frontmatter's key point stating "200pt panel width unchanged" was written before the size study. The panel is 504pt wide while the video toggle is on. The 200pt width applies only to the collapsed, toggle-off state.
