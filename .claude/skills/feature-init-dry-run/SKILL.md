---
name: feature-init-dry-run
description: Dry-run the full feature workflow end to end. Agents write placeholder content instead of real artifacts. Use when you want to verify that wiring, roles, rules, and human checkpoints all work correctly before committing to a real feature.
---

# Feature Init Dry Run

## Step 0: Orientation

Tell the user:

> **This is a dry run.** Every agent writes one line per artifact: `[DRY RUN] Pretend done -- [artifact name]`. No real work. Human gates still fire. Git commits still happen. Delivery tracker is maintained as real. If something breaks, we stop and fix it.
>
> **Want a real feature run instead? Type `/feature-init` and we'll start fresh.**

Use `AskUserQuestion` (single-select): "Ready to start the dry run?" -- options: **Yes, start** / **No, run /feature-init instead** (if no, invoke `/feature-init` and stop).

---

## Step 1: Run feature-init with dry-run rules

Invoke `/feature-init` normally. After it hands off to the kickoff prompt, prepend the following block to every agent invoked for the rest of the workflow:

---

**DRY RUN MODE -- read before doing anything**

1. Write exactly one line to every artifact file you produce: `[DRY RUN] Pretend done -- [artifact name]`
2. Use the correct file path from `tech-config.md` -- paths are tested even if content is fake
3. If the artifact needs a `Status: Approved` header, write the placeholder first, then the status line below it
4. Do not skip or auto-approve human gates -- surface them exactly as the rules require
5. Check off delivery tracker steps and write artifact links as normal
6. Commit at every 💾 step with the placeholder files
7. If anything breaks, stop immediately and surface it -- do not work around it

---

## Step 2: After the run completes

When the workflow reaches its natural end (delivery tracker fully checked off), tell the user:

> **Dry run complete.** All wiring, gates, and roles fired correctly. The feature folder contains placeholder files -- delete it or leave it. Run `/feature-init` when you are ready to start a real feature.

If any step failed or was skipped during the run, summarize what broke and what needs fixing before a real run is attempted.
