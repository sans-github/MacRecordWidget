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
|  | Design | ux | Pin toggle renders taller than every other control in the row. Measured from a screenshot at the large scale: pin 43px against 36-37px for mirror, the L size toggle, the mic and the timer, all sharing the same `controlSize`. Breaks the "one control family" reading and blocks any bar-height parity work | Agent | 2026-09-24 |
|  | Swift | gap | The app has no video capture at all. Photo Booth was removed so the camera toggle would stop doing two jobs, and nothing replaced it. If video recording is wanted, it needs building on the existing capture session | Agent | 2026-09-04 |
|  | Swift | gap | Live camera preview shipped with zero test coverage: no unit tests for `CameraManager` permission, fallback or persistence logic, and no QA pass against the PRD acceptance criteria. Stage 5 was skipped | Agent | 2026-09-04 |
|  | Swift | debt | `PanelSizer` depends on undocumented `MenuBarExtraWindow` behaviour (origin reverted inside `setFrame`, reasserted via a deferred `setFrameOrigin`). Works on macOS 14 but is not contract-backed and could break on a future macOS | Agent | 2026-09-04 |
|  | Spec | gap | Feature shipped without Stage 3: there is no technical design document for the camera preview. Architecture lives only in code comments and CLAUDE.md | Agent | 2026-09-04 |
|  | Swift | gap | The three S/M/L panel-size toggles carry no per-control `accessibilityIdentifier`. Only their container has one (`panelScalePicker`), so XCUITest cannot address an individual size button | Agent | 2026-09-05 |
|  | Swift | ux | The pin toggle's `accessibilityLabel` is the static string "Keep panel open" in both states, while its tooltip flips correctly. VoiceOver therefore reads the same label whether the panel is pinned or not, unlike the audio and camera toggles | Agent | 2026-09-05 |
|  | Design | ux | `.focusEffectDisabled()` on the popover HStack removes the focus ring from all four controls, not just the power button it was added for (commit `ab33c53`). Tab still moves focus and Space still activates, but nothing is visible while tabbing. Keyboard-accessibility regression | Agent | 2026-09-04 |
|  | Design | gap | No application menu and no keyboard shortcuts anywhere: agent-only `MenuBarExtra` with no `commands {}` and no `Settings` scene, so there is no Cmd-Q or Cmd-comma. Quit is reachable only by clicking the power icon | Agent | 2026-09-04 |
|  | Spec | gap | The blinking amber dot badge on the menu bar icon (`MenuBarIcon`, 5x5, Reduce Motion aware) shipped with no PRD coverage in either feature. Master `AC-UI-5` instead described `mic`/`video` icons that do not exist in the source | Agent | 2026-09-04 |
|  | Infra | bug | `feature-init.sh` reports "kickoff-prompt.md updated with feature folder path" but the substitution does not happen; `.claude/template/kickoff-prompt.md` still names the previous feature (`projects/20260518-production-polish`), so every new feature's kickoff reads a stale path | Agent | 2026-09-04 |
|  | Infra | debt | `feature-init.sh` prints a folder tree that does not match what it creates (shows `feature-workflow-config.md` / `plan-with-human-gates.md`; actually writes `feature-setup.md` / `delivery-tracker.md`, and prints a stray `src/` line) | Agent | 2026-09-04 |
|  | Swift | bug | `NSWorkspace.open` returns true whenever the `shortcuts://` scheme is claimed, so a missing "Start"/"Stop" Shortcut still flips the app into the recording state and the `shortcutLaunchFailed` alert is unreachable | Agent | 2026-09-04 |
|  | Swift | bug | Recording name uses `DateFormatter.localizedString`, so it is locale-dependent and retains commas/spaces; `.urlQueryAllowed` is also the wrong character set for a query value | Agent | 2026-09-04 |
|  | Swift | debt | The panel pin (`PanelSizer.keepVisibleIfPinned`) fights `MenuBarExtra`'s private close-on-resign-key by re-ordering the window front, both synchronously and on the next runloop pass, because the ordering against AppKit's own handler is not guaranteed. No public API for this; could break on a future macOS | Agent | 2026-09-05 |
|  | Design | ux | The S/M/L size buttons are mounted only while the camera preview is open, but `panelScale` persists and also drives the collapsed panel's width, control sizes, spacing and padding. Selecting Small, closing the camera and quitting leaves a small collapsed panel on the next launch with no visible control to change it back. Reproduced from source (`contentWidth` is `scale.previewWidth` unconditionally, `MacRecordWidgetApp.swift:195`); the code comment claiming the scale mostly resizes the preview is wrong. Candidate fix: mount the S/M/L toggles whenever the panel is open, not only with the preview | Agent | 2026-09-05 |
|  | Design | ux | Recording state inside the panel is now carried by fill colour alone: the audio toggle is `mic.fill` in both states and only the red tint flips. The fill is a luminance change so it survives greyscale, but the redundant shape cue (the old `stop.fill` swap) is gone and a pinned + camera-on panel shows three filled buttons differing only in tint | Agent | 2026-09-05 |
|  | Design | ux | At the Small scale a 320pt row must hold seven controls, six 10pt gaps, 20pt of padding and a 12pt minimum spacer. The camera picker is the only element that can yield (maxWidth-capped, not fixed), so it is squeezed well under its 150pt cap. Needs verifying on hardware: the camera name may be unreadable or the row may clip | Agent | 2026-09-05 |
|  | Design | ux | The button row now contains no text at all after the "Audio" label was removed. Seven icon-only controls (pin, mic, video, S, M, L, power) rely on tooltips and VoiceOver labels for meaning, so nothing in the row is identifiable by scanning it | Agent | 2026-09-05 |
|  | Design | gap | The camera preview's message states (permission, no camera, failed) are drawn at a fixed 22pt symbol and 12pt copy that do not scale with `PanelScale`, so a full-sentence message occupies a much larger share of the 320x180pt Small frame than of the Large one | Agent | 2026-09-05 |
|  | Design | debt | `PanelScale` spacing values sit off the macOS 4pt grid at several steps (rowSpacing 10/14/18, verticalPadding 6/8/11). Tuned against rendered control heights rather than derived from the grid, so the panel is outside the standard HIG rhythm | Agent | 2026-09-05 |
|  | Swift | ux | A cancelled `Task.sleep` in the Voice Memos wait surfaces as a generic "Recording Error" alert instead of being ignored | Agent | 2026-09-04 |
|  | Swift | bug | Pinned panel visibly blinks the first time another app is clicked after launch: AppKit's order-out is painted before `keepVisibleIfPinned` re-shows the window. Confirmed by the user on hardware | User | 2026-09-05 |
|  | Design | ux | The audio toggle distinguishes recording from idle by fill alone, so with the pin and camera also on the user sees three filled buttons separated only by tint (red vs accent) — hue carrying the one state whose misreading is expensive. Designer proposes keeping the fill flip and adding one shape cue while recording (same symbol family). User has seen the argument and deferred the decision | Agent | 2026-09-05 |
|  | Spec | gap | Master PRD is `Status: Draft — PM, pending human re-approval` after the 2026-09-05 rewrite. The previous `Approved — Human` stamp was removed because it described a superseded document. Not a valid baseline until the human approves it | Agent | 2026-09-05 |
|  | Spec | gap | `projects/master/` has drifted from the shipped UI across a day of changes: PRD and mocks still describe the "Audio" label, `record.circle.fill`, a fixed `.controlSize(.small)`, a 504pt fixed-width panel and an inset preview. None of the pin toggle, S/M/L scaling or `mic.fill` is covered. Needs a Stage 6 pass by PM and Designer, not an ad-hoc edit | Agent | 2026-09-05 |
|  | Design | ux | The four non-capture toggles (pin, mirror, and the three S/M/L buttons) carry no `.tint`, so `.toggleStyle(.button)` fills them with `controlAccentColor`. Mirror defaults on, one size toggle is always on and the pin is often on, so the resting panel is three to five accent-blue rectangles while the two controls that actually matter (mic, video) are red and off. Accent is being spent on persistent preferences rather than on selection. Options documented in `projects/20260924-control-row-color/generated-docs/design/color-options.html` | Agent | 2026-09-24 |
|  | Design | ux | Accepted contrast failure shipped with the semantic capsules: a white glyph on the #3AD862 green measures 1.88:1 against WCAG 1.4.11's 3:1 for a control icon, and the green ember's bright point measures 1.41:1. Five of nine controls are green. The user was shown the measurements and the three remedies and chose to keep white to match the FaceTime look; recorded here so the decision stays visible rather than being rediscovered as a bug. Documented in `RowPalette` | Agent | 2026-09-24 |
|  | Swift | ux | Every toggle in the button row now uses a custom `CapsuleToggleStyle`, which is a `Button` underneath, so it no longer carries `.toggleStyle(.button)`'s native switch semantics to VoiceOver. Mitigated with `.accessibilityAddTraits(.isSelected)` while on, but that is not the same announcement a real toggle makes and has not been verified with VoiceOver | Agent | 2026-09-24 |
|  | Swift | debt | The camera menu is drawn with `.menuStyle(.button)` + `.buttonStyle(.plain)` + `.menuIndicator(.hidden)` and a hand-built label, so the green chevron well can be tinted separately from the device name. That is three style modifiers substituting for an `NSPopUpButton`'s own chrome; the pressed and disabled appearances are no longer the platform's. Needs a look on hardware | Agent | 2026-09-24 |
|  | Design | ux | Photo Booth near-parity sizing was applied to the Large scale only (control height 22pt, glyph 17/14, text 13/13, padding 7 top / 6 bottom). Medium and Small keep today's glyph and font values, so the three scales no longer step evenly: L's control height is now 22 against M's 20 and S's 17, where the gaps used to be wider. Deliberate -- the designer asked for L to be measured on hardware before M and S follow -- but it is a deferred half of a change, not a finished state | Agent | 2026-09-24 |
|  | Design | ux | The capsule geometry grows each lit control by 2pt horizontally, and the camera menu is still the only flexible item in the row. Arithmetic at the Small scale with every control on leaves the menu roughly 40pt, which truncates a camera name to about four characters. Typical states (three on) leave roughly 60pt. Not verified on hardware | Agent | 2026-09-24 |

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
|  | The "Audio" label sat beside a single toggle and implied a "Video" counterpart that does not exist | Label removed 2026-09-05; the red record glyph carries the meaning on its own | 2026-09-05 |
