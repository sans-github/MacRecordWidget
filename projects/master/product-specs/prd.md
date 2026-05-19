Status: Approved — Human
Approved: 2026-05-18

# PRD: Production Polish

## Goals

**Goal:** Bring MacRecordWidget's UI and Swift source to a shippable standard before any feature work proceeds.

| Goal | Success metric |
|------|---------------|
| HIG-compliant popover UI | All controls use semantic macOS colors, standard sizing, and correct button roles. A new user can orient the UI without confusion. |
| Idiomatic Swift codebase | Zero use of deprecated observation APIs. No raw DispatchQueue calls. No optimistic state divergence. |
| Reliable recording lifecycle | Double-tap and rapid toggle produce no duplicate shortcut invocations. Accessibility denial is handled gracefully. |
| Maintainable popover dismissal | Dismissal code is documented, intentional, and free of async timing hacks. |

**Non-goals:**
- No new user-facing features
- No new Shortcuts, no new recording modes
- No backend, no web frontend, no infrastructure changes
- No XCUITest automation (manual smoke testing only for this pass)
- No App Store submission preparation (icons, metadata, entitlements review deferred)

---

## Problem

The app works but is not shippable. Two distinct issues make it unsuitable for distribution.

**UI issues (user-visible):**
- Stop button uses a hardcoded red that ignores the system accent color and looks wrong in non-default themes
- Start button does not use `controlAccentColor`, so it blends with generic controls
- Control sizing is inconsistent with HIG recommendations for menu-bar popovers
- Typography does not use semantic macOS text styles (caption, body, etc.)

**Code issues (maintainability and reliability):**
- `ObservableObject` + `@StateObject` are the old observation model; macOS 14 ships `@Observable` which is simpler and more efficient
- Background work uses raw `DispatchQueue.global()` calls instead of structured concurrency (`async`/`await`)
- Recording state is set optimistically before the shortcut fires, so a failed launch leaves the UI in a wrong state with no recovery
- Popover dismissal relies on a 100ms `asyncAfter` hack that is undocumented and fragile (breaks on slow machines or under load)
- Accessibility permission denial in the `osascript` path is silently swallowed

---

## Target audience

**Primary:** The developer (sole author) who will distribute and maintain this app. This polish pass makes the codebase something they are comfortable shipping and maintaining.

**Secondary:** End users who install the app. They benefit from a UI that looks native and correct on any macOS theme, and from reliability improvements that prevent silent failures.

---

## Scope

Two parallel tracks. Both must complete before this feature closes.

### Track 1: UI / HIG compliance

| Item | What changes |
|------|-------------|
| Stop button | Apply `.destructive` role or equivalent tint so it uses the system destructive color, not hardcoded red |
| Start button | Apply `controlAccentColor` tint so it uses the user's chosen accent color |
| Control sizing | Audit every control against HIG menu-bar popover recommendations; resize as needed |
| Typography | Replace any hardcoded font sizes with semantic macOS text styles |
| Menu bar icon | Confirm icon state changes (mic/mic.fill, video/video.fill, green while recording) are correct and consistent |
| Spacing and layout | Align padding and gaps to HIG-recommended values for popovers |

### Track 2: Swift modernization

| Item | What changes |
|------|-------------|
| Observation model | Migrate `RecordingManager` from `ObservableObject`/`@StateObject` to `@Observable`/`@State` (requires macOS 14 deployment target) |
| Deployment target | Bump from macOS 13.0 to macOS 14.0 in the project settings |
| Background work | Replace `DispatchQueue.global()` calls with `async`/`await` and structured concurrency |
| Error propagation | Introduce typed errors for the shortcut-launch and osascript paths instead of silent `print`/ignore |
| Accessibility denial | Detect and surface Accessibility permission denial gracefully (alert or status indicator) instead of silent failure |
| Double-tap guard | Add a guard that prevents a second Start or Stop from firing while the first invocation is in flight |
| Optimistic state | Remove optimistic state setting; update `isRecording` only after the shortcut URL fires successfully or fails with an error |
| Popover dismissal | Replace the `100ms asyncAfter` with a documented, consistent approach that survives the edge cases noted in CLAUDE.md |

---

## Roadmap

### This feature (production polish pass)

All Track 1 and Track 2 items listed above. No exceptions.

**Rationale for doing both tracks together:** The UI redesign and the Swift refactor touch the same two files. Doing them separately would require two rounds of review and integration risk. They are also both blockers for any future feature work -- new features built on top of the current code or UI would inherit the problems.

### Deferred (not in this feature)

- App Store submission (icons, metadata, entitlements review)
- XCUITest automation
- Additional recording modes or Shortcuts integrations
- Settings persistence (e.g. remembering video mode across launches)

---

## App flows

### Site map

| Surface | Purpose |
|---------|---------|
| Menu bar icon | Always-visible status indicator; click opens the popover |
| Popover | Main UI: video mode toggle, Start button, Stop button, Quit button |

### User roles

| Role | Access |
|------|--------|
| App user (single role) | Full access to all controls. No auth, no multi-user concept. |

### User journeys

**1. Start a recording session**
1. User clicks the menu bar icon; popover opens
2. User optionally toggles video mode on
3. User taps Start; popover dismisses; recording begins (Voice Memos quits, shortcut fires, Photo Booth opens if video)

**2. Stop a recording session**
1. User clicks the menu bar icon while recording; popover opens (icon is green)
2. User taps Stop; popover dismisses; shortcut fires to end recording

**3. Accessibility permission denied (video mode)**
1. User taps Start with video mode on
2. macOS prompts for Accessibility permission; user denies
3. App surfaces a clear error (alert or status indicator); `isRecording` remains false; no partial state

---

## Acceptance criteria

### Track 1: UI / HIG compliance

- **AC-UI-1:** Stop button uses the system destructive color. It must look correct in both light mode and dark mode, and when the user's accent color is changed.
- **AC-UI-2:** Start button uses `controlAccentColor`. It must reflect the user's chosen accent color.
- **AC-UI-3:** All controls (toggle, buttons) meet the minimum HIG-recommended touch/click target size for menu-bar popovers.
- **AC-UI-4:** All text uses semantic macOS text styles or SF Pro dynamic type. No hardcoded font sizes.
- **AC-UI-5:** Menu bar icon correctly shows `mic` (audio, idle), `mic.fill` (audio, recording, green), `video` (video, idle), `video.fill` (video, recording, green).
- **AC-UI-6:** Popover padding and control spacing are consistent with HIG popover recommendations (no controls touching the window edge, no excessive whitespace).

### Track 2: Swift modernization

- **AC-SW-1:** `RecordingManager` uses `@Observable`. `MacRecordWidgetApp` uses `@State` to hold it. No `ObservableObject`, `@StateObject`, or `@ObservedObject` remain.
- **AC-SW-2:** Deployment target is macOS 14.0 in both the project file and any CI configuration.
- **AC-SW-3:** No raw `DispatchQueue` calls remain. All background work uses `async`/`await` with `Task { }`.
- **AC-SW-4:** The shortcut-launch path propagates a typed error on failure. The caller handles it (log + user-visible indicator).
- **AC-SW-5:** The osascript path propagates a typed error on Accessibility denial. The app shows an alert or status label; `isRecording` is not set to true.
- **AC-SW-6:** Tapping Start or Stop while the previous invocation is still in flight produces no second shortcut invocation. The button is disabled or ignores the tap until the first invocation completes.
- **AC-SW-7:** `isRecording` is updated only after the shortcut URL opens successfully. A failed open leaves `isRecording` unchanged.
- **AC-SW-8:** Popover dismissal behavior matches the documented approach in CLAUDE.md: popover can be reopened by double-click while recording; the dismissal approach is explained in an inline comment.

---

## Risks and mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| `@Observable` migration breaks the popover's reactivity (SwiftUI re-render not triggered) | Medium | High | Test Start/Stop state changes visually after migration; `@Observable` + `@State` is the documented path for macOS 14 |
| Removing optimistic state makes the UI feel sluggish (button press has no immediate feedback) | Medium | Medium | Add a loading/pending state to the button while the invocation is in flight; this also satisfies AC-SW-6 |
| Popover dismissal replacement breaks the double-click-to-reopen behavior | Medium | High | Regression test: record, click status icon, verify popover opens; the CLAUDE.md gotcha section documents exactly why `orderOut` is used |
| macOS 14 deployment target breaks users on macOS 13 | Low | High | Document the new minimum explicitly; this is a solo-use app so the author controls the machine |
| Typed error propagation adds surface area that needs UI treatment | Low | Low | Errors surface as a sheet or `NSAlert`; no persistent error state needed for a two-button app |
