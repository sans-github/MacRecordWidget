# Rule: Artifact Path Resolution

All artifact paths must be resolved from the File locations table in `tech-config.md`. This is the single source of truth for where every artifact lives.

## What this means

- Never hardcode a path from a workflow step line, memory, or prior context.
- When writing or reading any artifact, look up its name in the File locations table and use the path listed there.
- Workflow steps use bracketed artifact names (e.g. `→ [Eng Plans (HLD)]`) as lookup keys -- resolve them to a real path before writing any file.

## When a path changes

Update the File locations table in `tech-config.md` first. Then grep the full repo and update all references before committing. A path change without a grep is incomplete.

## Applies to

All agents, all phases, all sessions.
