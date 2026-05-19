<!-- Generated at kickoff from ## Project phases in feature-setup.md. -->
<!-- Progressively filled by EM after the implementation plan is approved. -->
<!-- The orchestrator works through this top-to-bottom. When it runs out of steps, it stops. -->

## Delivery Plan

[ ]  not started   |   [-]  skipped   |   [x]  done

---

### Stage 1: Discovery

- [x] **Requirements Finalization**
  - [x] **PM:** review PRD with human, surface open questions, confirm scope → [PRD](../product-specs/prd.md) -- done when: PRD body written and human approves
  - [x] 👤💾 **HUMAN:** review and approve PRD

---

### Stage 2: Design

- [x] **UI / UX Design**
  - [x] **macOS DESIGNER:** produce HIG-compliant mocks → [Mocks](../generated-docs/design/) -- done when: mocks present in generated-docs/design/ and human approves
  - [x] 👤💾 **HUMAN:** review and approve mocks

---

### Stage 3: Technical Planning

- [x] **Engineering Kickoff**
  - [x] **EM:** decide on architecture engagement → confirmed: Arch skipped (no new infra, no unfamiliar tech) -- done when: decision recorded here

- [-] **System Architecture** -- SKIPPED (no new infrastructure or unfamiliar technology)

- [x] **High-Level Design**
  - [x] **EM:** produce high-level design → [Eng Plans (HLD)](../generated-docs/architecture/hld.md) -- done when: Status: Approved — EM set in file
  - [x] 👤💾 **HUMAN:** review and approve high-level design

- [x] **Implementation Plan**
  - [x] **EM:** produce detailed implementation plan → [Implementation Plan](../workflow/implementation-plan.md) -- done when: Status: Approved — EM set in file
  - [x] 👤💾 **HUMAN:** review and approve implementation plan
  - [x] **EM:** seed approved steps into Stage 4 and Stage 5 of this tracker

---

### Stage 4: Engineering

- [-] **BE Detailed Design** -- SKIPPED (no backend)
- [-] **FE Detailed Design** -- SKIPPED (no web frontend)
- [-] **API Contract** -- SKIPPED (no backend/frontend)
- [-] **BE Issues List** -- SKIPPED (no backend)
- [-] **Backend Development** -- SKIPPED (no backend)
- [-] **FE Issues List** -- SKIPPED (no web frontend)
- [-] **Frontend Development** -- SKIPPED (no web frontend)
- [-] **Infrastructure** -- SKIPPED (deployment target: local)

- [x] **Swift Detailed Design**
  - [x] **4.1 SWIFT ENGINEER:** produce Swift Detailed Design → [Swift Detailed Design](../generated-docs/architecture/swift-detailed-design.md) -- done when: file exists with all required sections
  - [x] **4.2 💾 EM:** review and approve Swift Detailed Design -- done when: Status: Approved — EM set in file; all ACs addressed

- [x] **Component Spec**
  - [x] **4.3 macOS DESIGNER:** finalise component spec → [Component Spec](../generated-docs/design/component-spec.md) -- done when: spec maps every UI element to SwiftUI control, semantic color, and spacing value

- [x] **Swift Engineer Issues List**
  - [x] **4.4 EM:** produce and approve Swift Engineer Issues List -- done when: Status: Approved — EM set in list; one issue per logical unit
  - [x] **4.5 SWIFT ENGINEER:** create GitHub Issues from approved list -- done when: all issues exist in GitHub with correct labels

- [x] **macOS Development**
  - [x] **4.6 SWIFT ENGINEER:** implement Track 1 UI changes → `MacRecordWidget/MacRecordWidgetApp.swift` -- done when: AC-UI-1 through AC-UI-6 satisfied; builds clean; verified against mocks
  - [x] **4.7 SWIFT ENGINEER:** implement Track 2 Swift modernization → `MacRecordWidget/` -- done when: AC-SW-1 through AC-SW-8 satisfied; builds clean on macOS 14 SDK; CI passes
  - [x] **4.8 💾 EM:** review and approve Swift Engineer implementation -- done when: all ACs verified; no open blockers

---

### Stage 5: Quality Assurance

- [-] **QA Issues List** -- SKIPPED (manual smoke testing only)

- [x] **Test Planning**
  - [x] **5.1 QA:** produce manual smoke test plan → [Test Plan](../generated-docs/qa/test-plan.md) -- done when: file exists covering all smoke scenarios; scope: manual only, no XCUITest automation
  - [x] **5.2 💾 EM:** review and approve test plan -- done when: Status: Approved — EM set in file; every AC maps to at least one scenario

- [x] **Test Execution**
  - [x] **5.3 QA:** execute manual smoke tests -- SKIPPED: human elected to skip formal smoke test execution and proceed directly to completion
  - [x] **5.4 💾 EM:** review and approve test results -- SKIPPED: human elected to skip formal smoke test execution and proceed directly to completion

---

### Stage 6: Master Baseline Update

- [x] **PM:** merge this feature's PRD into `projects/master/product-specs/prd.md` -- done when: master PRD reflects this feature → [projects/master/product-specs/prd.md](../../../projects/master/product-specs/prd.md)
- [x] **macOS DESIGNER:** merge this feature's mocks into `projects/master/mocks/` -- done when: master mocks reflect updated UI → [projects/master/mocks/](../../../projects/master/mocks/)
- [x] 👤💾 **HUMAN:** confirm master is current -- SKIPPED: human elected to move past this gate

---

### Stage 7: README and CLAUDE.md

- [x] **EM:** update `README.md` and `CLAUDE.md` to reflect production-polish changes -- done when: both files updated at repo root → [README.md](../../../README.md), [CLAUDE.md](../../../CLAUDE.md)
- [x] 👤💾 **HUMAN:** review and approve README and CLAUDE.md

---

### Stage 8: Release

- [x] **Phase Sign-off**
  - [x] **EM:** verify all artifacts complete and approved
  - [x] 👤💾 **HUMAN:** review and approve release readiness
