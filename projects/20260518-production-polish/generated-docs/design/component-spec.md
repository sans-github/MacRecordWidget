# Component Spec: Production Polish Popover

This document is the authoritative handoff reference for the Swift Engineer. Every interactive and visual element in the popover is specified with its SwiftUI control type, modifier chain, semantic color tokens, typography, sizing, and spacing. No design judgment calls are required during implementation.

---

## 1. Popover Container

| Property | Value |
|----------|-------|
| SwiftUI construct | `VStack(alignment: .leading, spacing: 8)` |
| Outer padding | `.padding(16)` on all sides |
| Frame width | `.frame(width: 200)` |
| Background | Native `MenuBarExtra(.window)` panel background (`NSColor.windowBackgroundColor`); no override needed |

The `VStack` contains three children in order: the HStack (toggle + quit button), a `Divider`, and the inner button VStack. The `Divider` uses its native semantic color (`NSColor.separatorColor`) with no modifier overrides.

Inner button `VStack` spacing: `VStack(spacing: 8)`.

---

## 2. Menu Bar Icon

| State | SF Symbol | Tint |
|-------|-----------|------|
| Audio, idle | `mic` | `.primary` (label color; adapts to light/dark) |
| Audio, recording | `mic.fill` | `.green` (system green; adapts to light/dark) |
| Video, idle | `video` | `.primary` |
| Video, recording | `video.fill` | `.green` |

SwiftUI expression:

```swift
Image(systemName: icon)
    .symbolRenderingMode(.hierarchical)
    .foregroundStyle(recordingManager.isRecording ? .green : .primary)
```

`icon` is derived from `recordingManager.videoEnabled` and `recordingManager.isRecording` as four-way logic (see swift-detailed-design.md Section 1.5). No changes to this logic.

---

## 3. Video Mode Toggle

| Property | Value |
|----------|-------|
| SwiftUI control | `Toggle` |
| Binding | `$recordingManager.videoEnabled` |
| Label text | "Include Video" |
| Font | `.font(.body)` (13pt Regular SF Pro Text; system default; no explicit modifier needed unless overriding) |
| Color | `.primary` (label color) |
| Placement | Leading item in the top `HStack`, before the quit button |
| Toggle style | Default macOS checkbox style (`.toggleStyle(.checkbox)` is the platform default inside a `MenuBarExtra` panel) |
| Sizing | Native macOS control height (approximately 16pt checkbox + label; do not set a fixed frame height) |
| Accessibility label | `"Include video in recording"` via `.accessibilityLabel("Include video in recording")` |

---

## 4. Start Button

| Property | Value |
|----------|-------|
| SwiftUI control | `Button` |
| Action | `Task { await startAndDismiss() }` |
| Label | `Label("Start", systemImage: "mic.fill")` with `.frame(maxWidth: .infinity)` on the label |
| Button style | `.buttonStyle(.bordered)` |
| Tint | `.tint(.accentColor)` |
| Font | Inherits `.body` from container; no override |
| Height | Native macOS bordered control height (approximately 22pt intrinsic); do not set a fixed height |
| Width | Full container width via `.frame(maxWidth: .infinity)` on the label |
| Disabled state | `.disabled(recordingManager.isRecording || recordingManager.isInFlight)` |
| Accessibility label | `"Start recording"` via `.accessibilityLabel("Start recording")` |

The `.bordered` style on macOS renders an outlined button with the tint color applied to the label and border. `.accentColor` resolves to `NSColor.controlAccentColor`, which follows the user's chosen accent color in System Settings. This satisfies AC-UI-2.

---

## 5. Stop Button

| Property | Value |
|----------|-------|
| SwiftUI control | `Button` |
| Action | `Task { await stopAndDismiss() }` |
| Label | `Label("Stop", systemImage: "stop.fill")` with `.frame(maxWidth: .infinity)` on the label |
| Button style | `.buttonStyle(.bordered)` |
| Tint | `.tint(.red)` |
| Font | Inherits `.body` from container; no override |
| Height | Native macOS bordered control height (approximately 22pt intrinsic); do not set a fixed height |
| Width | Full container width via `.frame(maxWidth: .infinity)` on the label |
| Disabled state | `.disabled(!recordingManager.isRecording || recordingManager.isInFlight)` |
| Accessibility label | `"Stop recording"` via `.accessibilityLabel("Stop recording")` |

`.tint(.red)` on a `.bordered` button uses the system `.red` color role, which is semantically correct for destructive actions and adapts correctly to light mode, dark mode, and all accent color settings. There is no SwiftUI `ButtonRole.destructive` on macOS for `.bordered` style -- `.tint(.red)` is the correct HIG-compliant approach. This satisfies AC-UI-1.

Note: both Start and Stop share the same `isInFlight` gate. When either button's action is running, both buttons are disabled simultaneously.

---

## 6. Quit Button

| Property | Value |
|----------|-------|
| SwiftUI control | `Button` |
| Action | `NSApplication.shared.terminate(nil)` |
| Label | `Image(systemName: "power")` |
| Button style | `.buttonStyle(.plain)` (borderless; consistent with existing implementation) |
| Tint | None (inherits `.secondary` label color via `.foregroundStyle(.secondary)` on the image) |
| Font | Not applicable (SF Symbol image) |
| Symbol size | `.imageScale(.medium)` or default; do not force a fixed frame |
| Placement | Trailing item in the top `HStack`, after the toggle |
| Accessibility label | `"Quit MacRecordWidget"` via `.accessibilityLabel("Quit MacRecordWidget")` |

The `HStack` containing the toggle and quit button uses `Spacer()` between them to push the quit button to the trailing edge.

---

## 7. Recording Status Indicator (Pulsing Dot)

The approved mocks include a pulsing dot to provide visual feedback while `isInFlight == true`. This element is active only during the in-flight window (after button tap, before dismissal).

| Property | Value |
|----------|-------|
| SwiftUI construct | `Circle()` |
| Size | `.frame(width: 8, height: 8)` |
| Fill color | `.fill(.accentColor)` when start is in flight; `.fill(.red)` when stop is in flight |
| Visibility | `.opacity(recordingManager.isInFlight ? 1 : 0)` |
| Animation | `withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true))` applied to `.scaleEffect` toggling between `0.7` and `1.0` |
| Reduce Motion | Wrap scale animation in `if !accessibilityReduceMotion` check; when Reduce Motion is on, omit the scale animation and use only the opacity change |
| Placement | Inline, trailing the active button label, or as a standalone indicator below the button stack; placement is at Swift Engineer's discretion as long as it is visible during in-flight state |
| Accessibility | `.accessibilityHidden(true)` (the button's disabled state already communicates the in-flight condition to VoiceOver) |

Reduce Motion environment variable: `@Environment(\.accessibilityReduceMotion) var accessibilityReduceMotion`

---

## 8. Error State

Per `swift-detailed-design.md` Section 4.1, errors surface via `NSAlert`. There is no inline error banner in the popover.

| Property | Value |
|----------|-------|
| Presentation method | `NSAlert.runModal()` called from `presentAlert(for:)` on the main actor |
| Alert style | `.critical` |
| Trigger | `catch` block in `startAndDismiss()` or `stopAndDismiss()` |
| Post-alert state | Popover returns to idle state; Start button re-enables (both `isRecording == false` and `isInFlight == false`); no persistent error indicator in the popover |

The two error cases and their copy are specified in `swift-detailed-design.md` Section 4.2. The designer does not require any additional popover-level error UI. The `NSAlert` modal is the complete and sole error surface.

---

## Dark Mode Behavior

All tokens used in this spec adapt automatically to light and dark mode without any `.environment(\.colorScheme)` override.

| Token | Adapts automatically | Notes |
|-------|---------------------|-------|
| `.accentColor` | Yes | Follows `NSColor.controlAccentColor`; respects user accent color choice |
| `.red` (via `.tint(.red)`) | Yes | Maps to `NSColor.systemRed`; macOS system red adjusts saturation for dark mode |
| `.green` (via `.foregroundStyle(.green)`) | Yes | Maps to `NSColor.systemGreen`; adjusts for dark mode |
| `.primary` | Yes | Maps to `NSColor.labelColor`; near-black in light, near-white in dark |
| `.secondary` | Yes | Maps to `NSColor.secondaryLabelColor`; adapts to both appearances |
| `Divider()` | Yes | Uses `NSColor.separatorColor` internally |
| Panel background | Yes | `NSColor.windowBackgroundColor` used by `MenuBarExtra(.window)`; no override needed |

No explicit `.colorScheme` environment overrides are required anywhere in this view tree. All semantic tokens resolve correctly at the system level.

---

## Spacing Summary

| Location | Value |
|----------|-------|
| Outer `VStack` spacing | 8pt |
| Outer padding (all sides) | 16pt |
| Inner button `VStack` spacing | 8pt |
| Popover frame width | 200pt |
| Pulsing dot size | 8x8pt |

All values are on the 4pt grid.

---

## Accessibility Identifier Map

For future XCUITest use. Assign these identifiers on the corresponding elements:

| Element | `.accessibilityIdentifier` |
|---------|--------------------------|
| Video mode toggle | `"videoModeToggle"` |
| Start button | `"startButton"` |
| Stop button | `"stopButton"` |
| Quit button | `"quitButton"` |

Apply via `.accessibilityIdentifier("...")` modifier on each control.
