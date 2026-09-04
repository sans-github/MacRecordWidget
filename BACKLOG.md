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
|  | Infra | bug | `feature-init.sh` reports "kickoff-prompt.md updated with feature folder path" but the substitution does not happen; `.claude/template/kickoff-prompt.md` still names the previous feature (`projects/20260518-production-polish`), so every new feature's kickoff reads a stale path | Agent | 2026-09-04 |
|  | Infra | debt | `feature-init.sh` prints a folder tree that does not match what it creates (shows `feature-workflow-config.md` / `plan-with-human-gates.md`; actually writes `feature-setup.md` / `delivery-tracker.md`, and prints a stray `src/` line) | Agent | 2026-09-04 |
|  | Swift | bug | `RecordingManager` is not `@MainActor`; `startRecording`/`stopRecording` are nonisolated async and mutate `isRecording`/`isInFlight` off the main thread while SwiftUI observes on main. Data race, and Swift 6 strict concurrency will reject it | Agent | 2026-09-04 |
|  | Swift | bug | `NSWorkspace.open` returns true whenever the `shortcuts://` scheme is claimed, so a missing "Start"/"Stop" Shortcut still flips the app into the recording state and the `shortcutLaunchFailed` alert is unreachable | Agent | 2026-09-04 |
|  | Swift | debt | Dead `RecordingError.accessibilityDenied` case and its alert branch remain after the osascript full-screen call was removed; the copy tells users to grant a permission the app no longer needs | Agent | 2026-09-04 |
|  | Swift | bug | Recording name uses `DateFormatter.localizedString`, so it is locale-dependent and retains commas/spaces; `.urlQueryAllowed` is also the wrong character set for a query value | Agent | 2026-09-04 |
|  | Swift | ux | A cancelled `Task.sleep` in the Voice Memos wait surfaces as a generic "Recording Error" alert instead of being ignored | Agent | 2026-09-04 |

**Active:**
| ID | Summary | Blocks | Ready? | Since |
|----|---------|--------|--------|-------|

**Resolved** (audit trail, never delete):
| ID | Summary | Resolved in | Date |
|----|---------|-------------|------|
