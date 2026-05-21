<!-- Generated at kickoff from ## Project phases in feature-setup.md. -->
<!-- Progressively filled by EM after the implementation plan is approved. -->
<!-- The orchestrator works through this top-to-bottom. When it runs out of steps, it stops. -->

## Delivery Plan

[ ]  not started   |   [-]  skipped   |   [x]  done

---

### Stage 1: Discovery

- [x] **Requirements Finalization**
  - [x] **PM:** review PRD with human, surface open questions, confirm scope → [PRD](../product-specs/prd.md) -- done when: full PRD written to file and human approves
  - [x] 👤💾 **HUMAN:** review and approve PRD -- done when: human confirms approval verbally

---

### Stage 2: Design

- [ ] **UI / UX Design**
  - [ ] **DESIGNER:** produce mocks → [Mocks] -- done when: HTML mocks present in generated-docs/design/ and human approves
  - [ ] 👤💾 **HUMAN:** review and approve mocks -- done when: human confirms approval verbally

---

### Stage 3: Technical Planning

- [ ] **Engineering Kickoff**
  - [ ] **EM:** decide on architecture engagement → [Feature Setup](feature-setup.md) -- done when: decision recorded (Arch skipped per kickoff plan; no new infra)

- [ ] **High-Level Design**
  - [ ] **EM:** produce high-level design → [Eng Plans (HLD)] -- done when: hld.md and hld.html present in generated-docs/architecture/ and Status: Approved — EM set in file

- [ ] **Implementation Plan**
  - [ ] **EM:** produce detailed implementation plan → [Implementation Plan](../workflow/implementation-plan.md) -- done when: implementation-plan.md and implementation-plan.html present in workflow/ and human approves
  - [ ] 👤💾 **HUMAN:** review and approve implementation plan -- done when: human confirms approval verbally
  - [ ] **EM:** seed approved steps into Stage 4 and Stage 5 of delivery-tracker.md -- done when: Stage 4 steps are filled in below

---

### Stage 4: Engineering

> Skeleton -- EM fills in these steps after Implementation Plan is approved.

- [ ] **Swift Engineer Issues List**
  - [ ] **EM:** produce and approve Swift Engineer issues list -- done when: Status: Approved — EM set in list; Swift Engineer creates GH issues and begins implementation

- [ ] **macOS Development**
  - [ ] **SWIFT ENGINEER:** implement SwiftUI view changes per approved mocks → `src/` -- done when: layout changes committed (horizontal button row, dot removed, buttons shifted up)
  - [ ] **SWIFT ENGINEER:** implement stopRecording() behavior change → `src/` -- done when: stopRecording() fires Stop shortcut only; Photo Booth not closed; change committed
  - [ ] 💾 **EM:** review and approve Swift Engineer implementation -- done when: Status: Approved — EM set in artifact

---

### Stage 5: Quality Assurance

> Stage 5 is [-] -- skipped entirely per feature-setup.md.

---

### Stage 6: Master Baseline Update

- [ ] **PM:** merge this feature's PRD into `projects/master/product-specs/prd.md` -- done when: master PRD reflects this feature's changes
- [ ] **DESIGNER / macOS DESIGNER:** merge this feature's mocks into `projects/master/mocks/` -- done when: master mocks reflect the current live UI
- [ ] 👤💾 **HUMAN:** confirm master is current -- done when: human confirms

---

### Stage 7: README and CLAUDE.md

- [ ] **EM:** run `/document-release` skill to update `README.md` and `CLAUDE.md` -- done when: both files exist at repo root and reflect all shipped features
- [ ] 👤💾 **HUMAN:** review and approve README and CLAUDE.md -- done when: human confirms

---

### Stage 8: Release

- [ ] **Phase Sign-off**
  - [ ] **EM:** verify all artifacts complete and approved, confirm deployment target is ready -- done when: all prior stages checked off
  - [ ] 👤💾 **HUMAN:** review and approve release readiness -- done when: human confirms
