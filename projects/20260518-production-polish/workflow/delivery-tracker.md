<!-- Generated at kickoff from ## Project phases in feature-setup.md. -->
<!-- Progressively filled by EM after the implementation plan is approved. -->
<!-- The orchestrator works through this top-to-bottom. When it runs out of steps, it stops. -->

## Delivery Plan

[ ]  not started   |   [-]  skipped   |   [x]  done

---

### Stage 1: Discovery

- [ ] **Requirements Finalization**
  - [ ] **PM:** review PRD with human, surface open questions, confirm scope → [PRD](../product-specs/prd.md) -- done when: PRD body written and human approves
  - [ ] 👤💾 **HUMAN:** review and approve PRD

---

### Stage 2: Design

- [ ] **UI / UX Design**
  - [ ] **macOS DESIGNER:** produce HIG-compliant mocks → [Mocks](../generated-docs/design/) -- done when: mocks present in generated-docs/design/ and human approves
  - [ ] 👤💾 **HUMAN:** review and approve mocks

---

### Stage 3: Technical Planning

- [ ] **Engineering Kickoff**
  - [ ] **EM:** decide on architecture engagement → confirmed: Arch skipped (no new infra, no unfamiliar tech)

- [-] **System Architecture** -- SKIPPED (no new infrastructure or unfamiliar technology)

- [ ] **High-Level Design**
  - [ ] **EM:** produce high-level design → [Eng Plans (HLD)](../generated-docs/architecture/hld.md) -- done when: Status: Approved — EM set in file
  - [ ] 👤💾 **HUMAN:** review and approve high-level design

- [ ] **Implementation Plan**
  - [ ] **EM:** produce detailed implementation plan → [Implementation Plan](../workflow/implementation-plan.md) -- done when: Status: Approved — EM set in file
  - [ ] 👤💾 **HUMAN:** review and approve implementation plan
  - [ ] **EM:** seed approved steps into Stage 4 and Stage 5 of this tracker

---

### Stage 4: Engineering
> EM fills in detailed steps after Implementation Plan is approved.

- [ ] **Swift Detailed Design**
  - [ ] **SWIFT ENGINEER:** produce detailed design → [Swift Detailed Design](../generated-docs/architecture/swift-detailed-design.md) -- done when: Status: Approved — EM set in file
  - [ ] 💾 **EM:** review and approve Swift detailed design

- [-] **BE Detailed Design** -- SKIPPED (no backend)
- [-] **FE Detailed Design** -- SKIPPED (no web frontend)
- [-] **API Contract** -- SKIPPED (no backend/frontend)
- [-] **BE Issues List** -- SKIPPED (no backend)
- [-] **Backend Development** -- SKIPPED (no backend)
- [-] **FE Issues List** -- SKIPPED (no web frontend)
- [-] **Frontend Development** -- SKIPPED (no web frontend)
- [-] **Infrastructure** -- SKIPPED (deployment target: local)

- [ ] **Swift Engineer Issues List**
  - [ ] **EM:** produce and approve Swift Engineer issues list -- done when: Status: Approved — EM set in list

- [ ] **macOS Development**
  - [ ] **macOS DESIGNER:** finalise component spec from approved mocks -- done when: spec present in generated-docs/design/
  - [ ] **SWIFT ENGINEER:** implement SwiftUI views per approved mocks and component spec → `MacRecordWidget/` -- done when: all HIG/visual changes in place
  - [ ] **SWIFT ENGINEER:** refactor RecordingManager to @Observable, async/await, typed errors, bump deployment target to 14.0 → `MacRecordWidget/` -- done when: builds clean, no warnings
  - [ ] **SWIFT ENGINEER:** resolve popover dismissal per agreed approach in Swift Detailed Design -- done when: no orderOut hack remains
  - [ ] 💾 **EM:** review and approve Swift Engineer implementation -- done when: Status: Approved — EM set in artifact

---

### Stage 5: Quality Assurance

- [ ] **Test Planning**
  - [ ] **QA:** produce manual smoke test plan → [Test Plan](../generated-docs/qa/test-plan.md) -- done when: Status: Approved — EM set in file; scope: manual only, no XCUITest automation
  - [ ] 💾 **EM:** review and approve test plan

- [-] **QA Issues List** -- SKIPPED (manual smoke testing only)

- [ ] **Test Execution**
  - [ ] **QA:** execute manual smoke tests against macOS app -- done when: all smoke test cases pass
  - [ ] 💾 **EM:** review and approve test results

---

### Stage 6: Master Baseline Update

- [ ] **PM:** merge this feature's PRD into `projects/master/product-specs/prd.md` -- done when: master PRD reflects this feature
- [ ] **macOS DESIGNER:** merge this feature's mocks into `projects/master/mocks/` -- done when: master mocks reflect updated UI
- [ ] 👤💾 **HUMAN:** confirm master is current

---

### Stage 7: README and CLAUDE.md

- [ ] **EM:** update `README.md` and `CLAUDE.md` to reflect production-polish changes -- done when: both files updated at repo root
- [ ] 👤💾 **HUMAN:** review and approve README and CLAUDE.md

---

### Stage 8: Release

- [ ] **Phase Sign-off**
  - [ ] **EM:** verify all artifacts complete and approved
  - [ ] 👤💾 **HUMAN:** review and approve release readiness
