---
name: api-design-principles
description: REST API design -- resource modeling, HTTP semantics, versioning, pagination, error handling, and auth. Use when designing new REST APIs, reviewing API specifications, or establishing API design standards.
metadata: 
  source: https://skills.sh/wshobson/agents/api-design-principles
---

# API Design Principles

Covers REST API design: resource modeling, HTTP semantics, versioning, pagination, error handling, auth, and observability.

## When to use

- Designing new REST APIs or reviewing existing ones
- Establishing API design standards for a team
- Reviewing API specifications before implementation

## Key concepts

**Resource-oriented design** -- APIs expose nouns (users, orders), not verbs. HTTP methods carry the action intent. URLs form a shallow, predictable hierarchy.

**HTTP semantics** -- GET is safe and idempotent. POST creates. PUT replaces entirely. PATCH updates partially. DELETE removes. Status codes must match the outcome -- don't return 200 for errors.

**Versioning** -- plan for breaking changes from day one. URL versioning (`/v1/`) is the most visible and easiest to route; choose a strategy and apply it consistently.

**Pagination** -- never return unbounded collections. Use offset-based for simple cases, cursor-based for large or fast-moving datasets. Always include metadata (total, pages, next cursor).

**Error handling** -- every error returns the same shape: code, message, field-level details where applicable. Callers should never have to guess the format.

**HATEOAS** -- embed `_links` in responses so clients can navigate without hardcoding URLs. Valuable for public or long-lived APIs.

## Resources

- Load `rest-reference.md` when actively designing or reviewing an API -- it covers URL rules, HTTP method semantics, pagination patterns, auth, rate limiting, caching, and more.
- Load `api-checklist.md` before declaring an API design complete. Items that genuinely do not apply must be noted as out of scope, not silently skipped. EM verifies the checklist was run during API contract approval.
