---
name: prd-craft
description: >
  PM writing craft, interview discipline, PRD format spec, and app flows artifact.
  Loaded when authoring or reviewing a PRD, running a requirements interview, or producing app flows.
---

## Writing principles

Apply these to every document you produce.

- **Don't make me think (P0):** make every idea instantly understandable. If a reader has to pause, rewrite.
- **Self-evident (P1):** if something isn't obvious, add an inline example -- don't rely on the reader to infer.
- **Design for scanning (P2):** sentences ≤20 words. Lead with keywords. Bullets over paragraphs. Big picture before detail.
- **Clarity over consistency (P3):** choose the clearest word even if it breaks a naming pattern.
- **Relentless trimming (P5):** cut 50% of words. Then cut again. Every word must earn its place.

---

## Interview flow

Before generating any document, run a short interview:

1. Ask one clarifying question at a time. Never bundle multiple questions.
2. After gathering enough to proceed, write a recap of ≤4 bullets summarizing your understanding.
3. Get explicit approval on the recap before writing anything.

If the user's answers conflict, call it out directly and resolve before continuing.

---

## PRD format spec

- H2 headings, bullets throughout, no prose paragraphs
- No filler: no "this document describes", no "as mentioned above"
- Tone: friendly expert -- calm, direct, no corporate speak
- Length: as short as possible while remaining complete

---

## PRD anatomy

Everything lives in a single `prd.md`. Sections in order:

1. **Elevator pitch** -- one paragraph, 30-second summary of what this is and why it matters
2. **Problem** -- what is broken or missing today; who feels it and how
3. **Target audience** -- primary users and secondary users; one line each
4. **Features** -- bullet list per phase (MVP / V1 / V2); each feature is one line
5. **Conceptual data model** -- plain English only (no schema, no SQL); list entities and their relationships (e.g. "A Project has many Tasks; a Task belongs to one User")
6. **Roadmap** -- explicit phase breakdown: what ships in MVP, what defers to V1, what defers to V2; include rationale for deferral
7. **App flows** -- site map, user roles & access, user journeys; Designer uses this as the primary input for mock creation
8. **Acceptance criteria** -- one testable AC block per feature
9. **Risks & mitigations** -- known risks (technical, product, adoption) and how each will be addressed or monitored

---

## App flows (section 7 of prd.md)

App flows sit between features and ACs: they make the feature list concrete enough for Designer to start mocks without guessing.

**Site map** -- top-level pages only; one-line purpose per page:

| Page | Purpose |
|------|---------|
| `/` | ... |

**User roles & access** -- who can reach what:

| Role | Access |
|------|--------|
| Admin | ... |

**User journeys** -- max 3 steps each; cover the 2-3 most important flows only:

1. **[Journey name]**
   1. Step one
   2. Step two
   3. Step three
