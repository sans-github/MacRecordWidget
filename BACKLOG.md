# Backlog

## For stakeholders

| | Layer | What | Why it matters | Action |
|--|-------|------|----------------|--------|

_Last triaged: --_

---

## For engineers

**Triage:**
| ID | Area | Type | Summary | Source | Date |
|----|------|------|---------|--------|------|
|  | Swift | gap | The app has no video capture at all. Photo Booth was removed so the camera toggle would stop doing two jobs, and nothing replaced it. If video recording is wanted, it needs building on the existing capture session | Agent | 2026-09-04 |
|  | Design | ux | The "Audio" label now sits beside a single toggle rather than a group of two, and implies a "Video" counterpart that does not exist | Agent | 2026-09-04 |
|  | Swift | gap | Live camera preview shipped with zero test coverage: no unit tests for `CameraManager` permission, fallback or persistence logic, and no QA pass against the PRD acceptance criteria. Stage 5 was skipped | Agent | 2026-09-04 |
|  | Swift | debt | `PanelSizer` depends on undocumented `MenuBarExtraWindow` behaviour (origin reverted inside `setFrame`, reasserted via a deferred `setFrameOrigin`). Works on macOS 14 but is not contract-backed and could break on a future macOS | Agent | 2026-09-04 |
|  | Spec | gap | Feature shipped without Stage 3: there is no technical design document for the camera preview. Architecture lives only in code comments and CLAUDE.md | Agent | 2026-09-04 |
|  | Design | ux | `.focusEffectDisabled()` on the popover HStack removes the focus ring from all four controls, not just the power button it was added for (commit `ab33c53`). Tab still moves focus and Space still activates, but nothing is visible while tabbing. Keyboard-accessibility regression | Agent | 2026-09-04 |
|  | Design | gap | No application menu and no keyboard shortcuts anywhere: agent-only `MenuBarExtra` with no `commands {}` and no `Settings` scene, so there is no Cmd-Q or Cmd-comma. Quit is reachable only by clicking the power icon | Agent | 2026-09-04 |
|  | Spec | gap | The blinking amber dot badge on the menu bar icon (`MenuBarIcon`, 5x5, Reduce Motion aware) shipped with no PRD coverage in either feature. Master `AC-UI-5` instead described `mic`/`video` icons that do not exist in the source | Agent | 2026-09-04 |
|  | Infra | bug | `feature-init.sh` reports "kickoff-prompt.md updated with feature folder path" but the substitution does not happen; `.claude/template/kickoff-prompt.md` still names the previous feature (`projects/20260518-production-polish`), so every new feature's kickoff reads a stale path | Agent | 2026-09-04 |
|  | Infra | debt | `feature-init.sh` prints a folder tree that does not match what it creates (shows `feature-workflow-config.md` / `plan-with-human-gates.md`; actually writes `feature-setup.md` / `delivery-tracker.md`, and prints a stray `src/` line) | Agent | 2026-09-04 |
|  | Swift | bug | `NSWorkspace.open` returns true whenever the `shortcuts://` scheme is claimed, so a missing "Start"/"Stop" Shortcut still flips the app into the recording state and the `shortcutLaunchFailed` alert is unreachable | Agent | 2026-09-04 |
|  | Swift | bug | Recording name uses `DateFormatter.localizedString`, so it is locale-dependent and retains commas/spaces; `.urlQueryAllowed` is also the wrong character set for a query value | Agent | 2026-09-04 |
|  | Swift | ux | A cancelled `Task.sleep` in the Voice Memos wait surfaces as a generic "Recording Error" alert instead of being ignored | Agent | 2026-09-04 |

**Active:**
| ID | Summary | Blocks | Ready? | Since |
|----|---------|--------|--------|-------|

**Resolved** (audit trail, never delete):
| ID | Summary | Resolved in | Date |
|----|---------|-------------|------|
|  | Camera contention with Photo Booth is unverified on macOS 14. The approved PRD's "preview keeps runn | Moot: Photo Booth is no longer launched, so nothing competes for the camera | 2026-09-04 |
|  | Button colors are inverted against the approved ACs: `AC-UI-1`/`AC-UI-2` require Stop to use the sys | Superseded: the row was redesigned; record and stop are now one tinted toggle | 2026-09-04 |
|  | Shipped AC says the Quit button closes Photo Booth and quits the app; source only stops an in-progre | Moot: Photo Booth is never launched now | 2026-09-04 |
|  | Dead `RecordingError.accessibilityDenied` case and its alert branch remain after the osascript full- | Removed 2026-09-04 along with the Photo Booth launch | 2026-09-04 |
|  | Spec numbering is loose: mocks draw the button row at a 200pt frame inside a 200pt panel that also carries 12p | Fixed: `.frame(width:)` now sizes content before padding is added outside it | 2026-09-04 |
|  | `MenuBarExtra(.window)` panel resize behaviour is unverified: whether a 200pt to 504pt width change animates o | Verified on hardware 2026-09-04: it animates, and the window reverts origin changes made inside `setFrame` | 2026-09-04 |
|  | Mocks assume the button row stays visually in place when the panel widens. It does not: the row is an `HStack` | Fixed in `24c2e80`/`bc` panel work: row is trailing-aligned and the panel frame is driven explicitly | 2026-09-04 |
|  | The live preview needs `AVCaptureSession` + `AVCaptureVideoPreviewLayer` in an `NSViewRepresentable` (no Swift | Implemented 2026-09-04: `CameraPreviewView.swift` wraps `AVCaptureVideoPreviewLayer`; `NSCameraUsageDescription` added | 2026-09-04 |
|  | `RecordingManager` is not `@MainActor`; `startRecording`/`stopRecording` are nonisolated async and mutate `isR | Fixed in `dec5c79`: class is now `@MainActor` | 2026-09-04 |
