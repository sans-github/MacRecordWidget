---
purpose: >
  Filled in by /feature-init (Step 2: HTML phase config) before any agent begins work.
  Configures which phases to include or skip and any deviations from the default collaboration pattern.
  Agents must read this before doing anything and use it to seed delivery-tracker.md.
---

# Project Config

## Project phases

The orchestrator reads this to seed `delivery-tracker.md`.

Toggle rules:
- `[ ]` -- active, include in the plan
- `[-]` -- skip. Apply to a stage to exclude all its steps -- no need to mark individual steps inside it. `[-]` is final: no agent may add, restore, or modify steps in a `[-]` stage. Only the human can change it.
- `💾` -- create a git commit automatically after this step completes, before moving on

---

### Stage 1: Discovery

- [ ] **Requirements Finalization**
  - [ ] **PM:** review PRD with human, surface open questions, confirm scope → [PRD]
  - [ ] 👤💾 **HUMAN:** review and approve PRD

---

### Stage 2: Design

- [ ] **UI / UX Design**
  - [ ] **DESIGNER:** produce mocks → [Mocks]
  - [ ] 👤💾 **HUMAN:** review and approve mocks

---

### Stage 3: Technical Planning

- [ ] **Engineering Kickoff**
  - [ ] **EM:** decide on architecture engagement → [Feature Setup]

- [ ] **System Architecture** *(skip if no new infrastructure or unfamiliar technology)*
  - [ ] **ARCH:** produce system architecture → [System Architecture]
  - [ ] 👤💾 **HUMAN:** review and approve system architecture

- [ ] **High-Level Design**
  - [ ] **EM:** produce high-level design → [Eng Plans (HLD)]
  - [ ] **EM <> DevOps:** collaboration loop -- review infra decisions in HLD, align on Terraform approach and AWS component choices *(skip if deployment target is local)*
  - [ ] 👤💾 **HUMAN:** review and approve high-level design

- [ ] **Implementation Plan**
  - [ ] **EM:** produce detailed implementation plan → [Implementation Plan]; write Stage 4 and Stage 5 steps to `workflow/implementation-plan.md` as a standalone file; every step must include a done condition (e.g. "done when: Status: Approved written to file" or "done when: human confirms")
  - [ ] 👤💾 **HUMAN:** review and approve implementation plan
  - [ ] **EM:** seed approved steps into Stage 4 and Stage 5 of `delivery-tracker.md`, replacing the skeleton

---

### Stage 4: Engineering
> Skeleton -- EM fills in these steps during Implementation Planning, only if this stage is `[ ]`. If `[-]`, skip entirely and do not revisit.

- [ ] **BE Detailed Design**
  - [ ] **BE:** produce detailed design → [BE Detailed Design] -- done when: Status: Approved — EM set in file
  - [ ] 💾 **EM:** review and approve BE detailed design -- done when: Status: Approved — EM set in file

- [ ] **FE Detailed Design**
  - [ ] **FE:** produce detailed design → [FE Detailed Design] -- done when: Status: Approved — EM set in file
  - [ ] 💾 **EM:** review and approve FE detailed design -- done when: Status: Approved — EM set in file

- [ ] **Swift Detailed Design** *(skip if no macOS app)*
  - [ ] **SWIFT ENGINEER:** produce detailed design → [Swift Detailed Design] -- done when: Status: Approved — EM set in file
  - [ ] 💾 **EM:** review and approve Swift detailed design -- done when: Status: Approved — EM set in file

- [ ] **API Contract**
  - [ ] **BE + FE:** align on API contract → [API Contract]
  - [ ] 💾 **EM:** review and approve API contract

- [ ] **BE Issues List**
  - [ ] **EM:** produce and approve BE issues list -- done when: Status: Approved — EM set in list; BE creates GH issues and begins implementation

- [ ] **Backend Development**
  - [ ] **BE:** implement database schema and migration scripts → [DB Schema Files], [DB Migrations]
  - [ ] 💾 **EM + BE:** review and approve DB schema -- done when: Status: Approved — EM set in schema file; ORM DDL generation disabled; migration tool configured to run on startup; blocks migrations and seed work
  - [ ] **BE:** implement API endpoints → `src/`
  - [ ] **BE:** implement logging -- done when: `be-logging` checklist fully checked off (structured JSON appender, TraceIdFilter, MDC correlation, access log, layer coverage)
  - [ ] **BE:** write unit and integration tests
  - [ ] 💾 **EM:** review and approve BE implementation -- done when: logging checklist verified; openapi.json exported and committed (Spring Boot only); Status: Approved — EM set in artifact
  - [ ] **EM:** approve BE artifacts + test docs -- done when: Status: Approved noted; unblocks QA automation against BE

- [ ] **FE Issues List**
  - [ ] **EM:** produce and approve FE issues list -- done when: Status: Approved — EM set in list; FE creates GH issues and begins implementation

- [ ] **Frontend Development**
  - [ ] **FE:** implement UI components per approved mocks → `src/`
  - [ ] **FE:** integrate with API
  - [ ] **FE:** implement logging -- done when: `fe-logging` checklist fully checked off (logger module, sessionId, traceId propagation from response headers, API call coverage, error boundary logging)
  - [ ] **FE:** write component and end-to-end tests
  - [ ] 💾 **EM:** review and approve FE implementation -- done when: logging checklist verified; Status: Approved — EM set in artifact
  - [ ] **EM:** approve FE artifacts + test docs -- done when: Status: Approved noted; unblocks QA automation against FE

- [ ] **Swift Engineer Issues List** *(skip if no macOS app)*
  - [ ] **EM:** produce and approve Swift Engineer issues list -- done when: Status: Approved — EM set in list; Swift Engineer creates GH issues and begins implementation

- [ ] **macOS Development** *(skip if no macOS app)*
  - [ ] **SWIFT ENGINEER:** implement SwiftUI views per approved mocks and component spec → `src/`
  - [ ] **SWIFT ENGINEER:** implement data layer (SwiftData / Core Data / networking) → `src/`
  - [ ] **SWIFT ENGINEER:** write unit tests and XCUITests -- done when: `swift-testing` checklist fully checked off
  - [ ] 💾 **EM:** review and approve Swift Engineer implementation -- done when: Status: Approved — EM set in artifact
  - [ ] **EM:** approve Swift Engineer artifacts + test docs -- done when: Status: Approved noted; unblocks QA automation against Swift Engineer output

- [ ] **Infrastructure** *(skip if no new infrastructure)*
  - [ ] **DEVOPS:** produce deployment plan → [Deployment Plan]
  - [ ] 👤💾 **HUMAN:** review and approve deployment plan
  - [ ] **DEVOPS:** provision infrastructure per approved architecture → [Infrastructure]
  - [ ] **QA + DEVOPS:** smoke test loop *(skip if deployment target is local)*
    - [ ] **DEVOPS:** hand off live server URL to QA
    - [ ] **QA:** run API-level and E2E smoke checks against live server
    - If any check fails: QA reports failing test case and error details to DevOps → DevOps remediates → QA re-runs; loop repeats until all pass
    - Done when: all smoke checks exit 0
  - [ ] 💾 **EM:** review and approve infrastructure

---

### Stage 5: Quality Assurance
> Skeleton -- EM fills in these steps during Implementation Planning, only if this stage is `[ ]`. If `[-]`, skip entirely and do not revisit.

- [ ] **Test Planning**
  - [ ] **QA:** produce test plan aligned to API contract and implementation → [Test Plan]
  - [ ] 💾 **EM:** review and approve test plan

- [ ] **QA Issues List**
  - [ ] **EM:** produce and approve QA issues list -- done when: Status: Approved — EM set in list; QA creates GH issues and begins implementation

- [ ] **Test Execution**
  - [ ] **QA:** implement automated tests against BE
  - [ ] **QA:** implement automated tests against FE
  - [ ] **QA:** implement automated tests against Swift Engineer output *(skip if no macOS app)*
  - [ ] **QA + BE:** resolve backend test blockers
  - [ ] **QA + FE:** resolve frontend test blockers
  - [ ] **QA + SWIFT ENGINEER:** resolve macOS test blockers *(skip if no macOS app)*
  - [ ] 💾 **EM:** review and approve test results

---

### Stage 6: Master Baseline Update

> Always `[ ]` -- this stage is never skippable. Runs after Stage 5 sign-off and must complete before any new feature can begin.

- [ ] **PM:** merge this feature's PRD into `projects/master/product-specs/prd.md`
  - If master PRD exists: consolidate -- add new sections, update changed sections, do not duplicate
  - If master PRD is empty: copy feature PRD as-is
  - done when: master PRD reflects all shipped features including this one

- [ ] **DESIGNER / macOS DESIGNER:** merge this feature's mocks into `projects/master/mocks/`
  - If master mocks exist: add new pages, replace updated pages, remove obsolete pages
  - If master mocks are empty: copy feature mocks as-is
  - done when: master mocks reflect the current live UI across all shipped features

- [ ] 👤💾 **HUMAN:** confirm master is current

---

### Stage 7: README and CLAUDE.md

> Always `[ ]` -- this stage is never skippable.

- [ ] **EM:** generate `scripts/dev.sh` by inspecting the actual `src/` structure
  - Detect BE type: `src/` contains `pom.xml` → Maven (`mvn spring-boot:run`), `build.gradle` → Gradle (`./gradlew bootRun`), `requirements.txt` or `pyproject.toml` → Python (`uvicorn` / `python -m ...`), `package.json` at BE root → Node (`npm run dev` or `npm start`)
  - Detect FE type: look for `package.json` under FE root; if `vite` is in `devDependencies` → `npm run dev`; otherwise `npm start`
  - Derive ports from config files where present: `src/*/src/main/resources/application.properties` (server.port), `vite.config.ts` (server.port), `.env` (PORT / VITE_PORT); fall back to well-known defaults (BE: 8080, FE: 5173)
  - Script must: use relative paths from repo root, echo what is spawning and on which port, print clickable URLs after both processes are up (include `http://localhost:{port}/swagger-ui.html` if `springdoc-openapi-starter-webmvc-ui` is present in `pom.xml`), trap Ctrl+C to kill both background processes cleanly
  - Script is generated fresh from the actual codebase -- never copied from a static template
  - done when: `scripts/dev.sh` exists at repo root, is executable (`chmod +x`), and correctly reflects the detected stack and ports

- [ ] **EM:** run `/document-release` skill to update `README.md` and `CLAUDE.md`
  - README constraints: project overview (1 paragraph), features list, prerequisites, how to run (BE and FE), how to run tests; "Running the app" section must list `bash scripts/dev.sh` as the primary start command with manual per-service steps as fallback; high-level and end-user facing only
  - CLAUDE.md constraints: tech stack, folder structure, key conventions agents need to follow in this codebase
  - done when: both files exist at repo root, reflect all shipped features, and README references `scripts/dev.sh`

- [ ] 👤💾 **HUMAN:** review and approve README and CLAUDE.md

---

### Stage 8: Release

- [ ] **Phase Sign-off**
  - [ ] **EM:** verify all artifacts complete and approved, confirm deployment target is ready
  - [ ] 👤💾 **HUMAN:** review and approve release readiness

---

## Deployment target

Declare the deployment intent for this project. Agents use this to determine whether DevOps/IaC work is in scope.

```
# Options: local | existing AWS infra | new AWS infra | TBD
local
```

---

## Additional context

Include anything that should inform delivery-tracker.md -- handwritten notes, whiteboard photos, Excalidraw diagrams, sketches, or rough ideas. Agents must respect and factor all of this in when generating delivery-tracker.md.

```
# Example:
- See product-specs/whiteboard-sketch.jpg for a rough flow diagram
- The team discussed keeping the data model flat -- avoid joins where possible
- The PM has a strong preference for shipping Phase 1 without auth; add auth in Phase 2
```
