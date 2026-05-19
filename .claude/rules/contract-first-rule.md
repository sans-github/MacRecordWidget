# Rule: Contract-First Dependencies

No agent may begin work that depends on an upstream artifact until that artifact is explicitly approved. This prevents rework caused by building on an unstable or unreviewed foundation.

This rule governs **agent-to-agent technical contracts** only. Human milestone gates (PRD, Mocks, Sys Arch, Implementation Plan, Kickoff Plan) are defined per-project in `workflow/delivery-tracker.md` -- not here.

## Agent-to-agent technical contracts

| Upstream artifact | Approver | Downstream work blocked |
|---|---|---|
| Tech stack / AWS component adoption | Arch | Proposing role (EM, BE, FE, Swift Engineer, DevOps) cannot include it in any artifact or begin provisioning |
| Deployment Plan (`deployment-plan.md`) | Human | DevOps cannot begin provisioning any infrastructure |
| HLD infra sections -- EM<>DevOps aligned *(non-local deployment only)* | EM | DevOps cannot begin Deployment Plan until EM and DevOps have completed their sync loop and EM has finalised the HLD |
| Eng Plans (HLD) (`hld.md` + `hld.html`) | EM | BE (Detailed Design), FE (Detailed Design), Swift Engineer (Detailed Design) |
| DB Schema | EM | BE data layer, migrations, queries |
| BE Detailed Design (`be-detailed-design.md`) | EM | BE API implementation, BE<>FE contract |
| FE Detailed Design (`fe-detailed-design.md`) | EM | FE component implementation, BE<>FE contract |
| Swift Detailed Design (`swift-detailed-design.md`) | EM | Swift Engineer implementation |
| API Contract | EM | BE endpoint implementation, FE integration |
| Test Plan | EM | QA Issues List, automation work |
| Issues List (BE) | EM | BE creates GH Issues and begins implementation |
| Issues List (FE) | EM | FE creates GH Issues and begins implementation |
| Issues List (Swift Engineer) | EM | Swift Engineer creates GH Issues and begins implementation |
| Issues List (QA) | EM | QA creates GH Issues and begins implementation |
| BE Artifacts + BE Test Docs | EM | QA automation against BE |
| FE Artifacts + FE Test Docs | EM | QA automation against FE |
| Swift Engineer Artifacts + Swift Test Docs | EM | QA automation against Swift Engineer output |

## What "approved" means

A technical contract is approved when the artifact has a `Status: Approved` line at the top of the file, with the approving role noted:

```
Status: Approved — EM
Approved: 2026-04-01
```

The approving agent writes this line after reviewing the artifact. The human does not write this line for technical contracts.

## Human milestone gate behavior

Human milestone gates are defined per-project in `workflow/delivery-tracker.md`. When an agent completes work that produces a checkpoint artifact, it must:

1. Stop and explicitly notify the human: "Checkpoint reached -- [artifact] is ready for your review. No work will proceed until you approve."
2. Wait for the human to verbally confirm (e.g. "done", "proceed"). After the human confirms, the orchestrating agent writes `Status: Approved — [role]` and `Approved: YYYY-MM-DD` into the artifact file before proceeding -- unless the loop that produced the artifact already wrote `Status: Approved` (e.g. PM sets it on mocks as the loop exit). In that case, the orchestrator adds only the `Approved: YYYY-MM-DD` line if it is missing, and does not overwrite the existing status line.
3. Run `git diff --stat HEAD` to see what has changed. Use `AskUserQuestion` to summarize the diffs in plain language and ask: "These files changed: [summary]. Want to commit before we move on?" If yes, invoke the `/my-git-commit` skill and wait for it to complete.
4. Only then proceed to the next step.

Agents must not assume approval, infer it from context, or continue past a checkpoint without an explicit human signal. If the human has not responded, the agent stays stopped.

## When a contract is not yet approved

Stop immediately. Do not do speculative work. Surface the blocker clearly:

> Blocked: waiting for [artifact name] to be approved by [role]. No downstream work will proceed until `Status: Approved` is set.

Do not draft a substitute, make assumptions about what the contract will say, or begin work on parts that "probably won't change." Wait for the real approval.
