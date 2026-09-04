Status: Approved — Human
Approved: 2026-05-21

# PRD: MacRecordWidget (Master)

Consolidated product baseline. Covers all shipped phases: production polish (2026-05-18) and popover button layout (2026-05-21).

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
- No settings persistence (video mode resets each launch)
- No App Store submission prep (icons, metadata, entitlements)
- No XCUITest automation (manual smoke testing only)

---

## Elevator pitch

MacRecordWidget is a menu bar app that starts and stops a recording session in one click. It fires two user-created Shortcuts ("Start" and "Stop"), quits Voice Memos first so macOS does not throw an audio-service error, and optionally opens Photo Booth for video. The whole UI is a single 200pt row of four icon controls.

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

## Conceptual data model

- The app holds one **Recording session** state, in memory only, never persisted.
- A Recording session has three flags: recording or idle, video enabled or audio only, and in flight or settled.
- A Recording session drives two **Shortcuts** by name: "Start" and "Stop". Both must exist in the user's Shortcuts app.
- A Recording session may own one **Photo Booth** launch, only when video is enabled.

---

## Roadmap

### Shipped

| Phase | Date | Contents |
|-------|------|----------|
| Production polish | 2026-05-18 | HIG pass on controls, `@Observable` migration, macOS 14 target, structured concurrency, typed errors, in-flight guard, non-optimistic state |
| Popover button layout | 2026-05-21 | Popover status dot removed, single horizontal row, popover stays open through Start and Stop, Photo Booth left running on Stop |

### Deferred

| Item | Why deferred |
|------|-------------|
| Settings persistence (remember video mode) | Low value for a solo user; resets are cheap |
| XCUITest automation | Manual smoke testing covers a four-control UI |
| App Store submission (icons, metadata, entitlements) | Distribution is via GitHub Actions artifact |
| Additional recording modes or Shortcuts | No demand yet; would expand the single-row UI |
| Full-screen Photo Booth | Removed deliberately to avoid the Accessibility permission prompt |

---

## App flows

### Site map

| Surface | Purpose |
|---------|---------|
| Menu bar icon | Always-visible status. Green while recording. Click toggles the popover. |
| Popover | The entire UI: one 200pt row with video toggle, Start, Stop, Quit. |

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

---

## Acceptance criteria

### Popover layout

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
