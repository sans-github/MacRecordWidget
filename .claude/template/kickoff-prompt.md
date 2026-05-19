# Kickoff Prompt

**Feature folder:** `projects/[YYYYMMDD-feature-name]`

---

## Required reading

Read these before doing anything:

1. `CLAUDE.md` (if present) -- existing software stack, conventions, project structure.
2. `.claude/agents-guide.md` -- agent team orientation, collaboration model, rules. The project config overrides where they differ.
3. `.claude/tech-config.md` -- file locations, naming conventions, tooling choices.
4. `[feature-folder]/workflow/feature-setup.md` -- active agents, skipped phases, overrides.
5. `[feature-folder]/product-specs/prd.md` -- the feature PRD.

Never hardcode artifact paths. Resolve all artifact paths by looking up the artifact name in the File locations table in `tech-config.md`.

---

## Produce the kickoff plan

Write `[feature-folder]/workflow/kickoff-plan.md` with the sections below.

Emoji conventions -- use inline on the heading, row, or bullet where the action is needed:
- 👀 Human must review and explicitly confirm before work proceeds
- ❓ Human input is missing and required -- agents cannot proceed without it
- 👤 Human gate -- human must approve before downstream work is unblocked

### 1. What I understood

Start with a one-paragraph big picture: what will be built and how the pieces fit together. Then summarize the PRD and project config in your own words. Call out anything ambiguous or missing that I should clarify before work begins.

**Folder structure check:** Verify the feature folder contains:
- `[feature-folder]/workflow/feature-setup.md`
- `[feature-folder]/product-specs/prd.md`
- `[feature-folder]/generated-docs/design/`

If any are missing, stop and tell the human exactly what is missing.

**Input quality check:** Flag any of:
- Unfilled placeholders (`[YYYYMMDD-feature-name]`, `TODO`, `TBD`, template defaults)
- Sections untouched or still containing template defaults
- Content in `feature-setup.md` or `prd.md` that contradicts the project description
- Sparse or vague entries (e.g. "active agents: all" with no rationale, one-line PRD)
- A stage marked as active whose upstream dependency is skipped -- flag the broken dependency and block until resolved. Dependencies: Design requires Discovery; System Design requires Discovery and Design; Technical Planning requires System Design; Engineering requires Technical Planning; QA requires Engineering; Release requires QA
- `prd.md` contains only a requirements frontmatter block (no full PRD body) -- this is the expected state after `/feature-init`. Do not flag it and do not invoke PM. Stage 1 will produce the full PRD. If `prd.md` is completely empty (no content at all), flag it as a blocker -- user must re-run `/feature-init` to capture requirements first.

Do not proceed if critical inputs are missing or stale. Surface them and wait for the human.

**Risks and unknowns:** Anything that could slow the project down: unclear requirements, missing design decisions, external dependencies, integration risks with existing code, or anything needing resolution before work starts. If `tech-config.md` has changed since the last feature (or this feature requires a change), assess the impact: what changed, which parts of the codebase are affected, risk level with reasoning, extent of refactor, and whether it could introduce regressions. Do not proceed past tech-config risks without explicit human sign-off.

**Out of scope:** Explicitly state what is NOT being built, based on the project config and PRD.

**Software stack:** Inspect `src/` to determine whether an existing stack is in place. If a stack exists, confirm it and list the key technologies per layer. If no stack exists, select the minimum subset from the Tech stack section of `tech-config.md` that covers the project requirements per layer -- do not default to the full list. Choosing a lighter option already on the list does not require Arch approval. Arch approval is required only when adopting an unlisted technology -- surface the concern regardless. If anything in the PRD cannot be addressed with the current or selected stack, flag it explicitly. Flag any mismatch between stack weight and project scope: what is too broad, unnecessary, missing, or potentially wrong; why it is a concern; and a concrete alternative with rationale (e.g. "consider Zustand instead of Redux Toolkit for a single-page app with no complex shared state"). Prefer proven, widely adopted libraries. Prefer the smallest stack that covers the requirements. Do not silently confirm if the scope is small or any layer looks mismatched. Source code output goes directly under `src/` (e.g. `src/backend/`, `src/frontend/`, `src/db/`). Never create a feature-named subfolder under `src/`. Feature names belong only under `projects/`.

### 2. Open questions

Numbered list of questions that need my answers before agents can proceed. Do not make assumptions.

When the human answers a question, update that line in `kickoff-plan.md`: add ✅ after ❓ and append a short resolution note inline. Unanswered questions stay as ❓ only. Example:

```
1. ❓✅ Will auth be included in Phase 1? -- No, auth ships in Phase 2.
2. ❓ Which cloud region should the infra target?
```

Do not remove the original question text. Mark all questions resolved before proceeding to approval.

### 3. Next step

One sentence only. State exactly what happens after I approve: who does what, and what artifact they produce. Must match the first unchecked step in `delivery-tracker.md`.

Example: "Once approved, Designer produces mocks for `[feature-folder]/generated-docs/design/` before any engineering work begins."

---

## After approval

Do not begin any work until I have reviewed and approved the kickoff plan.

### When I approve the kickoff plan:

1. Write `Status: Approved — Human` and `Approved: YYYY-MM-DD` at the top of `kickoff-plan.md`. Then invoke `/my-git-commit` automatically without asking. Commit subject: "Add kickoff plan for [feature-name]" where `[feature-name]` is the `YYYYMMDD-feature-name` portion of the feature folder path.

2. Seed `[feature-folder]/workflow/delivery-tracker.md` from `## Project phases` in `feature-setup.md`:
   - First line after the heading: `[ ]  not started   |   [-]  skipped   |   [x]  done`
   - Work through each phase in order.
   - Phase or step `[-]`: mark SKIPPED, append any inline reason if present.
   - Phase or step `[ ]`: include as an active numbered checkbox.
   - Stage 6 (Master Baseline Update) is always `[ ]` -- never mark it SKIPPED regardless of `feature-setup.md`. If it appears as `[-]`, correct it to `[ ]` silently.
   - Stage 7 (README and CLAUDE.md) is always `[ ]` -- same rule applies.
   - Stage 8 (Release) is always `[ ]` -- same rule applies.
   - Do not resolve contradictions here -- they must be caught during the input quality check before this step is reached.

   Then invoke `/my-git-commit` automatically without asking. Commit subject: "Seed delivery tracker for [feature-name]" where `[feature-name]` is the `YYYYMMDD-feature-name` portion of the feature folder path.

3. Begin execution: work through `delivery-tracker.md` top-to-bottom.

### Execution rules

- Never self-execute a step assigned to a named role. Invoke the Agent tool with that role.
- Never skip ahead. A step is not started until all prior steps are checked off.
- After checking off any step, scan its parent phase group (bold label line, e.g. `- [ ] **Backend Development**`). If every child step under that group is `[x]`, mark the parent `[x]` in the same edit. Do not defer or batch rollup. Stage headings (`### Stage N: ...`) have no checkbox and are never rolled up.
- After completing any step marked 💾, create a git commit immediately before proceeding to the next step. Do not ask -- commit automatically. Commit subject: imperative mood, describe the artifact (`Add PRD for sample-feature`), no stage numbers or approval metadata.
- When the orchestrator reaches the end of the list, stop and wait -- EM will add the next batch of steps.
- When a 👤 human gate is reached, follow the review flow in `html-preview-rule.md`: use `AskUserQuestion` to offer opening the HTML preview in the browser, then ask for approval. Check the box only after human confirms.
- After human confirms a gate, do not prompt for a commit. Any uncommitted changes (e.g. tracker checkboxes) will be picked up by the next 💾 auto-commit.
