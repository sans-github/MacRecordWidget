---
name: macos-design-system
description: The house visual system for San's macOS apps (semantic capsule controls, two-hue palette, live ember, one scale enum for every dimension, contrast and motion rules). Load when producing mocks or building SwiftUI controls for a macOS app, alongside macos-hig.
---

# macOS Design System

Extracted from MacRecordWidget, the reference app. `reference.swift` in this folder is the working code it came from; read it before building controls, and use it to answer anything this page leaves open.

## Palette: hue says state, not subsystem

Two hues, nothing else lit:

| Token | Hex | Meaning |
|---|---|---|
| `capture` | `#FF383C` | Something is live and recording the user (audio, video, screen). Only that. |
| `control` | `#007AFF` | Every other lit control: toggles that are on, selected sizes, a menu's chevron well, quit. |
| `glyphOn` | white | The glyph on any lit capsule. |

- Do not add a third hue for a subsystem (MacRecordWidget dropped a camera green because it read as a third, unexplained state and failed contrast).
- One hex per token covers both light and dark appearance.
- The user's accent colour is not honoured in a control row: blue there means "lit", not "your accent".
- Contrast must clear WCAG 1.4.11 3:1 for an icon: white on `#FF383C` is 3.57:1, white on `#007AFF` is 4.02:1. Compute it for any new hue; do not eyeball it.

## Controls: semantic capsules

| State | Shape | Fill | Edge | Glyph |
|---|---|---|---|---|
| Off | rounded rect, `scale.cornerRadius` | `controlBackgroundColor` | 1pt `separatorColor` | `labelColor` |
| On | fully round capsule | hue | none (the fill is the edge) | white |

- Height is pinned to `scale.controlHeight` for every control in a row, including text boxes like a timer. It is the only thing holding the row together while silhouettes change.
- Width must not depend on state: horizontal padding is one number for on and off, or lighting a control shoves its neighbours.
- A toggle keeps its glyph and flips its fill. Swap glyphs only when the glyph itself is the state (e.g. `pin.fill` / `pin.slash`).
- A control that is always "on" by meaning (quit) is drawn lit, never in the off style.
- `.focusEffectDisabled()` on the row; no focus rings.
- Prefer `Toggle` with a custom `ToggleStyle` over a segmented `Picker`: `NSSegmentedControl` ignores SwiftUI `.font()` and will not scale.
- A camera or device choice is a `Menu` of `Button`s, not a `Picker`, when the true selection updates asynchronously (a two-way binding writes the stale value back).

## Live state: the ember

While something is actually capturing, its capsule wears an animated gradient in the capture red with a breathing glow (3.4s period), driven by `TimelineView(.animation)` rather than `repeatForever`, so there is nothing to cancel when it stops. A second, non-hue signal (a small blinking amber dot, 1.6s, deliberately not a near multiple of the ember period) marks the same state for users who cannot rely on red.

Both collapse to static under **Reduce Motion** (`accessibilityReduceMotion`) and the ember also under **Increase Contrast** (`colorSchemeContrast`).

## Scale: one enum owns every dimension

If the app offers sizes, one `enum` (`PanelScale` in the reference) owns glyph size, glyph font, control font, label font, control height, row spacing, padding and corner radius. Never scatter the numbers across views; the row and the content have to scale together.

- Three fonts, not interchangeable: `glyphFont` (SF Symbols), `controlFont` (text inside AppKit-backed controls; `ControlSize` does not carry text size), `scaleLabelFont` (single letters, a point smaller at the small scale because a letter fills its box more solidly).
- Keep the box-to-text ratio around 1.3 (glyph 17 / text 13 at large).
- 22pt is the floor for `controlHeight` (HIG minimum click target).
- Optical over arithmetic padding: a gap against hard content can be a point smaller than a gap against window chrome.

## Mocks

HTML mocks use exactly these tokens and states. Show every control in off, on, and live (ember) state, in light and dark, so the reviewer sees the whole state space before any Swift is written.
