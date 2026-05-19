---
name: collaboration-contracts
description: Single source of truth for all agent collaboration contracts -- what each role depends on, produces, and gatekeeps across all delivery phases. Update this file when any artifact flow, dependency, or approval gate changes. All agents load this at runtime.
---

# Collaboration Contracts

This is the single source of truth for artifact flows across the team. When a collaboration model changes, update this file only -- do not update individual agent files.

## How to use this skill

When this skill is loaded, treat every contract in this file as a hard constraint. Before any handoff, approval, or phase transition, re-read the relevant section and verify your action is permitted. Do not rely on memory of a prior read.

## HTML previews

Every time an agent writes or updates a human-gate artifact (PRD, kickoff plan, sys-arch, HLD, BE/FE/Swift detailed design, API contract, test plan), it must immediately generate a co-located `.html` preview via pandoc. At each 👤 review gate, offer to open the HTML in the browser using `AskUserQuestion`. Full details in `html-preview-rule.md`.

---

## PM <> User

**PM depends on:**
- Reqs -- gathered from User before authoring PRD

**PM produces:**
- `prd.md` + `prd.html` -- single document covering PRD, app flows, ACs, and risks; PM is gatekeeper; HTML generated via pandoc per `html-preview-rule.md`

---

## PM <> Designer

**PM provides to Designer:**
- PRD, ACs -- approved by PM; triggers Mock creation

**Designer provides to PM:**
- Mocks (draft) -- iterated until PM approves

**PM produces (joint with Designer):**
- Mocks -- PM is gatekeeper; not final until PM sets `Status: Approved`

---

## PM <> EM

**PM provides to EM:**
- PRD, Reqs, Mocks, ACs -- after Mocks are approved; kicks off engineering planning

**EM depends on:**
- PRD, ACs -- approved by PM before authoring Eng Plans (HLD)

---

## PM <> QA

QA does not receive a formal artifact handoff from PM. EM coordinates QA's kickoff and forwards PRD, Mocks, and ACs. QA may ask PM targeted questions about existing PRD/Reqs/ACs content -- read-only clarification only (see Clarification access).

---

## PM <> BE / FE

BE and FE do not receive formal artifact handoffs from PM. EM is the kickoff point and explicitly forwards relevant artifacts. BE and FE may ask PM targeted questions about existing PRD/Reqs/ACs content -- read-only clarification only (see Clarification access).

---

## EM <> Arch

**EM provides to Arch:**
- PRD, ACs -- to scope Sys Arch

**Arch provides to EM:**
- Sys Arch (`generated-docs/architecture/sys-arch.md` + `generated-docs/architecture/sys-arch.html`) -- EM drives the loop; Arch authors and has final say; in agent-to-agent handoffs pass only the `.md` file

**EM depends on:**
- Sys Arch -- approved by Arch before authoring Eng Plans (HLD)
- Arch approval -- any new tech stack or AWS component EM wants to include in HLD requires Arch sign-off first

---

## EM <> DevOps (HLD)

When the deployment target is not local, EM runs a sync loop with DevOps during HLD authoring to validate infra decisions before presenting the HLD for human approval.

**EM provides to DevOps:**
- Draft HLD (infra sections) -- for DevOps review and alignment during authoring

**DevOps provides to EM:**
- Feedback on AMI choices, user_data complexity, SSM wiring, security group rules, and Terraform feasibility -- EM incorporates before finalising HLD

**EM gatekeeps:**
- HLD finalisation -- EM and DevOps must be aligned on infra sections before HLD is submitted for human approval

**DevOps depends on:**
- Finalised HLD -- EM<>DevOps aligned before DevOps begins Deployment Plan

---

## EM <> BE

**EM provides to BE:**
- Eng Plans (HLD) -- approved by EM; unblocks BE Detailed Design
- PRD, Reqs, ACs -- forwarded from PM at kickoff; informs BE Detailed Design scope

**BE provides to EM:**
- BE Detailed Design (`generated-docs/architecture/be-detailed-design.md` + `generated-docs/architecture/be-detailed-design.html`) -- for approval; HTML generated via pandoc per `html-preview-rule.md`; in agent-to-agent handoffs pass only the `.md` file
- Issues List -- submitted for sign-off before GH Issues are created

**EM gatekeeps:**
- BE Detailed Design -- must be approved before BE API implementation or API Contract authoring
- Issues List (BE) -- must be approved before GH Issues are created and implementation begins

**BE depends on:**
- Arch approval -- any new tech stack or AWS component BE wants to introduce requires Arch sign-off before it can be included in BE Detailed Design
- Eng Plans (HLD) -- approved by EM before authoring BE Detailed Design
- BE Detailed Design -- approved by EM before authoring API Contract or beginning implementation
- Issues List -- approved by EM before creating GH Issues and beginning implementation

---

## EM <> FE

**EM provides to FE:**
- Eng Plans (HLD) -- approved by EM; unblocks FE Detailed Design
- PRD, Reqs, ACs -- forwarded from PM at kickoff; informs FE Detailed Design scope
- Mocks -- forwarded from Designer at kickoff; required before component implementation

**FE provides to EM:**
- FE Detailed Design (`generated-docs/architecture/fe-detailed-design.md` + `generated-docs/architecture/fe-detailed-design.html`) -- for approval; HTML generated via pandoc per `html-preview-rule.md`; in agent-to-agent handoffs pass only the `.md` file
- Issues List -- submitted for sign-off before GH Issues are created

**EM gatekeeps:**
- FE Detailed Design -- must be approved before FE implementation or API Contract authoring
- Issues List (FE) -- must be approved before GH Issues are created and implementation begins

**FE depends on:**
- Arch approval -- any new tech stack or library FE wants to introduce requires Arch sign-off before it can be included in FE Detailed Design
- Eng Plans (HLD) -- approved by EM before authoring FE Detailed Design
- PRD, Reqs, ACs -- forwarded by EM at kickoff
- Mocks -- approved by PM; forwarded by EM at kickoff before component implementation
- FE Detailed Design -- approved by EM before authoring API Contract or beginning implementation
- Issues List -- approved by EM before creating GH Issues and beginning implementation

---

## BE <> FE

**Joint output:**
- API Contract (`generated-docs/contracts/api-contract.md` + `generated-docs/contracts/api-contract.html`) -- authored jointly by BE and FE, aligned on their Detailed Designs; submitted to EM for approval; HTML generated via pandoc per `html-preview-rule.md`; in agent-to-agent handoffs pass only the `.md` file

**EM gatekeeps:**
- API Contract -- must be approved before BE endpoint implementation and FE integration begin

**BE and FE each depend on:**
- API Contract -- approved by EM before implementing endpoints (BE) or implementing integration (FE)

---

## EM <> QA

**EM provides to QA:**
- PRD, Mocks, ACs -- forwarded from PM and Designer at kickoff; input to Test Plan authoring
- BE + FE + Swift Detailed Designs -- forwarded by EM once approved; input to detailed QA planning

**QA provides to EM:**
- Test Plan (`generated-docs/qa/test-plan.md` + `generated-docs/qa/test-plan.html`) -- for approval before Issues List authoring; HTML generated via pandoc per `html-preview-rule.md`; in agent-to-agent handoffs pass only the `.md` file
- Issues List -- submitted for sign-off before GH Issues are created
- Automation suite -- for approval before delivery

**EM gatekeeps:**
- Test Plan -- must be approved before QA Issues List authoring
- Issues List (QA) -- must be approved before GH Issues are created and automation begins

**QA depends on:**
- PRD, Mocks, ACs -- forwarded by EM at kickoff before authoring Test Plan
- BE Detailed Design + FE Detailed Design + Swift Detailed Design -- approved and forwarded by EM before beginning detailed QA planning
- Test Plan -- approved by EM before authoring Issues List
- Issues List -- approved by EM before creating GH Issues and beginning implementation

---

## BE <> QA

**BE provides to QA:**
- BE Artifacts + BE Test Docs -- required before QA can author BE automation
- `generated-docs/contracts/openapi.json` -- exported OpenAPI spec (Spring Boot projects only); enables QA to drive contract-level API assertions

**QA depends on from BE:**
- BE Artifacts + BE Test Docs -- received from BE before authoring BE automation
- `generated-docs/contracts/openapi.json` -- Spring Boot projects only; if present, use it to validate response shapes against the spec

---

## FE <> QA

**FE provides to QA:**
- FE Artifacts + FE Test Docs -- required before QA can author FE automation

**QA depends on from FE:**
- FE Artifacts + FE Test Docs -- received from FE before authoring FE automation

**QA produces (from BE + FE + Swift Engineer combined):**
- Automation suite -- gated by EM
- Spec drift GH issues -- filed to PM when PRD differs from working product; to Designer when mocks differ

---

## Designer <> FE

FE does not receive a formal Mocks handoff from Designer. EM forwards approved Mocks to FE at kickoff. FE may ask Designer targeted questions about existing Mocks content -- read-only clarification only (see Clarification access).

---

## EM <> DevOps

**EM provides to DevOps:**
- Eng Plans (HLD) -- approved by EM; unblocks infrastructure provisioning

**DevOps provides to EM:**
- Deployment Plan (`generated-docs/architecture/deployment-plan.md`) -- produced before any provisioning; human-approved gate
- Infrastructure Verification (`generated-docs/ops/infra-verification.md`) -- produced after provisioning and automated checks pass; human-approved gate before stage sign-off
- IaC (Terraform) -- EM is gatekeeper for high-risk or cost-significant changes
- CI/CD pipelines -- EM is gatekeeper for high-risk or cost-significant changes

**DevOps depends on:**
- Arch approval -- any new AWS component or infrastructure service DevOps wants to introduce requires Arch sign-off before provisioning
- Eng Plans (HLD) -- approved by EM before provisioning infrastructure
- Human-approved Deployment Plan -- required before provisioning any infrastructure
- Any high-risk or cost-significant infra change -- requires explicit EM approval before proceeding

---

## DevOps <> BE / FE

**DevOps provides to BE, FE:**
- Deployment targets, environment configs, runbooks -- enables implementation

**DevOps provides to QA:**
- CI gates -- test suites wired into pipeline before QA begins automation

---

## QA <> DevOps (smoke testing)

Applies to non-local deployments only. After infrastructure is provisioned, DevOps and QA run a smoke test loop before the infra-verification human gate.

**DevOps provides to QA:**
- Live server URL -- handed off after deployment; triggers QA smoke run

**QA provides to DevOps:**
- Failing test case name + full error details -- reported directly when any smoke check fails; DevOps remediates before QA re-runs

**QA owns:**
- API-level smoke check -- scripted HTTP calls against the live server covering key flows (e.g. auth, health)
- E2E smoke spec -- headless browser run covering critical UI paths

**Loop exit condition:**
- All smoke checks pass (exit 0) -- QA confirms to DevOps and EM; infra-verification gate opens

**DevOps depends on:**
- QA smoke pass confirmation -- required before Infrastructure Verification artifact is produced and the human gate is opened

**QA depends on:**
- Live server URL from DevOps -- required before smoke run begins

---

## Arch gatekeeping

Arch must approve before any role proceeds with a new tech stack or AWS component.

**Gatekeeps (must approve before downstream proceeds):**
- Tech stack adoption -- any new language, framework, or major library proposed by EM, BE, FE, or Swift Engineer requires Arch approval before use
- AWS component adoption -- any new AWS service or infrastructure component proposed by EM, BE, FE, or DevOps requires Arch approval before provisioning

---

## Clarification access

During planning and implementation, BE, FE, Swift Engineer, QA, and DevOps may ask PM targeted questions about existing PRD/Reqs/ACs content, and ask Designer or macOS Designer targeted questions about existing Mocks content. These are read-only clarifications on artifacts already in scope -- not requirement gathering, not scope discussions, not design revision requests.

If a clarification conversation reveals a gap, missing requirement, or needed design revision, the agent must stop, file it to `BACKLOG.md` per the backlog-reporting-rule (use `type: gap` with the appropriate area: `Spec`, `Mocks`, or `Contract`), and surface it to EM. Agents must not self-resolve or ask PM/Designer to revise artifacts in the moment -- any change to scope or design goes back through EM.

---

## PM <> macOS Designer

**PM provides to macOS Designer:**
- PRD, ACs -- approved by PM; triggers Mock creation

**macOS Designer provides to PM:**
- Mocks (draft) -- iterated until PM approves

**PM produces (joint with macOS Designer):**
- Mocks -- PM is gatekeeper; not final until PM sets `Status: Approved`

---

## EM <> macOS Designer

**EM provides to macOS Designer:**
- PRD, Reqs, ACs -- forwarded from PM at kickoff; informs mock scope
- Mocks -- approved by PM; forwarded by EM at kickoff before any Swift Engineer component work begins

**macOS Designer provides to EM:**
- Component spec (window-level breakdown with AppKit/SwiftUI control mapping) -- for approval before Swift Engineer implementation; delivered alongside or embedded in mocks
- Issues List -- submitted for sign-off before GH Issues are created

**EM gatekeeps:**
- Mocks -- must be approved by PM before Swift Engineer component implementation begins
- Component spec -- must identify the AppKit/SwiftUI control for every UI element before handoff to Swift Engineer
- Issues List (macOS Designer) -- must be approved before GH Issues are created

**macOS Designer depends on:**
- PRD, ACs -- forwarded by EM at kickoff before authoring mocks
- Issues List -- approved by EM before creating GH Issues and beginning implementation

---

## EM <> Swift Engineer

**EM provides to Swift Engineer:**
- Eng Plans (HLD) -- approved by EM; unblocks Swift Engineer Detailed Design
- PRD, Reqs, ACs -- forwarded from PM at kickoff; informs scope
- Mocks + component spec -- forwarded from macOS Designer at kickoff; required before view implementation

**Swift Engineer provides to EM:**
- Detailed Design (`generated-docs/architecture/swift-detailed-design.md` + `generated-docs/architecture/swift-detailed-design.html`) -- for approval; HTML generated via pandoc per `html-preview-rule.md`; in agent-to-agent handoffs pass only the `.md` file
- Issues List -- submitted for sign-off before GH Issues are created

**EM gatekeeps:**
- Swift Engineer Detailed Design -- must be approved before implementation begins
- Issues List (Swift Engineer) -- must be approved before GH Issues are created and implementation begins

**Swift Engineer depends on:**
- Arch approval -- any new framework or external dependency requires Arch sign-off before inclusion in Detailed Design
- Eng Plans (HLD) -- approved by EM before authoring Detailed Design
- Mocks + component spec -- approved by PM and forwarded by EM before view implementation
- Detailed Design -- approved by EM before beginning implementation
- Issues List -- approved by EM before creating GH Issues and beginning implementation

---

## macOS Designer <> Swift Engineer

Swift Engineer does not receive a formal Mocks handoff from macOS Designer. EM forwards approved Mocks and component spec to Swift Engineer at kickoff. Swift Engineer may ask macOS Designer targeted questions about existing Mocks -- read-only clarification only (see Clarification access).

When Swift Engineer identifies a control or behavior that cannot be implemented as specified (SwiftUI limitation, AppKit interop required), they raise a feasibility issue to macOS Designer before implementing a workaround. Any design revision goes back through EM.

---

## Swift Engineer <> QA

**Swift Engineer provides to QA:**
- Swift Engineer Artifacts + Swift Test Docs -- required before QA can author Swift automation
- `accessibilityIdentifier` map -- documents identifiers used in the view layer so QA can write reliable XCUITest selectors

**QA depends on from Swift Engineer:**
- Swift Engineer Artifacts + Swift Test Docs -- received from Swift Engineer before authoring automation
- `accessibilityIdentifier` map -- required before writing XCUITest selectors

---

## EM produces (standalone)

- Plan with Human Gates (`workflow/delivery-tracker.md`) -- progressively filled by EM; seeded at kickoff with initial steps up to PM→EM handoff; after handoff, EM adds arch steps (if needed), HLD, and then the detailed implementation plan (full phase-by-phase breakdown with numbered steps, responsible agents, artifacts, loop exit conditions, and human checkpoints); always add a 👤 human gate after the implementation plan before execution begins; the orchestrator works through it top-to-bottom and stops when it reaches the end, waiting for EM to add the next batch
- Kickoff Plan (`workflow/kickoff-plan.md` + `workflow/kickoff-plan.html`) -- HTML generated via pandoc per `html-preview-rule.md`; orchestrator is author
- Eng Plans (HLD) (`generated-docs/architecture/hld.md` + `generated-docs/architecture/hld.html`) -- HTML generated via pandoc per `html-preview-rule.md`; in agent-to-agent handoffs pass only the `.md` file; EM is gatekeeper
