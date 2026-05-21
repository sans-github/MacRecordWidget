Status: Approved — Human
Approved: 2026-05-21

# Kickoff Plan: 20260521-popover-button-layout

## 1. What I understood

This feature makes three targeted, surgical UI changes to the existing MacRecordWidget SwiftUI popover. The flickering recording-status dot above the Start button is removed entirely. The Start and Stop buttons move from a vertical stack to a side-by-side horizontal row, shifting up to fill the space freed by the removed dot. Finally, Stop's behavior is narrowed: it fires the Stop shortcut only and leaves Photo Booth running, so the user can immediately start a new session from Photo Booth without returning to the menu bar. The Quit button is untouched. No new infrastructure, no API, no DB, no tests required. The entire change is confined to `MacRecordWidgetApp.swift` and `RecordingManager.swift`.

**Folder structure check:** All required folders are present.

- `projects/20260521-popover-button-layout/workflow/feature-setup.md` -- present
- `projects/20260521-popover-button-layout/product-specs/prd.md` -- present
- `projects/20260521-popover-button-layout/generated-docs/design/` -- present

**Input quality check:** The PRD contains only a requirements frontmatter block. This is the expected state after `/feature-init`. Stage 1 will produce the full PRD. No unfilled placeholders, no contradictions, no broken stage dependencies.

**Software stack:** The existing stack is Swift 5.10 + SwiftUI (macOS layer), matching `tech-config.md`. No new technology is being introduced. Arch approval is not required.

**Stack fit assessment:** The scope is micro (two Swift files, layout and one behavior change). The existing stack is exactly right. No mismatch.

**Risks and unknowns:**

- The flickering dot is a View element that may be conditionally rendered from state. Removing it is straightforward, but the exact identifier needs confirmation in code before editing to avoid leaving dead state.
- Moving buttons to a horizontal row changes the HStack/VStack nesting. If padding or fixed frame sizes are hardcoded, the layout may not behave as expected at different system font sizes. Worth a quick review.
- Photo Booth is currently quit when Stop fires (or left open if started without video mode). The PRD says Stop should now leave Photo Booth running unconditionally. Need to confirm: does the current `stopRecording()` close Photo Booth, or does it only fire the Stop shortcut? If Photo Booth is not currently closed by `stopRecording()`, this may already be the behavior and the change is a no-op on that front.

**Out of scope:**

- Any change to the Start button behavior
- Any change to the Quit button
- New recording indicators or status UI (dot is removed, not replaced)
- Tests (Stage 5 is `[-]`)
- Infrastructure (deployment target is local)

---

## 2. Open questions

1. ✅ The PRD says Stop fires the Stop shortcut and leaves Photo Booth running. Does the current `stopRecording()` in `RecordingManager.swift` close Photo Booth at all, or has it never done so?

   **Resolution:** The Quit (power) button closes everything -- `stopRecording()` does NOT currently close Photo Booth. The behavior change (Stop leaving Photo Booth running) IS real work that needs to be implemented.

2. ✅ The PRD says Stage 2 (Design / mocks) is active. Are mocks actually needed for two-file layout tweaks, or can we skip directly to implementation?

   **Resolution:** Mocks are needed. The macOS Designer will produce HTML mocks.

---

## 3. Next step

Once approved, PM reviews the PRD requirements with you and produces the full PRD for `projects/20260521-popover-button-layout/product-specs/prd.md`.
