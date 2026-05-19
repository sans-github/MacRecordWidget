Status: Approved — Human
Approved: 2026-05-18

# Kickoff Plan: Production Polish

## What I Understood

MacRecordWidget is a two-file macOS menu bar app (`MacRecordWidget/MacRecordWidgetApp.swift` and `MacRecordWidget/RecordingManager.swift`) that triggers Apple Shortcuts-based recording via a popover panel. This project is a focused polish pass with two parallel tracks: the macOS Designer audits and redesigns the popover UI against HIG guidelines, and the Swift Engineer refactors the source to production-grade Swift. No new functionality is introduced. The workflow goes: PM finalizes requirements, Designer produces HIG-compliant mocks, EM plans the implementation, Swift Engineer executes the refactor per those mocks and plan, QA validates, then the master baseline and docs are updated.

**Folder structure check:**
- `projects/20260518-production-polish/workflow/feature-setup.md` -- present
- `projects/20260518-production-polish/product-specs/prd.md` -- present (requirements frontmatter only; full PRD will be produced in Stage 1)
- `projects/20260518-production-polish/generated-docs/design/` -- present

**Input quality check:** No issues. `prd.md` contains requirements frontmatter as expected after `/feature-init`; Stage 1 will produce the full PRD body.

**Software stack:** Existing stack is Swift 5.10 + SwiftUI (macOS), confirmed from `MacRecordWidget/`. No BE, FE, DB, or Infra layers are in scope. This matches the macOS tier in `tech-config.md`. No unlisted technology is being adopted, so no Arch approval is required on stack grounds.

> 👀 **Source location note:** Existing source lives at `MacRecordWidget/` (not `src/`). Refactored Swift output will be edited in-place at `MacRecordWidget/` rather than under `src/`. No new `src/` subtree will be created for a refactor-only pass.

**Risks and unknowns:**

- The two-file codebase has no existing tests. Introducing XCUITest or Swift Testing for a menu bar extra is non-trivial -- `MenuBarExtra` with `.window` style is not easily reachable by UI automation. QA scope needs to be agreed before Stage 5 begins.
- The popover dismissal workaround (`keyWindow?.orderOut` after a 100 ms delay, documented in CLAUDE.md) is a known fragile point. The Swift Engineer refactor should resolve this, but the correct fix must be agreed in the Swift Detailed Design before implementation.
- `@Observable` (Observation framework) requires macOS 14+. The current deployment target should be confirmed so the Swift Engineer can determine whether the migration is safe.

**Out of scope:** New recording modes, backend services, web frontend, database, cloud infrastructure, new Shortcuts integrations.

---

## Open Questions

1. ❓ Should the System Architecture step in Stage 3 be skipped? The feature-setup.md marks it active, but this is a two-file refactor with no new infrastructure and no unfamiliar technology -- the skip condition in `feature-setup.md` ("skip if no new infrastructure or unfamiliar technology") appears to apply. EM will make the final call during Stage 3.

2. ❓ What is the minimum macOS deployment target for the refactored app? `@Observable` and the Observation framework require macOS 14. If the current target is 13 or lower, the Swift Engineer cannot migrate from `ObservableObject` without bumping the target.

3. ❓ Should Stage 5 (QA) be scoped to manual smoke testing rather than full automation? XCUITest has very limited access to `MenuBarExtra` popovers. An automated suite may be impractical for this app's surface area.

---

## Next Step

Once approved, PM produces the full PRD for `projects/20260518-production-polish/product-specs/prd.md` -- refining the requirements frontmatter into a complete, reviewable PRD.
