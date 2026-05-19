# Rule: Delegate to Named Roles

When a step, plan, or instruction names a specific agent role (e.g. EM, BE, FE, Swift Engineer, PM, Designer, macOS Designer, QA, Arch, DevOps), the orchestrator must delegate that work to the named agent -- not execute it directly.

## What this means

- "EM produces X" → invoke the EM agent and instruct it to produce X
- "BE authors the schema" → invoke the BE agent
- "Designer produces mocks" → invoke the Designer agent

The orchestrator coordinates and sequences. It does not substitute for a named role, even if it could produce a plausible output.

## Why

Each agent role carries domain expertise, constraints, and commit conventions specific to that role. Work produced by the wrong role will lack those constraints and may produce subtly incorrect or incomplete output -- for example, an implementation plan authored by the orchestrator instead of EM will miss EM-specific delivery sequencing and phase logic.

## Exceptions

A step that is explicitly addressed to the orchestrator (e.g. "write Status: Approved at the top of the file", "ask the human to confirm") is not a delegation -- the orchestrator executes it directly.

## Applies to

All phases of a project: kickoff, planning, design, implementation, testing, deployment.
