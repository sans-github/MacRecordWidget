# Rule: Progress Tracking for Multi-Phase Work

`workflow/delivery-tracker.md` is the single source of truth for both human milestone gates and phase progress. It is progressively filled by EM as decisions are made.

For any task that follows a phased workflow, maintain `delivery-tracker.md` throughout execution.

## Setup

`delivery-tracker.md` is seeded at kickoff with initial steps and human gates. EM adds detailed implementation steps progressively -- after arch engagement is decided, after detailed design, etc. Do not begin implementation work until the relevant steps exist in the plan.

## During execution

- Check off each step immediately when its output is confirmed present and correct -- not when work starts.
- Never mark a step complete based on memory or assumption. Verify by checking the actual artifact, file, or commit.
- For steps that produce a file artifact: resolve the path from the File locations table in `tech-config.md`, then write the artifact as a relative markdown link `→ [path/to/artifact.md](../path/to/artifact.md)` in the step line before checking it off. Always use a relative markdown link -- not a bare path or code span -- so the artifact is clickable in GitHub and most markdown viewers. Do not check off until the file exists at that path.
- Do not batch checkoffs. Mark steps one at a time as they complete.
- After completing any step marked 💾, create a git commit immediately before proceeding to the next step. Do not ask -- commit automatically.
- After checking off any step, scan its parent phase group (bold label line, e.g. `- [ ] **Backend Development**`). If every child step under that group is `[x]`, mark the parent `[x]` immediately -- in the same edit, not deferred. Phase group checkboxes are derived state: they must always reflect the completion of all children. Do not mark a phase group `[x]` if any child step is still `[ ]` or `[-]` and not yet done. Stage headings (`### Stage N: ...`) have no checkbox and are never rolled up.
- When the orchestrator reaches the end of the list, stop and wait -- EM will add the next batch of steps.

## On resume (interrupted session)

1. Read `delivery-tracker.md` first.
2. Find the last checked step.
3. Verify that step's output actually exists (file, artifact, commit). If it does not, uncheck it and redo it.
4. Continue from the first unchecked step.

## Format

Every step must include a done condition so the orchestrator can verify completion, not infer it.

```markdown
## Kickoff

1. [x] **PM:** review PRD with human, confirm scope → [product-specs/prd.md](../product-specs/prd.md) -- done when: human approves verbally
2. [x] 👤 **HUMAN:** review and approve PRD -- done when: human confirms
3. [x] **DESIGNER:** produce mocks → [generated-docs/design/login-flow.html](../generated-docs/design/login-flow.html) -- done when: mocks present and PM satisfied
4. [ ] **ARCH:** produce HLD → `generated-docs/architecture/hld.md` -- done when: EM approves
```

The `→ link` on a checked step is the confirmed artifact link -- written by the agent that produced the artifact when it checks off, not at plan creation. For steps that produce multiple files, list them all: `→ [path/a.md](../path/a.md), [path/b.html](../path/b.html)`.

Skipped steps (e.g. out of scope for current delivery phase) should be marked with a note rather than left blank:

```markdown
5. [ ] **SDET:** X -- SKIPPED (Phase 1: SDET inactive)
```
