---
name: ui-simplicity
description: UI simplicity discipline -- decompose before designing, eliminate duplication, enforce hierarchy, evaluate against a rubric before delivery. Use when producing any mock or UI artifact.
---

# UI Simplicity

A discipline for producing interfaces that are focused, scannable, and free of clutter. The failure mode this skill guards against: UIs that pack in random, duplicated, or non-sensical elements instead of communicating clearly and directly.

## When to use

Load this skill before producing any mock, screen, or UI artifact. Run the self-evaluation rubric before declaring any design complete.

## Step 1: Decompose before you design

List every distinct piece of information and every action the screen must support -- before writing a single line of markup. This is not optional.

For each item on the list, answer:
- **What decision does this help the user make, or what task does it enable?**
- **Where else on this screen or flow does this information or action appear?**

If you cannot answer the first question, cut the item. If it appears more than once, cut all but the canonical instance. Only what survives this filter belongs in the design.

> Source: Anthropic multi-agent principle of decompose-before-acting. Vague subagent scope causes duplicated work; vague UI scope causes duplicated, cluttered controls.

## Step 2: Core rules

**One place per concept.** Every piece of information and every action lives in exactly one place. If a label appears twice, the second one is wrong. If the same action exists in two locations, consolidate to the more discoverable one. Duplication signals unclear thinking about ownership, not thoroughness.

> Source: Hick's Law (fewer choices, faster decisions), Nielsen Heuristic #4 (consistency and standards), Anthropic deduplication principle.

**Exactly one primary action per screen.** Pick it. Make it visually dominant. Everything else is subordinate -- visually and spatially. If you cannot name the primary action in three words, the screen is under-designed.

> Source: Von Restorff Effect (the distinct item is remembered), Nielsen Heuristic #8 (aesthetic and minimalist design), Apple Clarity principle.

**Layout follows task flow, not element type.** Place elements in the order the user needs them to complete their goal. Do not group all inputs together just because they are inputs, or all buttons together just because they are buttons. The task sequence is the layout sequence.

> Source: Anthropic end-state focus principle (validate user achieved outcome, not each intermediate step), Nielsen Heuristic #2 (match system to mental model).

**Elements earn their place.** For every decorative element, icon, divider, label, or secondary action: if removing it does not break the user's ability to understand or complete the task, remove it. Decoration is not neutral -- it competes for attention with content that matters.

> Source: Occam's Razor (simplest solution that accomplishes the goal), Apple Deference principle (content takes priority, minimal decoration), Material Design (hierarchy through space and type, not decoration), Nielsen Heuristic #8.

**Group by proximity and similarity.** Related elements sit near each other and look alike. Unrelated elements have visible space between them. Do not rely on labels to explain grouping that spatial layout should communicate visually.

> Source: Law of Proximity, Law of Similarity, Law of Common Region, Chunking -- all agree that spatial relationships carry meaning users read automatically.

**Reduce choices, reduce fatigue.** Hick's Law: decision time grows with the number of options. For any decision point in the UI, expose only the options that apply to the user's current context. Hide advanced options behind a disclosed control. Never present more than seven items in a flat list without grouping or filtering.

> Source: Hick's Law, Miller's Law, Nielsen Heuristic #7 (flexibility: simple default path for new users, power options hidden).

**Speak the user's language.** Every label, heading, and status message uses the vocabulary the user already knows, not the system's internal terminology. If you are reaching for a technical term, stop and find the plain-language equivalent.

> Source: Nielsen Heuristic #2 (match between system and mental model), Jakob's Law (users expect designs to work like interfaces they already know).

**Show, don't make them remember.** Visible options are always preferable to remembered commands. Primary interactions must be discoverable by scanning the screen. Nothing a user needs regularly should require hovering, right-clicking, or recalling a shortcut.

> Source: Nielsen Heuristic #6 (recognition over recall), Nielsen Heuristic #1 (visibility of system status).

**Communicate hierarchy through space and type, not decoration.** Use font size, weight, whitespace, and color value (light vs. dark) to signal what matters most. Do not reach for borders, backgrounds, icons, or badges to create hierarchy that spacing and typography should carry.

> Source: Material Design philosophy, Apple Depth principle (hierarchy through visual layers, not clutter), Serial Position Effect (users remember first and last items -- put primary information there).

**Absorb complexity; do not pass it to the user.** Tesler's Law: complexity cannot be eliminated, only moved. The interface must absorb as much of it as possible. When a workflow is inherently complex, simplify the user's experience through smart defaults, progressive disclosure, and pre-filling -- not by showing the user all the complexity at once.

> Source: Tesler's Law (Law of Conservation of Complexity).

## Self-evaluation rubric

Run this before declaring any design complete. A design that fails any item must be revised before handoff.

| Check | Pass condition |
|---|---|
| Decomposition done | Every element on screen appears in the pre-design list with a justified purpose |
| No duplication | No information or action appears in more than one place |
| Primary action named | Can state the primary action in three words or fewer |
| Primary action dominant | Primary action is visually distinct from all secondary actions |
| Layout follows task | Element order matches the sequence in which the user needs them |
| Decoration audit passed | Can justify every non-content visual element; removing it would harm comprehension |
| Grouping is spatial | Related elements are spatially close; unrelated elements have visible separation |
| Choice count bounded | No flat list exceeds seven items without grouping; advanced options are disclosed |
| Language is plain | Zero internal or technical terms visible to the user |
| Primary interactions visible | No required action is hidden behind hover, right-click, or recalled shortcut |
| Hierarchy uses space/type | No decorative border, badge, or icon is doing work that whitespace or font weight should do |

If you cannot mark every row as passed, do not hand off. Fix first.
