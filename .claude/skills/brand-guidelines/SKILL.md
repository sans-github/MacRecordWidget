---
name: brand-guidelines
description: Brand guidelines for the product -- color palette, typography, spacing, component states, and voice. Loaded by the Designer agent when producing mocks to ensure visual consistency across features.
---

# Brand Guidelines — Agent Stack

**Identity:** Off-White + Deep Teal. Quiet authority, slightly Nordic. Near-achromatic base with a single deep teal accent.
**Preview:** `.claude/skills/brand-guidelines/previews/default-brand.html`

---

## Color palette

All tokens defined for both light and dark mode. Use token names in mocks and CSS -- never raw hex values.

### Light mode

| Token | Hex | Usage |
|---|---|---|
| `color-primary` | `#2A6872` | Primary actions, links, active states |
| `color-primary-hover` | `#1A4E58` | Hover state for primary |
| `color-primary-subtle` | `#E4EFF0` | Backgrounds, badges using primary color |
| `color-secondary` | `#4A7880` | Secondary actions |
| `color-neutral-900` | `#161E20` | Body text, headings |
| `color-neutral-600` | `#526870` | Secondary text, labels |
| `color-neutral-300` | `#B8CACF` | Borders, dividers |
| `color-neutral-100` | `#EAF0F2` | Subtle backgrounds |
| `color-neutral-0` | `#FFFFFF` | White / card backgrounds |
| `color-success` | `#2A6A52` | Success states, confirmations |
| `color-warning` | `#806030` | Warnings, caution states |
| `color-error` | `#783040` | Errors, destructive actions |
| `color-info` | `#2A4A78` | Informational states |
| `color-surface` | `#F5F8F9` | Page background |

### Dark mode

| Token | Hex | Usage |
|---|---|---|
| `color-primary` | `#4AA8B8` | Primary actions, links, active states |
| `color-primary-hover` | `#60C0D0` | Hover state for primary |
| `color-primary-subtle` | `#182830` | Backgrounds, badges using primary color |
| `color-secondary` | `#70A8B4` | Secondary actions |
| `color-neutral-900` | `#E8F0F2` | Body text, headings |
| `color-neutral-600` | `#7898A0` | Secondary text, labels |
| `color-neutral-300` | `#2E4850` | Borders, dividers |
| `color-neutral-100` | `#1C3038` | Subtle backgrounds |
| `color-neutral-0` | `#162028` | White / card backgrounds |
| `color-success` | `#50A880` | Success states, confirmations |
| `color-warning` | `#C8A050` | Warnings, caution states |
| `color-error` | `#C06070` | Errors, destructive actions |
| `color-info` | `#50A0C8` | Informational states |
| `color-surface` | `#111820` | Page background |

---

## Typography

| Token | Font family | Weight | Size | Line height | Usage |
|---|---|---|---|---|---|
| `text-display` | Plus Jakarta Sans | 700 | 44px | 1.1 | Hero headings |
| `text-h1` | Plus Jakarta Sans | 700 | 30px | 1.2 | Page titles |
| `text-h2` | Plus Jakarta Sans | 600 | 22px | 1.3 | Section headings |
| `text-h3` | Plus Jakarta Sans | 600 | 17px | 1.4 | Card headings, subsections |
| `text-body-lg` | Plus Jakarta Sans | 400 | 17px | 1.6 | Primary body text |
| `text-body` | Plus Jakarta Sans | 400 | 15px | 1.6 | Default body text |
| `text-body-sm` | Plus Jakarta Sans | 400 | 13px | 1.5 | Secondary body, captions |
| `text-label` | Plus Jakarta Sans | 600 | 12px | 1.4 | Form labels, tags (uppercase, +0.2px tracking) |
| `text-code` | JetBrains Mono | 400 | 13px | 1.6 | Code snippets |

Font stack: `'Plus Jakarta Sans', sans-serif` (primary), `'JetBrains Mono', monospace` (code)
Google Fonts import: `https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@300;400;500;600;700&family=JetBrains+Mono:wght@400;500`

---

## Spacing system

Base unit: `4px`

| Token | Value | Usage |
|---|---|---|
| `space-1` | 4px | Tight gaps (icon + label) |
| `space-2` | 8px | Inner padding (compact) |
| `space-3` | 12px | Inner padding (default) |
| `space-4` | 16px | Component gaps |
| `space-6` | 24px | Section gaps (small) |
| `space-8` | 32px | Section gaps (medium) |
| `space-12` | 48px | Layout gaps |
| `space-16` | 64px | Page sections |

---

## Shape and elevation

| Token | Value | Usage |
|---|---|---|
| `radius-sm` | 4px | Tags, badges |
| `radius-md` | 7px | Inputs, buttons, cards |
| `radius-lg` | 12px | Modals, sheets, large surfaces |
| `radius-full` | 9999px | Pills, avatars |
| `shadow-sm` | `0 1px 3px rgba(22,30,32,0.07)` | Subtle lift (dropdowns) |
| `shadow-md` | `0 4px 12px rgba(22,30,32,0.09)` | Cards, popovers |
| `shadow-lg` | `0 12px 32px rgba(22,30,32,0.13)` | Modals, dialogs |

Dark mode shadow: replace rgba with `rgba(0,0,0,0.30/0.36/0.46)` at the same offsets.

---

## Core component states

| State | Visual treatment |
|---|---|
| Default | Base token colors, no decoration |
| Hover | `color-primary-hover` for primary; `color-primary-subtle` background for secondary/ghost |
| Active / pressed | No translateY; shadow removed |
| Focus (keyboard) | `color-primary` outline, 2px, 2px offset |
| Disabled | `color-neutral-100` background, `color-neutral-300` text, no pointer events, no shadow |
| Loading | Skeleton or spinner using `color-neutral-300` |
| Error | `color-error` border + message below field in `color-error` |
| Success | `color-success` indicator or border-left accent |

---

## Button hierarchy

| Variant | When to use | Background | Text | Border |
|---|---|---|---|---|
| Primary | Main CTA, one per view | `color-primary` | white | none |
| Secondary | Supporting action | `color-neutral-0` | `color-primary` | 1.5px `color-primary` |
| Ghost | Low-emphasis action | transparent | `color-primary` | none |
| Destructive | Irreversible action | `color-error` | white | none |
| Disabled | Any unavailable action | `color-neutral-100` | `color-neutral-300` | none |

---

## Iconography

Icon library: Lucide or Heroicons (outline set)
Default size: 16px inline, 20px standalone
Color: inherits from text color unless specified

Rules:
- Never use icons without a text label or tooltip (accessibility)
- Use filled variants for active/selected state, outline for default

---

## Voice and tone

| Situation | Tone | Example |
|---|---|---|
| Empty state | Helpful, action-oriented | "No agents configured yet. Add your first agent to get started." |
| Error message | Clear, non-blaming | "Sync failed. Check your network connection and try again." |
| Success confirmation | Brief, positive | "Changes saved." / "Config applied." |
| Destructive confirmation | Direct, consequence-first | "Remove this agent? All associated plans and contracts will be permanently deleted. This cannot be undone." |
| Loading | Minimal | "Loading..." or no text if under 1s |

Writing rules:
- Sentence case for all UI text (not Title Case)
- No exclamation marks except onboarding
- Avoid technical jargon in user-facing copy

---

## What the Designer must do with this

Before producing any mock:
1. Use only tokens defined above -- no ad-hoc colors, sizes, or fonts
2. Include all component states in every mock (hover, disabled, error, loading)
3. If a new pattern is needed that isn't covered here, flag it explicitly -- do not invent ad-hoc styles silently
4. After completing mocks, note any token gaps discovered (patterns needed but not defined)
