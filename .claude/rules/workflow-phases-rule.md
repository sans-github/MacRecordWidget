# Rule: Define Work as Phased Workflow

For any multi-step project or feature, define the work as a structured workflow document before starting execution.

## Structure

A workflow document must have:

- **Phases** -- top-level groupings of related work (e.g. "Phase 1: Requirements", "Phase 2: Design")
- **Numbered steps** within each phase -- specific, actionable units of work
- **Responsible role** per step -- who does it (agent, team member, or role)
- **Expected artifact** per step -- what is produced (document, plan, contract, implementation)

## Rules

- Phases must be sequential. Do not start a phase until the previous one is complete.
- Steps within a phase may run in parallel only when explicitly stated.
- Each step must produce a concrete, verifiable artifact or output. Vague steps like "discuss" are not allowed -- they must produce a decision record or updated document.
- Collaboration loops between roles (e.g. EM<>FE) are explicit steps, not implicit. Name them, include them in the numbered sequence, and define the exit condition (both parties aligned).
- The document must be human-readable as a standalone process spec -- not just machine-executable.

## Example shape

```
## Phase 1: Name

1. **Role** does X, producing artifact Y.
2. **Role A** and **Role B** collaborate (A<>B loop) until aligned on Z.

## Phase 2: Name

3. ...
```
