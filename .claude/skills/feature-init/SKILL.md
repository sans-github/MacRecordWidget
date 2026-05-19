---
name: feature-init
description: Scaffold a new feature folder under projects/. Creates projects/master/ (once) and projects/YYYYMMDD-feature-name/ from the template. Use when starting work on a new feature.
---

# Feature Init

Scaffolds a new feature workspace and guides the user through requirements, config, and kickoff interactively. One command -- no manual file editing required.

**Sequence:** Requirements Kickoff → Scaffold → HTML Phase Config → Kick off

---

## Step 0: Requirements Kickoff

Open with: "Let me gather details about what you'd like to build today."

Use `AskUserQuestion` (single-select) to ask how the user wants to start:

- **Describe it now** -- you'll interview me
- **I have requirements text** -- I'll paste them
- **I have a full PRD** -- I'll paste it or give a file path

### Path A: Describe it now

Invoke the `senior-product-manager` agent with this instruction:

> "Run a short requirements interview with the user. Ask one question at a time. When you have enough context, produce: (1) a one-paragraph summary, (2) 3-5 key points, (3) a suggested 2-3 word kebab-case slug for the feature folder (e.g. `user-auth-flow`). Do not write a full PRD -- requirements summary only."

Wait for PM agent to complete. Extract the slug suggestion from its output.

### Path B: I have requirements text

Ask the user to paste their requirements. Then invoke `senior-product-manager` with:

> "The user has provided the following requirements: [paste]. Refine them into: (1) a one-paragraph summary, (2) 3-5 key points, (3) a suggested 2-3 word kebab-case slug. Requirements summary only -- no full PRD."

Extract the slug suggestion.

### Path C: I have a full PRD

Ask the user to paste the PRD content or provide a file path. If a file path is given, read the file. Derive a 2-3 word kebab-case slug from the PRD title or first heading. No PM agent invocation needed.

### Confirm the slug

After any path, present the slug suggestion to the user using `AskUserQuestion`:

> "I'll name the feature folder `YYYYMMDD-[slug]` (today's date will be prepended). Does this look right?"

Options: "Yes, use this name" / "Edit it" (user types a different slug via Other).

Hold the confirmed slug and requirements summary in context -- they are written to `prd.md` after the scaffold in Step 1.

---

## Step 1: Scaffold

Run `bash .claude/skills/feature-init/feature-init.sh YYYYMMDD-[confirmed-slug]` using Bash. IMPORTANT: always use this relative path exactly -- never expand it to an absolute path. Substitute today's date (YYYYMMDD) and the confirmed slug.

Show the user the folder tree from the script output. Extract the feature folder path from the output (format: `projects/YYYYMMDD-feature-name`) -- you will need it in every subsequent step.

**Write requirements to `prd.md`:**

- **Paths A or B:** Write the requirements frontmatter block to `[feature-folder]/product-specs/prd.md`:

  ```
  ---
  requirements:
    summary: <one paragraph from PM output>
    key_points:
      - <bullet>
      - <bullet>
    additional_context: none
    gathered_by: orchestrator-inline
  ---
  ```

- **Path C (full PRD provided):** Write the full PRD content directly to `[feature-folder]/product-specs/prd.md` (no frontmatter wrapper).

Then invoke `/my-git-commit` automatically without asking. Commit subject: `"Scaffold [feature-name] feature folder"` where `[feature-name]` is the `YYYYMMDD-feature-name` portion of the folder path.

---

## Step 2: HTML Phase Config

### Generate the HTML

Do NOT write HTML from scratch. Use the pre-built template at `.claude/skills/feature-init/feature-overview-template.html`.

Read `[feature-folder]/workflow/feature-setup.md` to extract stage data, then read the template and produce `[feature-folder]/workflow/feature-overview.html` by replacing three placeholders:

**`{{FEATURE_NAME}}`** -- feature name as a human-readable title (e.g. `User Auth Flow`)

**`{{PROJECT_SUMMARY}}`** -- 1-2 sentence summary from the requirements frontmatter in `prd.md`

**`{{STAGES_JSON}}`** -- a JSON array describing every stage. Each element:

```json
{
  "id": "Stage 1: Discovery",
  "name": "Stage 1: Discovery",
  "desc": "PM finalizes requirements with you before work begins.",
  "active": true,
  "locked": false,
  "gates": [
    { "id": "HUMAN: review and approve PRD", "label": "Review and approve the PRD", "active": true }
  ]
}
```

Rules for building `STAGES_JSON`:
- `active`: `true` if the stage is `[ ]`, `false` if `[-]`
- `locked`: `true` for Stages 6, 7, and 8 (never-skippable); `false` for all others
- `gates`: one entry per `👤` line in the stage; `active` defaults to `true`; `label` is plain English (strip "HUMAN:", "review and approve" → "Review and approve ...")
- Locked stages: set `locked: true` -- the template will automatically disable their gate checkboxes too

### Present the HTML

Use `AskUserQuestion` (single-select):

> "Phase overview is ready. Want to open it in your browser to configure your project?"

Options:
- **Open in browser** -- CC detects the OS and runs the appropriate command:
  - macOS: `open [feature-folder]/workflow/feature-overview.html`
  - Linux: `xdg-open [feature-folder]/workflow/feature-overview.html`
  - Windows: `start [feature-folder]/workflow/feature-overview.html`
- **Skip, use defaults** -- skip HTML; all stages remain active, deployment target stays `local`

If "Open in browser": after running the open command, tell the user: "The overview is open. Toggle any stages you want to skip, fill in deployment target, then click Confirm. Come back here and say 'done' when finished."

Wait for the user to return and say "done" (or similar).

### Read and apply the result

Read the clipboard using the appropriate command for the OS:
- macOS: `pbpaste`
- Linux: `xclip -selection clipboard -o` (fall back to `xsel --clipboard --output` if `xclip` is not installed)
- Windows: `powershell -command Get-Clipboard`

Write the output to `[feature-folder]/workflow/user-phase-input.json`. Then read that file.

Apply to `[feature-folder]/workflow/feature-setup.md`:
- For each stage with `false` in `phases`: change its `[ ]` to `[-]` at the stage line
- For each checkpoint with `false` in `checkpoints`: find the matching `👤` step line within that stage and change its `[ ]` to `[-]`
- Replace the deployment target `local` default in the `## Deployment target` block with the user's choice
- If `additional_context` is non-empty: replace the example block in `## Additional context` with the user's text

Delete `[feature-folder]/workflow/user-phase-input.json` after applying.

Print a plain-language summary:

```
Phases configured:
- Stage 1: Discovery        [ active ]
    👤 review and approve PRD          [ active ]
- Stage 2: Design           [ skipped ]
- Stage 3: Technical Planning  [ active ]
    👤 review and approve system architecture  [ skipped ]
    👤 review and approve high-level design    [ active ]
...
Deployment target: local
```

Use `[ active ]` for `[ ]` items and `[ skipped ]` for `[-]` items. Only show checkpoint rows for active stages.

Then ask: "Does this look right before we continue?" with options "Yes, continue" and "No, reopen browser". If reopen, re-run the HTML flow from "Present the HTML" and repeat until the user confirms.

---

## Step 3: Kick off

Ask the user: "Config and requirements are ready. Ready to kick off?" Offer "Yes, proceed" and "Not yet".

If yes: read `.claude/template/kickoff-prompt.md`, replace every occurrence of `[YYYYMMDD-feature-name]` with the actual feature folder path (e.g. `projects/20260420-my-feature`), then execute the resulting prompt as if the user had sent it. The kickoff prompt handles everything from here.
