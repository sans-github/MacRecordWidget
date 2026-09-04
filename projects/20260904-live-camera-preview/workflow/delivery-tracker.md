<!-- Generated at kickoff from ## Project phases in feature-setup.md. -->
<!-- Progressively filled by EM after the implementation plan is approved. -->
<!-- The orchestrator works through this top-to-bottom. When it runs out of steps, it stops. -->

## Delivery Plan

[ ]  not started   |   [-]  skipped   |   [x]  done

Design-only pass. Stages 3, 4, and 5 are skipped by the human's phase config, so no Swift implementation or tests are produced. Stage 7 documents design intent only; Stage 8 is design sign-off, not release readiness (kickoff plan Q3).

### Stage 0: Master Baseline Backfill

Prerequisite added at kickoff. `projects/master/` predates the shipped `20260521-popover-button-layout` feature, and `product-baseline-rule.md` hard-blocks PM and Designer until it is current (kickoff plan Q1).

- [x] **Master Baseline Backfill**
  - [x] 💾 **PM:** merge the shipped `20260521-popover-button-layout` PRD into `projects/master/product-specs/prd.md` → [projects/master/product-specs/prd.md](../../master/product-specs/prd.md) -- done when: master PRD describes the single-row popover (video toggle, record, stop, power)
  - [x] 💾 **DESIGNER:** merge the shipped `20260521-popover-button-layout` mocks into `projects/master/mocks/` → [projects/master/mocks/index.html](../../master/mocks/index.html) -- done when: a master mock reflects the current single-row button layout
  - [x] 👤💾 **HUMAN:** confirm the master baseline is current before Stage 1 begins -- done when: human confirms

### Stage 1: Discovery

- [x] **Requirements Finalization**
  - [x] 💾 **PM:** author the full PRD from the captured requirements and the seven resolved kickoff questions → [product-specs/prd.md](../product-specs/prd.md) -- done when: PRD body written, HTML preview generated, first `##` heading is `## Goals`
  - [x] 👤💾 **HUMAN:** review and approve PRD -- done when: human approves

### Stage 2: Design

- [ ] **UI / UX Design**
  - [ ] 💾 **macOS DESIGNER:** produce mocks at the approved L size (480x270 preview, 504x346 panel) → `projects/20260904-live-camera-preview/generated-docs/design/` -- done when: mocks cover the default, permission-denied, no-camera, and disconnected states, plus the camera picker, mirror toggle, and passive camera-name indicator
  - [ ] 👤💾 **HUMAN:** review and approve mocks -- done when: human approves

### Stage 3: Technical Planning

- [-] SKIPPED -- phase config, design-only pass

### Stage 4: Engineering

- [-] SKIPPED -- phase config, design-only pass. No Swift implementation in this pass. The `@MainActor` isolation fix on `RecordingManager` is recorded in the PRD as a prerequisite for whenever implementation happens (kickoff plan Q4).

### Stage 5: Quality Assurance

- [-] SKIPPED -- phase config, design-only pass

### Stage 6: Master Baseline Update

- [ ] 💾 **PM:** merge this feature's PRD into `projects/master/product-specs/prd.md` -- done when: master PRD includes the live camera preview
- [ ] 💾 **DESIGNER / macOS DESIGNER:** merge this feature's mocks into `projects/master/mocks/` -- done when: master mocks include the preview panel
- [ ] 👤💾 **HUMAN:** confirm master is current -- done when: human confirms

### Stage 7: README and CLAUDE.md

- [-] **EM:** generate `scripts/dev.sh` -- SKIPPED (Xcode app, no BE/FE processes to run; kickoff plan Q3)
- [ ] 💾 **EM:** update `README.md` and `CLAUDE.md` to document the design intent, clearly marked as not implemented -- done when: both files describe the feature and its not-implemented status
- [ ] 👤💾 **HUMAN:** review and approve README and CLAUDE.md -- done when: human approves

### Stage 8: Release

- [ ] **Design Sign-off** (redefined from release readiness for this design-only pass)
  - [ ] 💾 **EM:** verify all design artifacts are complete and approved -- done when: PRD, mocks, and master baseline are all approved
  - [ ] 👤💾 **HUMAN:** review and approve design sign-off -- done when: human approves
