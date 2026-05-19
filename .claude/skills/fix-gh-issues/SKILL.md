---
name: fix-gh-issues
description: Fetch open GitHub issues for this repo, analyze each one against existing patterns, and implement fixes end to end. Analyze before acting -- never implement on face value.
---

# Fix GitHub Issues

Work through open GitHub issues one at a time. For each: analyze fully, get approval, implement, commit, push, close. Never skip the analysis phase.

## Phase 1: Fetch the queue

```bash
gh issue list
```

If there are no open issues, report that and stop.

Take the lowest-numbered open issue and move to Phase 2. Do not batch or queue multiple issues at once.

## Phase 2: Read and analyze (do this fully -- then STOP and wait for approval)

Read the full issue:

```bash
gh issue view <N>
```

Then analyze on four dimensions before touching any file:

**1. Legitimacy** -- Is this a real, observed problem or speculative? Does it make sense in context? Does the concrete example (if any) actually demonstrate the gap?

**2. Pattern fit** -- Where does the fix actually belong?

Do not trust the file the issue names. Read the relevant files and find the correct home. Ask:
- Is this agent behavior (goes in the agent file) or domain workflow (goes in a skill or rule)?
- Does a section already exist that owns this concern?
- Does the proposed change follow the existing format -- section order, heading style, bullet conventions, table structure?

If the correct pattern does not exist in the codebase, stop and ask the user before inventing one. Do not create new structures speculatively.

**3. Human value** -- Does this make the workflow clearer, safer, or more useful for a human reviewer or engineer? If the answer is "marginally" or "not really", flag it.

**4. Agent value** -- Does this make agent output more correct, more complete, or less likely to fail silently? Does it give the agent a concrete protocol rather than a vague instruction?

**Correction check** -- If the issue proposes something factually wrong (wrong file, wrong approval target, wrong step), call it out explicitly and propose the correction. Do not silently implement the wrong thing.

### Present the analysis

Report to the user in this format before making any change:

> **Issue #N: [title]**
>
> **Legitimacy:** [assessment -- real/speculative, evidence]
> **Correct file(s):** [list, with reasoning if different from what the issue says]
> **Human value:** [assessment]
> **Agent value:** [assessment]
> **Corrections to the issue:** [any factual errors in the issue's proposal]
> **Proposed changes:** [bullet list of specific edits]
>
Then use `AskUserQuestion` (single-select) to ask for approval:

- Question: "Proceed with Issue #N?"
- Option 1: **Yes** -- implement the approved changes (list this first so the user can tab-select it)
- Option 2: **No / needs changes** -- stop and wait for revised direction

Wait for explicit user approval. Do not proceed on assumption or inference.

## Phase 3: Implement (only after approval)

Make exactly the changes that were approved -- nothing more. No adjacent cleanup, refactoring, or improvements not discussed in the analysis.

After making changes, verify:
- The change matches the file's existing format and conventions
- No hardcoded personal paths, credentials, or sensitive information was introduced
- If any artifact was renamed or moved, grep the full repo for stale references and update all of them before finishing
- **Language and stack agnosticism:** changes to agent files and rules must be expressed in terms that apply across stacks -- not tied to a specific language, framework, or tool. If the issue example is stack-specific (e.g. Spring Boot, React, Terraform), extract the general principle and write the rule at that level. Concrete examples are allowed to illustrate the principle, but the rule itself must hold regardless of stack (e.g. "apply all logging skill requirements before handoff" not "add these Spring Boot `application.properties` entries").

## Phase 4: Commit, push, close

Commit and push using `/my-git-commit-push`.

Then immediately close the issue -- no approval needed:

```bash
gh issue close <N> --comment "Fixed in <sha>. [one sentence on what changed and in which file(s)]"
```

## Phase 5: Repeat

After closing, run `gh issue list` again. If issues remain, take the next one and repeat from Phase 2. Stop when the queue is empty and report the count of issues resolved.
