Status: Approved — EM
Approved: 2026-05-18

# Swift Detailed Design: Production Polish

## View Overview

`MacRecordWidgetApp.swift` hosts the entire view tree inside a single `MenuBarExtra` scene. The changes are confined to that file and to `RecordingManager.swift`. No new views or files are introduced.

```
MacRecordWidgetApp (@main, App)
└── MenuBarExtra(.window)
    ├── label: Image(systemName: icon)          ← icon logic unchanged (AC-UI-5)
    └── content: VStack(alignment: .leading)
        ├── HStack
        │   ├── Toggle("Include Video", ...)     ← label uses .font(.body) (AC-UI-4)
        │   └── Button(power icon)               ← plain style, unchanged
        ├── Divider
        └── VStack(spacing: 8)
            ├── Button("Start")                  ← .tint(.accentColor), min 44pt (AC-UI-2, AC-UI-3)
            └── Button("Stop")                   ← .controlSize(.large), .tint(.red) role-equivalent (AC-UI-1, AC-UI-3)
```

---

## 1. View Tree Breakdown

### 1.1 Stop button

**Current:**
```swift
Button {
    let panel = NSApp.keyWindow
    recordingManager.stopRecording()
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { panel?.orderOut(nil) }
} label: {
    Label("Stop", systemImage: "stop.fill")
        .frame(maxWidth: .infinity)
}
.disabled(!recordingManager.isRecording)
```

**Proposed:**
```swift
Button {
    Task { await stopAndDismiss() }
} label: {
    Label("Stop", systemImage: "stop.fill")
        .frame(maxWidth: .infinity)
}
.buttonStyle(.bordered)
.tint(.red)                          // semantic destructive tint; adapts to light/dark
.disabled(!recordingManager.isRecording || recordingManager.isInFlight)
```

The `tint(.red)` modifier on a `.bordered` button uses the system `.red` color role, which adapts correctly to light mode, dark mode, and all accent color settings. There is no SwiftUI `ButtonRole.destructive` on macOS for `.bordered` style buttons -- `.tint(.red)` is the correct HIG-compliant approach.

**Satisfies:** AC-UI-1

### 1.2 Start button

**Current:**
```swift
Button {
    let panel = NSApp.keyWindow
    recordingManager.startRecording()
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { panel?.orderOut(nil) }
} label: {
    Label("Start", systemImage: "mic.fill")
        .frame(maxWidth: .infinity)
}
.disabled(recordingManager.isRecording)
```

**Proposed:**
```swift
Button {
    Task { await startAndDismiss() }
} label: {
    Label("Start", systemImage: "mic.fill")
        .frame(maxWidth: .infinity)
}
.buttonStyle(.bordered)
.tint(.accentColor)
.disabled(recordingManager.isRecording || recordingManager.isInFlight)
```

**Satisfies:** AC-UI-2, AC-SW-6

### 1.3 Control sizing

**Current:** `.frame(width: 180)` on the outer VStack; no explicit minimum height on buttons.

**Proposed:** Buttons remain `.bordered` style which renders at the standard macOS control height (approximately 22pt intrinsic). The `.frame(maxWidth: .infinity)` ensures the full 180pt width is tappable. This meets the HIG click-target guidance for menu-bar popovers (menu-bar popovers are pointer-driven, not touch -- the 44pt iOS touch target does not apply; macOS HIG requires controls be at least the default control size, which `.bordered` satisfies).

**Satisfies:** AC-UI-3

### 1.4 Typography

**Current:** No explicit font modifiers are set on labels in the current code. The default SwiftUI font in a `MenuBarExtra` panel inherits `.body` (13pt Regular on macOS), which is correct. No changes required -- no hardcoded `.system(size: N)` exists in the current source.

If the Video toggle label ever gains a subtitle or secondary text, it must use `.font(.caption)`.

**Satisfies:** AC-UI-4 (confirmed no hardcoded sizes; no change needed)

### 1.5 Menu bar icon

**Current (unchanged):**
```swift
let icon = recordingManager.videoEnabled
    ? (recordingManager.isRecording ? "video.fill" : "video")
    : (recordingManager.isRecording ? "mic.fill" : "mic")
Image(systemName: icon)
    .symbolRenderingMode(.hierarchical)
    .foregroundStyle(recordingManager.isRecording ? .green : .primary)
```

No change. The logic correctly implements all four states.

**Satisfies:** AC-UI-5

### 1.6 Popover spacing and padding

**Current:** `VStack(alignment: .leading, spacing: 8)`, `.padding(12)`, inner `VStack(spacing: 6)`.

**Proposed:** Adjust to match HIG popover insets. Standard macOS popover content inset is 16pt on all sides; minimum inter-control spacing is 8pt.

```swift
VStack(alignment: .leading, spacing: 8) { ... }
    .padding(16)                           // was 12
    .frame(width: 200)                     // was 180; wider avoids label truncation
```

Inner button stack spacing stays at 8pt (raised from 6 to match standard row spacing).

**Satisfies:** AC-UI-6

### 1.7 Call-site: @State and dismiss helpers

The `@StateObject` instantiation is replaced with `@State`:

```swift
@main
struct MacRecordWidgetApp: App {
    @State private var recordingManager = RecordingManager()

    var body: some Scene { ... }

    // Dismissal helpers -- see Section 3 for rationale
    @MainActor
    private func startAndDismiss() async {
        let panel = NSApp.keyWindow
        do {
            try await recordingManager.startRecording()
        } catch {
            presentAlert(for: error)
        }
        // See CLAUDE.md "Gotchas": orderOut is used instead of popover.close()
        // because close() breaks double-click-to-reopen while recording.
        // The 100ms delay gives the button animation time to complete before
        // the window is removed from the screen.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { panel?.orderOut(nil) }
    }

    @MainActor
    private func stopAndDismiss() async {
        let panel = NSApp.keyWindow
        do {
            try await recordingManager.stopRecording()
        } catch {
            presentAlert(for: error)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { panel?.orderOut(nil) }
    }
}
```

**Satisfies:** AC-SW-1, AC-SW-3, AC-SW-8

---

## 2. RecordingManager Refactor Plan

### 2.1 @Observable migration

**Current:**
```swift
class RecordingManager: ObservableObject {
    @Published var isRecording = false
    @Published var videoEnabled = false
}
```

**Proposed:**
```swift
@Observable
final class RecordingManager {
    var isRecording = false
    var videoEnabled = false
    var isInFlight = false
}
```

Remove `import SwiftUI` from `RecordingManager.swift` (it is only needed for `@Published`; `@Observable` lives in `Observation`, which is re-exported by `SwiftUI` but is also available via `import Observation`). Keep `import Foundation`.

No changes to observation semantics from the SwiftUI side -- `@Observable` properties are tracked automatically when accessed inside a `body` computation.

**Satisfies:** AC-SW-1

### 2.2 Async throws signatures

```swift
func startRecording() async throws {
    guard !isInFlight else { return }
    isInFlight = true
    defer { isInFlight = false }

    // Quit Voice Memos if running (see CLAUDE.md gotcha)
    let voiceMemos = NSWorkspace.shared.runningApplications
        .first(where: { $0.bundleIdentifier == "com.apple.VoiceMemos" })
    voiceMemos?.terminate()
    if voiceMemos != nil {
        try await Task.sleep(for: .seconds(1.5))
    }

    let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .medium)
        .replacingOccurrences(of: "/", with: "-")
        .replacingOccurrences(of: ":", with: "-")
    let name = "Recording-\(timestamp)"

    guard let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
          let url = URL(string: "shortcuts://run-shortcut?name=Start&input=text&text=\(encoded)")
    else {
        throw RecordingError.shortcutLaunchFailed(reason: "Could not construct shortcut URL")
    }

    let opened = NSWorkspace.shared.open(url)
    guard opened else {
        throw RecordingError.shortcutLaunchFailed(reason: "NSWorkspace.open returned false")
    }

    // State is set only after the URL opens successfully (AC-SW-7)
    isRecording = true

    if videoEnabled {
        try await launchPhotoBooth()
    }
}

func stopRecording() async throws {
    guard !isInFlight else { return }
    isInFlight = true
    defer { isInFlight = false }

    guard let url = URL(string: "shortcuts://run-shortcut?name=Stop") else {
        throw RecordingError.shortcutLaunchFailed(reason: "Could not construct Stop shortcut URL")
    }

    let opened = NSWorkspace.shared.open(url)
    guard opened else {
        throw RecordingError.shortcutLaunchFailed(reason: "NSWorkspace.open returned false for Stop")
    }

    isRecording = false

    if videoEnabled {
        NSWorkspace.shared.runningApplications
            .first(where: { $0.bundleIdentifier == "com.apple.PhotoBooth" })?
            .terminate()
    }
}
```

**Satisfies:** AC-SW-3, AC-SW-6, AC-SW-7

### 2.3 RecordingError enum

```swift
enum RecordingError: Error, LocalizedError {
    case shortcutLaunchFailed(reason: String)
    case accessibilityDenied

    var errorDescription: String? {
        switch self {
        case .shortcutLaunchFailed(let reason):
            return "Could not launch the recording shortcut. \(reason)"
        case .accessibilityDenied:
            return "Accessibility permission was denied."
        }
    }
}
```

**Cases:**

| Case | When thrown | Associated value |
|------|-------------|-----------------|
| `shortcutLaunchFailed(reason:)` | `NSWorkspace.shared.open(url)` returns `false`, or URL construction fails | Human-readable reason string for logging |
| `accessibilityDenied` | `osascript` process exits with a non-zero code indicating AX permission denied | None |

**Satisfies:** AC-SW-4, AC-SW-5

### 2.4 isInFlight guard

`isInFlight: Bool` is a stored property on `RecordingManager` (tracked by `@Observable`). It is set to `true` at the very start of `startRecording()` and `stopRecording()`, and reset to `false` via `defer` on any exit path (success, throw, or early return).

The guard pattern:
```swift
guard !isInFlight else { return }
isInFlight = true
defer { isInFlight = false }
```

Both the Start and Stop buttons bind `.disabled` to `isInFlight`:
```swift
.disabled(recordingManager.isRecording || recordingManager.isInFlight)   // Start
.disabled(!recordingManager.isRecording || recordingManager.isInFlight)  // Stop
```

Because `isInFlight` is `@Observable`, SwiftUI re-renders the button disabled state as soon as the property changes on the main actor. The guard inside the function provides a second layer of protection in case a tap arrives before the UI disables.

**Satisfies:** AC-SW-6

### 2.5 isRecording set only after successful open

`NSWorkspace.shared.open(url)` is synchronous and returns `Bool`. If it returns `false`, the function throws `RecordingError.shortcutLaunchFailed` before reaching `isRecording = true`. This guarantees state is never set optimistically.

On the stop path: `isRecording = false` is placed after the `guard opened` check for symmetry, so a failed Stop URL also leaves state unchanged.

**Satisfies:** AC-SW-7

### 2.6 Photo Booth / osascript path

```swift
private func launchPhotoBooth() async throws {
    NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Photo Booth.app"))
    // Wait for Photo Booth to finish launching before sending AX event
    try await Task.sleep(for: .seconds(2.0))

    let task = Process()
    task.launchPath = "/usr/bin/osascript"
    task.arguments = ["-e",
        "tell application \"System Events\" to tell process \"Photo Booth\" " +
        "to set value of attribute \"AXFullScreen\" of window 1 to true"
    ]
    try task.run()
    task.waitUntilExit()

    if task.terminationStatus != 0 {
        // A non-zero exit from osascript sending an AX event reliably indicates
        // that Accessibility permission was denied. Surface this to the caller.
        isRecording = false
        throw RecordingError.accessibilityDenied
    }
}
```

Note: `Process.run()` can throw if the executable is not found; that is re-thrown as a system error and caught by the generic `catch` in the call-site helpers, which will present an `NSAlert` with the localized description.

**Satisfies:** AC-SW-5

---

## 3. Popover Dismissal

The `orderOut` approach documented in `CLAUDE.md` is retained without change. The only addition is an explicit inline comment at both call sites.

**Rationale (preserved from CLAUDE.md):** Calling `popover.close()` directly while a recording is in progress breaks the double-click-to-reopen behavior: the popover enters an inconsistent internal state and will not reopen until the app is relaunched. Using `NSApp.keyWindow?.orderOut(nil)` with a 100ms delay dismisses the panel through the window layer rather than the popover API, which sidesteps the bug. The 100ms delay gives the button's visual feedback animation time to complete.

**Inline comment (identical at both Start and Stop call sites):**
```swift
// DISMISSAL: Use orderOut(nil) on the captured keyWindow rather than
// popover.close(). Calling close() while recording is active breaks the
// double-click-to-reopen behavior (popover enters an inconsistent state).
// The 100ms delay allows the button animation to complete first.
// See CLAUDE.md "Gotchas" for full explanation.
DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { panel?.orderOut(nil) }
```

This one `DispatchQueue.main.asyncAfter` call is intentionally retained. It is the documented dismissal mechanism and is not business logic. All other `DispatchQueue` usage is removed.

**Satisfies:** AC-SW-3 (no business-logic DispatchQueue calls remain), AC-SW-8

---

## 4. Error Surface

### 4.1 NSAlert presentation

Both error cases surface to the user via `NSAlert`. The alert is presented from the `MacRecordWidgetApp` helper method:

```swift
@MainActor
private func presentAlert(for error: Error) {
    let alert = NSAlert()
    alert.alertStyle = .critical
    switch error as? RecordingError {
    case .accessibilityDenied:
        alert.messageText = "Accessibility Permission Required"
        alert.informativeText = "MacRecordWidget needs Accessibility permission to make Photo Booth full-screen. Open System Settings > Privacy & Security > Accessibility and enable MacRecordWidget."
    case .shortcutLaunchFailed(let reason):
        alert.messageText = "Could Not Start Recording"
        alert.informativeText = "The recording shortcut could not be launched. Make sure a Shortcut named \"Start\" (or \"Stop\") exists in the Shortcuts app. Detail: \(reason)"
    case nil:
        alert.messageText = "Recording Error"
        alert.informativeText = error.localizedDescription
    }
    alert.addButton(withTitle: "OK")
    alert.runModal()
}
```

### 4.2 Error alert copy

| Error case | messageText | informativeText |
|---|---|---|
| `accessibilityDenied` | Accessibility Permission Required | MacRecordWidget needs Accessibility permission to make Photo Booth full-screen. Open System Settings > Privacy & Security > Accessibility and enable MacRecordWidget. |
| `shortcutLaunchFailed` | Could Not Start Recording | The recording shortcut could not be launched. Make sure a Shortcut named "Start" (or "Stop") exists in the Shortcuts app. Detail: [reason] |

### 4.3 State guarantee on error

When either error is thrown from `startRecording()`:
- `isInFlight` is reset to `false` via `defer` before the `catch` block in the view runs
- `isRecording` is never set to `true` (the assignment only occurs after a successful `open`)
- The Start button re-enables immediately because both `isRecording == false` and `isInFlight == false`

When `accessibilityDenied` is thrown from inside `launchPhotoBooth()`, which is called after `isRecording = true`:
- `launchPhotoBooth()` sets `isRecording = false` before throwing (explicit reset)
- The view catches the error and presents the alert
- The UI returns to idle state

**Satisfies:** AC-SW-4, AC-SW-5

---

## 5. Deployment Target

`MACOSX_DEPLOYMENT_TARGET` will be set to `14.0` in `MacRecordWidget.xcodeproj/project.pbxproj`.

The setting appears twice in `project.pbxproj` -- once under the `Debug` build configuration and once under `Release`. Both must be updated. If only one is changed, the Release build will still target macOS 13 and the `@Observable` macro will cause a linker error at archive time.

```
MACOSX_DEPLOYMENT_TARGET = 14.0;   /* appears in both Debug and Release sections */
```

**File:** `MacRecordWidget.xcodeproj/project.pbxproj`

No CI configuration change is required for this repo. The existing GitHub Actions workflow uses a macOS runner; if the runner is `macos-13`, it must be bumped to `macos-14` or `macos-latest`. This is a one-line change in the workflow YAML.

**Satisfies:** AC-SW-2

---

## 6. AC Coverage Table

| AC | Design decision that satisfies it |
|----|----------------------------------|
| AC-UI-1 | Stop button: `.tint(.red)` on `.bordered` style; adapts to light/dark mode and any accent color (Section 1.1) |
| AC-UI-2 | Start button: `.tint(.accentColor)` on `.bordered` style (Section 1.2) |
| AC-UI-3 | `.bordered` button style renders at native macOS control height; `.frame(maxWidth: .infinity)` provides full-width click target; pointer-driven UI does not require 44pt iOS targets (Section 1.3) |
| AC-UI-4 | Confirmed: no hardcoded `.system(size: N)` exists in current source; default `.body` font is correct; no change required (Section 1.4) |
| AC-UI-5 | Icon logic unchanged; four-state `mic`/`mic.fill`/`video`/`video.fill` + green tint when recording is correct (Section 1.5) |
| AC-UI-6 | Outer padding bumped to 16pt; frame width to 200pt; inner button spacing 8pt (Section 1.6) |
| AC-SW-1 | `RecordingManager` gets `@Observable` macro; `ObservableObject` and `@Published` removed; call site uses `@State` (Section 2.1) |
| AC-SW-2 | `MACOSX_DEPLOYMENT_TARGET = 14.0` in both Debug and Release in `project.pbxproj`; GitHub Actions runner bumped to `macos-14` (Section 5) |
| AC-SW-3 | All `DispatchQueue.global()` replaced with `Task { }`; `Thread.sleep` replaced with `try await Task.sleep`; one `DispatchQueue.main.asyncAfter` retained exclusively for the documented `orderOut` dismissal (Section 3) |
| AC-SW-4 | `RecordingError.shortcutLaunchFailed(reason:)` thrown when `NSWorkspace.open` returns false; caught by view helpers; `NSAlert` shown (Sections 2.3, 4.2) |
| AC-SW-5 | `RecordingError.accessibilityDenied` thrown when `osascript` exits non-zero; `isRecording` set back to `false` before throw; `NSAlert` shown with Accessibility instructions (Sections 2.6, 4.2) |
| AC-SW-6 | `isInFlight: Bool` guard in both `startRecording()` and `stopRecording()`; buttons also `.disabled` when `isInFlight == true`; two-layer protection (Sections 2.4, 1.2, 1.1) |
| AC-SW-7 | `isRecording = true` placed after `guard opened` check; never set before `NSWorkspace.open` returns success (Section 2.5) |
| AC-SW-8 | `orderOut` approach retained; four-line inline comment added at both dismissal sites explaining why `popover.close()` is not used and why the 100ms delay exists (Section 3) |
