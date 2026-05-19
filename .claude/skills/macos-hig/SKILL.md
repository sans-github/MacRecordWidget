---
name: macos-hig
description: macOS Human Interface Guidelines -- control vocabulary, spacing, semantic colors, window behavior, accessibility, and platform conventions. Use when designing or reviewing macOS app UI.
---

# macOS Human Interface Guidelines

## Platform at a glance

| Concern | macOS standard |
|---|---|
| UI framework | SwiftUI (primary), AppKit (interop only) |
| Type system | SF Pro (Text for body, Display for large headings) |
| Icon system | SF Symbols 5+ |
| Grid | 4pt base unit |
| Window chrome | Native title bar; avoid custom chrome unless strictly necessary |
| Menu | Every major action must be reachable from the menu bar |
| Keyboard | Keyboard-navigable interfaces by default; shortcuts for frequent actions |

---

## Window types

| Type | When to use | SwiftUI scene |
|---|---|---|
| Document window | Per-document, resizable | `DocumentGroup` |
| App window | Single-instance main UI | `WindowGroup` |
| Settings | Preferences/settings, fixed width | `Settings` |
| Panel | Floating utility (inspector, colors) | `Window` with `.windowStyle(.plain)` + `NSPanel` if needed |
| Menu Bar Extra | Lightweight always-visible access | `MenuBarExtra` |

Windows open from the menu bar or via system commands. Do not use full-screen takeovers for secondary tasks.

---

## Containers and layout controls

| Component | SwiftUI | Purpose |
|---|---|---|
| Sidebar | `NavigationSplitView` (leading column) | Primary navigation list |
| Inspector | `NavigationSplitView` (trailing column) or `Inspector` | Context-sensitive detail panel |
| Toolbar | `toolbar {}` modifier | Primary actions for the window |
| Tab view | `TabView` with `.tabViewStyle(.automatic)` | Top-level mode switching |
| Split view | `NavigationSplitView` / `HSplitView` | Persistent side-by-side panes |
| Disclosure group | `DisclosureGroup` | Collapsible sections in a list or form |
| Popover | `popover(isPresented:)` | Contextual transient controls |
| Sheet | `sheet(isPresented:)` | Modal task requiring completion before returning |
| Alert | `alert(_:isPresented:)` | Destructive confirmation or critical message |
| Panel (floating) | `Window` + `NSPanel` interop | Non-modal floating tool window |

---

## Input controls

| Control | SwiftUI | Notes |
|---|---|---|
| Push button | `Button` | Default action: `.buttonStyle(.borderedProminent)` |
| Borderless button | `Button(.borderless)` | Toolbar actions, inline icon buttons |
| Segmented control | `Picker` with `.pickerStyle(.segmented)` | Mutually exclusive mode selection |
| Checkbox | `Toggle` | Multi-select boolean |
| Radio group | `Picker` with `.pickerStyle(.radioGroup)` | Single-select from a small fixed set |
| Text field | `TextField` | Single-line input |
| Secure field | `SecureField` | Password |
| Search field | `SearchField` | Filtering lists |
| Combo box | `ComboBox` (AppKit) / custom | Editable + dropdown |
| Stepper | `Stepper` | Numeric increment |
| Slider | `Slider` | Continuous range |
| Date picker | `DatePicker` | Date/time input |
| Color well | `ColorPicker` | Color selection |
| Progress | `ProgressView` | Determinate or indeterminate |
| List | `List` | Scrollable row collection; use `Table` for multi-column |
| Table | `Table` | Multi-column sortable data |
| Menu | `Menu` | Dropdown list of actions |
| Context menu | `.contextMenu {}` | Right-click actions |

---

## Spacing and sizing

All spacing is on the 4pt grid. Use these named values in specs:

| Token | Value | Use |
|---|---|---|
| `spacing-1` | 4pt | Tight inline gaps |
| `spacing-2` | 8pt | Related elements |
| `spacing-3` | 12pt | Section padding |
| `spacing-4` | 16pt | Standard padding |
| `spacing-5` | 20pt | Comfortable section gaps |
| `spacing-6` | 24pt | Card/panel padding |
| `spacing-8` | 32pt | Major section separation |

Minimum touch target on macOS: **16x16pt** for icons, **22pt height** for controls (buttons, text fields).

---

## Typography (SF Pro)

| Role | Style | Size | Weight |
|---|---|---|---|
| Large title | SF Pro Display | 26pt | Bold |
| Title 1 | SF Pro Display | 22pt | Bold |
| Title 2 | SF Pro Text | 17pt | Bold |
| Title 3 | SF Pro Text | 15pt | Semibold |
| Headline | SF Pro Text | 13pt | Semibold |
| Body | SF Pro Text | 13pt | Regular |
| Callout | SF Pro Text | 12pt | Regular |
| Subheadline | SF Pro Text | 11pt | Regular |
| Footnote | SF Pro Text | 10pt | Regular |
| Caption | SF Pro Text | 10pt | Regular |

In SwiftUI: `.font(.title)`, `.font(.body)`, `.font(.caption)` etc. Never hardcode point sizes.

---

## Semantic color roles

Use semantic colors exclusively. Never use hardcoded hex values -- they break dark mode and high contrast.

| Token | SwiftUI | AppKit | Use |
|---|---|---|---|
| Primary label | `.primary` | `NSColor.labelColor` | Main text |
| Secondary label | `.secondary` | `NSColor.secondaryLabelColor` | Supporting text |
| Tertiary label | -- | `NSColor.tertiaryLabelColor` | Disabled text, placeholders |
| Accent | `.accentColor` | `NSColor.controlAccentColor` | Interactive highlights, selection |
| Background | `.background` | `NSColor.windowBackgroundColor` | Window fill |
| Secondary background | `Color(nsColor: .controlBackgroundColor)` | `NSColor.controlBackgroundColor` | Sidebars, panels |
| Separator | `Divider()` | `NSColor.separatorColor` | Rule lines |
| Selected content | -- | `NSColor.selectedContentBackgroundColor` | Focused list selection |
| Unemphasized selection | -- | `NSColor.unemphasizedSelectedContentBackgroundColor` | Unfocused list selection |

---

## Dark mode

Every design must cover both light and dark appearances. Rules:

- Never use fixed-color assets without a corresponding dark-mode asset in the asset catalog
- Test at system level: flip appearance in System Settings and verify no hard-coded colors surface
- Use `.colorScheme(.light)` and `.colorScheme(.dark)` previews in SwiftUI, never rely on simulator only
- Background layering: `windowBackgroundColor` (base) > `controlBackgroundColor` (sidebar) > `underPageBackgroundColor` (behind scroll area)

---

## Accessibility

Minimum compliance for every screen:

- VoiceOver: every interactive element has a meaningful `.accessibilityLabel`
- Keyboard navigation: all actions reachable without a mouse; `Tab` moves focus; `Space`/`Return` activates
- Reduce Motion: wrap animations in `withAnimation` and check `@Environment(\.accessibilityReduceMotion)`
- Increase Contrast: use semantic colors (they respond automatically); do not rely on low-contrast separator-only visual distinctions
- Dynamic Type: text scales with accessibility font sizes; never clip or truncate at system large sizes

---

## Menu bar conventions

Every Mac app must have a complete menu bar. Required menus:

| Menu | Required items |
|---|---|
| App menu | About, Settings (⌘,), Hide, Quit (⌘Q) |
| File | New (⌘N), Open (⌘O), Close (⌘W), Save (⌘S) -- as applicable |
| Edit | Undo (⌘Z), Redo (⇧⌘Z), Cut, Copy, Paste, Select All |
| View | Toggle sidebar, toolbar customization -- as applicable |
| Window | Minimize, Zoom, Bring All to Front |
| Help | App help, support link |

Custom menus go between View and Window. Do not place primary actions only in a toolbar without a menu bar equivalent.

---

## Keyboard shortcuts

| Category | Convention |
|---|---|
| Primary actions | ⌘ + letter (⌘N, ⌘S, ⌘O) |
| Destructive actions | No shortcut unless confirmed (delete with backspace only in selection context) |
| Secondary actions | ⇧⌘ or ⌥⌘ combinations |
| Avoid | Overriding system-reserved shortcuts (⌘Space, ⌘Tab, ⌘H, ⌘M, ⌘Q) |
| Custom shortcuts | User-configurable preferred; use `commands {}` modifier in SwiftUI |

---

## Anti-patterns (never do these on macOS)

- Bottom sheets (mobile pattern; use popover or panel instead)
- Full-screen modal dialogs for non-critical tasks (use sheet or alert)
- Custom window chrome that hides the title bar without strong justification
- Floating toolbar buttons with no keyboard equivalent
- Fixed-size windows that cannot be resized
- Card-based scroll feeds (mobile-origin; use Table or List with selection)
- Hamburger or slide-out navigation menus (use NavigationSplitView sidebar)
- Toast notifications for critical feedback (use alert or inline error state)
