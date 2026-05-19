# Rule: Backlog Reporting

All agents must report tech debt and non-feature bugs discovered during any session by appending to the Triage section of `BACKLOG.md` in the repo root.

## When to report

- A bug is observed or suspected (data, UI, API, infra, test)
- A shortcut or workaround was taken that should be revisited
- An implementation reveals a structural weakness not caused by the current task

## BACKLOG.md format

Two sections.

### For stakeholders

| | Layer | What | Why it matters | Action |
|--|-------|------|----------------|--------|
| 🔴 | Data | ... | ... | ... |

Layer labels: `Data`, `Interface`, `Reliability`, `Infrastructure`, `Quality`

Severity: 🔴 P0 broken/affects users now -- 🟡 P1 degrades quality or blocks future work -- 🟢 P2 polish/cleanup

### For engineers

**Triage:**
| ID | Area | Type | Summary | Source | Date |
|----|------|------|---------|--------|------|

**Active:**
| ID | Summary | Blocks | Ready? | Since |
|----|---------|--------|--------|-------|

**Resolved** (audit trail, never delete):
| ID | Summary | Resolved in | Date |
|----|---------|-------------|------|

## Field conventions

- `ID` -- sequential, never reused: B-001, B-002, ... (leave blank -- EM assigns at triage)
- `Area` -- BE, FE, Swift, DB, Infra, Design, QA, Spec, Mocks, Contract
- `Type` -- `bug` (observable defect), `debt` (internal quality), `ux` (usability without a crash), `gap` (missing or incomplete specification, design, or contract)
- `Source` -- `User`, `Agent`, `Retro`
- `Since` -- date item moved to Active; used for staleness tracking
- Priority (P0/P1/P2) -- assigned by EM+PM at triage only, never by agents

## Rules

- Never self-assign priority. Leave ID blank -- EM assigns at triage.
- Never move an item to Active. Triage only.
- Report even if the item seems minor. EM+PM decide what matters.
- After 2 iterations in Active with no milestone, prefix with 🟠 to flag for re-triage.
- When items must ship together, add below the Active table: `_B-001 + B-002 ship together. No stopgap._`

## GitHub labels

Backlog fields map directly to flat GH labels -- no prefixes. Apply one area label and one type label per issue; priority is added at triage. Full label list is in `tech-config.md`.

---

## Triage process (EM + PM)

Before every iteration kickoff: assign ID and priority, move to Active or drop, update the stakeholder section for P0/P1 items, update `_Last triaged_` date.
