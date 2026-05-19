Status: Approved — Human
Approved: 2026-05-18

# HLD: Production Polish

## Architecture Summary

MacRecordWidget is a two-file SwiftUI macOS menu-bar app. This feature introduces no new components, no new dependencies, and no infrastructure changes. The work is entirely contained within the two existing Swift source files.

| Decision | Choice | Rationale |
|----------|--------|-----------|
| New components | None | Scope is polish-only; adding components would introduce unnecessary complexity |
| Dependency changes | None | All required APIs ship with macOS 14 SDK |
| Deployment target | macOS 14.0 (bumped from 13.0) | Required by `@Observable` macro; acceptable because app is solo-use |
| Observation model | `@Observable` (Observation framework) | Ships with macOS 14; simpler than `ObservableObject`, fewer re-render surprises |
| Concurrency | `async`/`await` with `Task { }` | Structured concurrency replaces raw `DispatchQueue` calls; safer, more readable |
| Error handling | Typed `enum` errors | Replaces silent `print`/ignore; enables user-visible feedback |
| Popover dismissal | `orderOut` on captured `keyWindow` + 100ms delay, with inline comment | Already implemented and documented in CLAUDE.md; approach is retained and formally documented rather than replaced with something untested |

---

## Current State

### Files

| File | Role |
|------|------|
| `MacRecordWidget/MacRecordWidgetApp.swift` | SwiftUI `@main` entry point, `MenuBarExtra` scene, all view code |
| `MacRecordWidget/RecordingManager.swift` | `ObservableObject` state holder, recording logic, shortcut URL dispatch |

### Known issues being addressed

**UI / HIG:**
- Stop button uses hardcoded red, ignores system accent color
- Start button does not use `controlAccentColor`
- No semantic text styles; font sizes may be hardcoded
- Control sizing not audited against HIG popover recommendations

**Swift:**
- `ObservableObject` + `@StateObject` (deprecated observation model for macOS 14+)
- `DispatchQueue.global()` for background work (raw, unstructured)
- Optimistic `isRecording = true` set before shortcut fires (state can diverge on failure)
- 100ms `asyncAfter` for popover dismissal (undocumented, fragile label; currently working but needs a comment)
- Accessibility denial in osascript path is silently swallowed
- No double-tap guard (rapid taps can fire duplicate shortcuts)

---

## Planned Changes

### Track 1: UI / HIG compliance (`MacRecordWidgetApp.swift`)

| Change | Detail |
|--------|--------|
| Stop button role | Apply `.destructive` role so the system destructive semantic color is used; never hardcode |
| Start button tint | Apply `.tint(.accentColor)` / `controlAccentColor` so it reflects the user's chosen accent color |
| Control sizing | Audit padding, frame, and font against HIG menu-bar popover guidelines; minimum click-target 44pt |
| Semantic text styles | Replace any hardcoded `.font(.system(size: N))` with `.font(.body)`, `.font(.caption)`, etc. |
| Menu bar icon | Verify existing `mic`/`mic.fill`/`video`/`video.fill` logic is correct and stays unchanged |
| Spacing | Align `VStack` spacing and `.padding` values to HIG-recommended popover insets |

### Track 2: Swift modernization (`RecordingManager.swift` + `MacRecordWidgetApp.swift`)

| Change | Detail |
|--------|--------|
| `@Observable` migration | Remove `ObservableObject` conformance and `@Published`; add `@Observable` macro to `RecordingManager` |
| `@State` at call site | Replace `@StateObject` in `MacRecordWidgetApp` with `@State` |
| Deployment target | Bump `MACOSX_DEPLOYMENT_TARGET` to 14.0 in `MacRecordWidget.xcodeproj` |
| Async/await | Wrap background work in `Task { }` with `await Task.sleep`; remove `DispatchQueue.global()` and `DispatchQueue.main.asyncAfter` for business logic |
| Typed errors | Add `RecordingError: Error` enum with cases for shortcut launch failure and accessibility denial |
| Error propagation | `startRecording()` and `stopRecording()` become `async throws`; callers catch and surface errors |
| Double-tap guard | Add `isInFlight: Bool` property; set true at invocation start, false on completion or error; buttons disabled when true |
| Non-optimistic state | Move `isRecording = true` to after `NSWorkspace.shared.open(url)` returns without error |
| Popover dismissal | Retain `orderOut(nil)` approach (it works and is the documented gotcha); add a block comment referencing CLAUDE.md rationale |
| Accessibility denial | Catch process exit code from osascript; if AX permission denied, set `isRecording = false` and show `NSAlert` |

---

## File Impact

| File | Changes |
|------|---------|
| `MacRecordWidget/MacRecordWidgetApp.swift` | Track 1 UI changes; `@State` call-site update; error-handling UI (alert presentation) |
| `MacRecordWidget/RecordingManager.swift` | Track 2 full refactor |
| `MacRecordWidget.xcodeproj/project.pbxproj` | Deployment target bump to 14.0 |
| `CLAUDE.md` | Update to reflect `@Observable` model and finalized dismissal approach |

No new files. No files deleted.

---

## Deployment Target Change

| Setting | Before | After |
|---------|--------|-------|
| `MACOSX_DEPLOYMENT_TARGET` | 13.0 | 14.0 |
| CI (`.github/workflows/`) | Implicit | Must specify `macosx14` runner or equivalent |

The `@Observable` macro is available from macOS 14.0. There is no workaround for macOS 13 -- the bump is a hard requirement for Track 2.

Impact: sole-author, sole-user app. The author controls the target machine. Documented in CLAUDE.md.

---

## Risk Summary

| Risk | Likelihood | Impact | Response |
|------|-----------|--------|----------|
| `@Observable` breaks SwiftUI re-render in popover | Medium | High | Verify Start/Stop visually toggle icon and button states after migration |
| Removing optimistic state introduces perceived lag | Medium | Medium | Add `isInFlight` pending state; disable buttons while in flight -- this doubles as the double-tap guard |
| `orderOut` dismissal regression after refactor | Low | High | Manual smoke: record, click icon, verify popover reopens |
| macOS 14 bump breaks CI runner | Low | Medium | Update workflow yml to `macosx14` runner; already on GitHub-hosted runners |
| Typed error surface area adds untested UI paths | Low | Low | `NSAlert` presentation is trivial; smoke test covers the Accessibility-denied flow |
