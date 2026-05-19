Status: Approved — Human
Approved: 2026-05-18

# Implementation Plan: Production Polish

## Summary

Two-track polish pass on a two-file SwiftUI macOS menu-bar app. No new components, no new dependencies, no infrastructure.

| Track | Scope | Files touched |
|-------|-------|---------------|
| Track 1: UI / HIG | Button roles, semantic colors, typography, spacing | `MacRecordWidgetApp.swift` |
| Track 2: Swift modernization | `@Observable`, async/await, typed errors, double-tap guard, deployment target | `RecordingManager.swift`, `MacRecordWidgetApp.swift`, `project.pbxproj` |

Active roles: Swift Engineer (implementation), macOS Designer (component spec), QA (manual smoke), EM (approvals).

---

## Stage 4: Engineering

### Step 4.1 -- Swift Engineer: Produce Swift Detailed Design

**Who:** Swift Engineer
**Artifact:** `projects/20260518-production-polish/generated-docs/architecture/swift-detailed-design.md` + `.html`
**Done when:** File exists at that path with all required sections, and Status: Approved -- EM is set in the file by EM.

The design must cover:

- View tree breakdown (what changes in `MacRecordWidgetApp.swift`, annotated per AC)
- `RecordingManager` refactor plan: `@Observable` migration, `async throws` signatures, `RecordingError` enum cases, `isInFlight` guard property
- Popover dismissal: confirm `orderOut` approach is retained; document the inline comment that will be added
- Error surface: how accessibility-denied and shortcut-launch-failed errors reach the user (NSAlert vs status label)
- Deployment target: confirm `MACOSX_DEPLOYMENT_TARGET` = 14.0 in project settings

### Step 4.2 -- EM: Review and approve Swift Detailed Design

**Who:** EM
**Done when:** `Status: Approved -- EM` written at top of `swift-detailed-design.md`.

Blocking check: design must address every AC in the PRD (AC-UI-1 through AC-UI-6, AC-SW-1 through AC-SW-8). Hard-block if any AC is unaddressed.

### Step 4.3 -- macOS Designer: Finalise component spec from approved mocks

**Who:** macOS Designer
**Artifact:** Component spec file or section in `projects/20260518-production-polish/generated-docs/design/` (e.g. `component-spec.md`)
**Done when:** Spec is present at that path and maps every UI element to its AppKit/SwiftUI control, semantic color token, and spacing value. EM confirms presence.

The spec must cover:

- Start button: control type, tint/role, sizing
- Stop button: control type, destructive role, sizing
- Video toggle: control type, label style
- Quit button: control type, placement
- Popover padding, VStack spacing values
- All font references resolved to semantic macOS text styles

### Step 4.4 -- EM: Produce Swift Engineer Issues List

**Who:** EM
**Done when:** Issues list document produced and `Status: Approved -- EM` set. List must contain one GH issue per logical unit of work (at minimum: Track 1 UI changes, Track 2 observation migration, Track 2 concurrency refactor, Track 2 error handling, Track 2 deployment target bump).

### Step 4.5 -- Swift Engineer: Create GitHub Issues

**Who:** Swift Engineer
**Done when:** All issues from the approved Issues List exist in GitHub with correct labels. EM verifies issue URLs are recorded.

Depends on: Step 4.4 approved.

### Step 4.6 -- Swift Engineer: Implement Track 1 UI changes

**Who:** Swift Engineer
**Artifact:** `MacRecordWidget/MacRecordWidgetApp.swift`
**Done when:** All AC-UI-1 through AC-UI-6 are satisfied; app builds clean; no compiler warnings introduced. Verified by visual inspection against mocks and component spec.

Changes:
- Stop button: `.destructive` role applied; no hardcoded color
- Start button: `.tint(.accentColor)` applied
- Control sizing audited; minimum 44pt click targets
- Semantic text styles applied; no `.system(size: N)` remaining
- VStack/padding values match component spec
- Menu bar icon logic verified unchanged

### Step 4.7 -- Swift Engineer: Implement Track 2 Swift modernization

**Who:** Swift Engineer
**Artifacts:** `MacRecordWidget/RecordingManager.swift`, `MacRecordWidget/MacRecordWidgetApp.swift`, `MacRecordWidget.xcodeproj/project.pbxproj`
**Done when:** All AC-SW-1 through AC-SW-8 are satisfied; app builds clean on macOS 14 SDK; no compiler warnings; CI passes.

Changes (in order, each a discrete commit):
1. Bump `MACOSX_DEPLOYMENT_TARGET` to 14.0 in project settings (AC-SW-2)
2. Migrate `RecordingManager` to `@Observable`; update `MacRecordWidgetApp` to use `@State` (AC-SW-1)
3. Add `RecordingError` typed enum; convert `startRecording` and `stopRecording` to `async throws` (AC-SW-4, AC-SW-5)
4. Replace `DispatchQueue.global()` with `Task { }` and `await Task.sleep`; remove all raw `DispatchQueue` calls (AC-SW-3)
5. Add `isInFlight` guard; disable Start/Stop buttons while in-flight (AC-SW-6)
6. Move `isRecording = true` to after successful shortcut URL open; handle failure (AC-SW-7)
7. Detect Accessibility denial from osascript; surface `NSAlert`; ensure `isRecording` stays false (AC-SW-5)
8. Add inline comment to `orderOut` dismissal block referencing CLAUDE.md rationale (AC-SW-8)

### Step 4.8 -- EM: Review and approve Swift Engineer implementation

**Who:** EM
**Done when:** EM has verified each AC against the submitted implementation; no open blockers; approval recorded.

Review checklist:
- All AC-UI-1 through AC-UI-6 present in `MacRecordWidgetApp.swift`
- All AC-SW-1 through AC-SW-8 present in source files
- No remaining `ObservableObject`, `@StateObject`, `DispatchQueue.global()` or `DispatchQueue.main.asyncAfter` (except the documented dismissal block)
- Deployment target in `.xcodeproj` is 14.0
- CI build passes

Hard-block: if any AC is missing, implementation goes back to Swift Engineer before Stage 5 begins.

---

## Stage 5: Quality Assurance

### Step 5.1 -- QA: Produce manual smoke test plan

**Who:** QA
**Artifact:** `projects/20260518-production-polish/generated-docs/qa/test-plan.md` + `.html`
**Done when:** File exists at that path covering all smoke scenarios, and `Status: Approved -- EM` is set in the file by EM.

The plan must cover (no automation -- manual only):

- Idle state: menu bar icon shows `mic` (audio) or `video` (video mode on)
- Start recording: icon turns `mic.fill` / green; popover dismisses
- Stop recording: icon returns to `mic` / non-green; popover dismisses
- Video mode toggle: disabled while recording; icon reflects video state
- Accessibility denied: start with video mode on, deny permission, verify alert shown, `isRecording` remains false
- Double-tap guard: rapid Start taps produce only one shortcut invocation
- Popover reopen while recording: double-click icon while recording; verify popover opens
- Quit while recording: confirm Stop fires before termination
- Light mode / dark mode: Start button uses accent color; Stop button uses destructive color in both modes
- Non-default accent color: Start button reflects changed accent color

### Step 5.2 -- EM: Review and approve test plan

**Who:** EM
**Done when:** `Status: Approved -- EM` written at top of `test-plan.md`.

Blocking check: every AC from the PRD must map to at least one smoke scenario. Reject if any AC is uncovered.

### Step 5.3 -- QA: Execute manual smoke tests

**Who:** QA
**Done when:** All smoke scenarios from the approved test plan pass. Results recorded in a test results section appended to `test-plan.md` (pass/fail per scenario, macOS version tested, date).

Depends on: Step 4.8 (EM approved implementation), Step 5.2 (EM approved test plan).

### Step 5.4 -- EM: Review and approve test results

**Who:** EM
**Done when:** EM has reviewed pass/fail results; all scenarios pass; no open blockers. Approval noted in delivery tracker.

Hard-block: any failing scenario must be resolved by Swift Engineer before approval. Failed scenario goes back as a bug to Step 4.7.
