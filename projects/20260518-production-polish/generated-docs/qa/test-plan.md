Status: Approved — EM
Approved: 2026-05-18

# Test Plan: Production Polish (Manual Smoke)

## Scope

**In scope:** Manual smoke verification of all AC-UI-1 through AC-UI-6 and AC-SW-1 through AC-SW-8 for the production polish pass. Ten scenarios covering icon state, recording lifecycle, error handling, double-tap guard, popover behavior, quit safety, and color theming.

**Out of scope:** XCUITest automation (explicitly deferred in PRD), App Store submission checks, network/backend testing (no backend exists), and any feature not listed in the PRD.

**Risk summary:**

| Risk | Covered by |
|------|-----------|
| Icon state inconsistency across video/audio modes | TC-01, TC-02, TC-03, TC-04 |
| Duplicate shortcut invocations on rapid tap | TC-06 |
| Accessibility denial leaving partial state | TC-05 |
| Popover not reopenable while recording | TC-07 |
| Quit before Stop fires shortcut silently | TC-08 |
| Color regressions in non-default themes | TC-09, TC-10 |

---

## Test Cases

### TC-01: Idle state icon (audio and video modes)

**AC covered:** AC-UI-5

**Preconditions:**
- App is running and not recording
- macOS menubar is visible

**Steps:**
1. Observe the menu bar icon with video mode toggle OFF (default).
2. Note the icon symbol displayed.
3. Click the menu bar icon to open the popover.
4. Toggle video mode ON.
5. Close the popover (click away or press Escape).
6. Observe the menu bar icon again.

**Expected result:**
- Step 2: icon shows `mic` (outline, non-filled, non-green).
- Step 6: icon shows `video` (outline, non-filled, non-green).

**Pass / Fail:** ___

---

### TC-02: Start recording -- icon and popover

**AC covered:** AC-UI-5, AC-SW-6, AC-SW-7, AC-SW-8

**Preconditions:**
- App is running and not recording
- A Shortcut named "Start" exists and is functional
- Video mode is OFF

**Steps:**
1. Click the menu bar icon to open the popover.
2. Tap the Start button.
3. Observe the popover immediately after tapping.
4. Observe the menu bar icon after the popover dismisses.

**Expected result:**
- Step 3: popover dismisses (not left open).
- Step 4: icon shows `mic.fill` in green, indicating recording is active.

**Pass / Fail:** ___

---

### TC-03: Stop recording -- icon and popover

**AC covered:** AC-UI-5, AC-SW-7, AC-SW-8

**Preconditions:**
- App is running and actively recording (icon shows `mic.fill` green)
- A Shortcut named "Stop" exists and is functional

**Steps:**
1. Click the menu bar icon to open the popover.
2. Confirm the Start button is not the primary action; Stop button is present.
3. Tap the Stop button.
4. Observe the popover immediately after tapping.
5. Observe the menu bar icon after the popover dismisses.

**Expected result:**
- Step 4: popover dismisses.
- Step 5: icon returns to `mic` (outline, non-green), indicating idle state.

**Pass / Fail:** ___

---

### TC-04: Video mode toggle -- disabled while recording, icon reflects state

**AC covered:** AC-UI-5, AC-SW-6

**Preconditions:**
- App is running and not recording
- Video mode is OFF

**Steps:**
1. Click the menu bar icon to open the popover.
2. Toggle video mode ON. Close the popover.
3. Observe the menu bar icon (should show `video`).
4. Click the menu bar icon. Tap Start. Confirm recording begins (icon shows `video.fill` green).
5. Click the menu bar icon to reopen the popover while recording.
6. Attempt to interact with the video mode toggle.
7. Observe whether the toggle is interactive.

**Expected result:**
- Step 3: icon shows `video` (outline, non-green).
- Step 4: icon shows `video.fill` in green after recording starts.
- Step 7: video mode toggle is disabled (not interactive) while recording is in progress.

**Pass / Fail:** ___

---

### TC-05: Accessibility denied -- alert shown, isRecording stays false

**AC covered:** AC-SW-5

**Preconditions:**
- App is running and not recording
- Video mode is ON
- Accessibility permission for the app is NOT granted (revoke in System Settings > Privacy & Security > Accessibility if previously granted)

**Steps:**
1. Click the menu bar icon to open the popover.
2. Confirm video mode is ON.
3. Tap Start.
4. When macOS prompts for Accessibility permission, deny it (click "Don't Allow" or equivalent).
5. Observe any alert or error indicator shown by the app.
6. Observe the menu bar icon.

**Expected result:**
- Step 5: app displays an NSAlert or visible error indicator explaining that Accessibility permission was denied.
- Step 6: icon remains `video` (non-green); `isRecording` is false; no recording is in progress.

**Pass / Fail:** ___

---

### TC-06: Double-tap guard -- rapid Start taps produce one invocation

**AC covered:** AC-SW-6

**Preconditions:**
- App is running and not recording
- A Shortcut named "Start" exists and is functional
- Video mode is OFF

**Steps:**
1. Click the menu bar icon to open the popover.
2. Tap the Start button two or more times as quickly as possible (rapid consecutive taps).
3. Observe the Shortcuts app (or the shortcut's effect) to count how many times the "Start" shortcut was triggered.

**Expected result:**
- The "Start" shortcut fires exactly once regardless of how many rapid taps were made. After the first tap, the Start button is visually disabled or does not respond to further taps until the invocation completes.

**Pass / Fail:** ___

---

### TC-07: Popover reopen while recording

**AC covered:** AC-SW-8

**Preconditions:**
- App is running and actively recording (icon shows `mic.fill` green)

**Steps:**
1. Double-click the menu bar status item (or single-click, depending on macOS behavior for MenuBarExtra).
2. Observe whether the popover opens.
3. If it opens, verify the Stop button is present and the app UI is functional.

**Expected result:**
- Popover opens successfully while recording is active.
- Stop button is visible and the UI is not stuck or broken.
- This verifies that the dismissal approach (orderOut) does not prevent reopening.

**Pass / Fail:** ___

---

### TC-08: Quit while recording -- Stop fires before termination

**AC covered:** AC-SW-7 (state integrity on quit path)

**Preconditions:**
- App is running and actively recording (icon shows `mic.fill` green)
- A Shortcut named "Stop" exists and is functional

**Steps:**
1. Click the menu bar icon to open the popover.
2. Tap the Quit button (power icon).
3. Observe whether a Stop shortcut fires before the app exits (e.g. via Shortcuts notification or recording stopping in Voice Memos).
4. Verify the app terminates.

**Expected result:**
- The Stop shortcut fires (or recording stops) before the app fully terminates. The app does not quit silently while leaving a recording session open.

**Pass / Fail:** ___

---

### TC-09: Light mode and dark mode -- Start and Stop button colors

**AC covered:** AC-UI-1, AC-UI-2

**Preconditions:**
- App is running and not recording
- macOS is in Light mode

**Steps:**
1. Open the popover. Observe the Start button color (should match the system accent color).
2. Observe the Stop button color (should appear as a destructive/red-tinted control).
3. Switch macOS to Dark mode (System Settings > Appearance > Dark).
4. Open the popover again.
5. Observe the Start button color in Dark mode.
6. Observe the Stop button color in Dark mode.

**Expected result:**
- Steps 1 and 5: Start button uses `controlAccentColor` (reflects the current accent color setting) in both modes. Color adjusts naturally with the system theme.
- Steps 2 and 6: Stop button uses the system destructive color (red-toned, not a hardcoded hex) in both Light and Dark mode. The color reads correctly in both themes without looking out of place.

**Pass / Fail:** ___

---

### TC-10: Non-default accent color -- Start button reflects change

**AC covered:** AC-UI-2

**Preconditions:**
- App is running and not recording
- macOS accent color is set to a non-default value (e.g. Orange or Purple) via System Settings > Appearance > Accent color

**Steps:**
1. Open the popover.
2. Observe the Start button tint color.
3. Change the macOS accent color to a different non-default color (e.g. from Orange to Purple) in System Settings.
4. Return to the app and open the popover.
5. Observe the Start button tint color again.

**Expected result:**
- Step 2: Start button tint matches the currently selected accent color.
- Step 5: Start button tint updates to reflect the newly selected accent color. The button does not retain the old color or a hardcoded fallback.

**Pass / Fail:** ___

---

## AC Coverage Map

| AC | Test case(s) |
|----|-------------|
| AC-UI-1 | TC-09 |
| AC-UI-2 | TC-09, TC-10 |
| AC-UI-3 | Visual inspection during any TC (click targets >= 44pt) |
| AC-UI-4 | Visual inspection during any TC (no hardcoded font sizes) |
| AC-UI-5 | TC-01, TC-02, TC-03, TC-04 |
| AC-UI-6 | Visual inspection during any TC (no controls touching window edge) |
| AC-SW-1 | Not directly testable via manual smoke (code-level AC; verified by EM in Step 4.8) |
| AC-SW-2 | Not directly testable via manual smoke (project-level AC; verified by EM in Step 4.8) |
| AC-SW-3 | Not directly testable via manual smoke (code-level AC; verified by EM in Step 4.8) |
| AC-SW-4 | Covered indirectly by TC-02 (shortcut launch failure would surface an indicator) |
| AC-SW-5 | TC-05 |
| AC-SW-6 | TC-04, TC-06 |
| AC-SW-7 | TC-02, TC-03, TC-08 |
| AC-SW-8 | TC-02, TC-03, TC-07 |

Note: AC-UI-3, AC-UI-4, and AC-UI-6 are visual/structural ACs that apply as passive checks across all test cases. The tester should note any failure of these during any scenario and record it under the relevant TC's pass/fail entry.

---

## Test Results

To be completed by the tester after execution.

| Field | Value |
|-------|-------|
| macOS version tested | |
| Date | |
| Tester | |
| Overall result | PASS / FAIL |

| TC | Result | Notes |
|----|--------|-------|
| TC-01 | | |
| TC-02 | | |
| TC-03 | | |
| TC-04 | | |
| TC-05 | | |
| TC-06 | | |
| TC-07 | | |
| TC-08 | | |
| TC-09 | | |
| TC-10 | | |

Any failing scenario must be reported to the Swift Engineer before this plan can be approved by EM. Include the TC ID, the observed result, and the macOS version in the bug report.
