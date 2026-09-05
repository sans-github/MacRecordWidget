<!-- Generated at kickoff from ## Project phases in feature-setup.md. -->
<!-- Progressively filled by EM after the implementation plan is approved. -->
<!-- The orchestrator works through this top-to-bottom. When it runs out of steps, it stops. -->

## Delivery Plan

[ ]  not started   |   [-]  skipped   |   [x]  done

Originally configured as a design-only pass (Stages 3, 4 and 5 skipped). After design sign-off the human asked for the feature to be built, so implementation happened out of band on 2026-09-04 without re-running the skipped stages. Stage 4 is recorded below as done-out-of-band with what actually shipped; Stages 3 and 5 remain genuinely skipped, meaning there is no technical design document and no test coverage for this feature.

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

- [x] **UI / UX Design**
  - [x] 💾 **macOS DESIGNER:** produce mocks at the approved L size (480x270 preview, 504x346 panel) → [generated-docs/design/index.html](../generated-docs/design/index.html) -- done when: mocks cover the default, permission-denied, no-camera, and disconnected states, plus the camera picker, mirror toggle, and passive camera-name indicator
  - [x] 👤💾 **HUMAN:** review and approve mocks -- done when: human approves

### Stage 3: Technical Planning

- [-] SKIPPED -- phase config, design-only pass

### Stage 4: Engineering

- [x] **macOS Development** -- DONE OUT OF BAND 2026-09-04, at the human's request after design sign-off. No detailed design or issues list was produced; the approved PRD and mocks were implemented directly.
  - [x] 💾 `@MainActor` prerequisite on `RecordingManager` landed as its own change first (commit `dec5c79`) -- done when: isolation fixed before any capture code
  - [x] 💾 Live camera preview implemented: `CameraManager.swift`, `CameraPreviewView.swift`, `PanelSizer.swift`, `NSCameraUsageDescription` -- done when: CI green and installed
  - [x] 💾 Panel sizing corrected: shrink-back, padding order, trailing alignment, right-alignment to the screen edge -- done when: verified on hardware by the human
  - [x] 👤 **HUMAN:** confirmed the preview works on device -- done when: human confirms ("Ok that worked")
  - [x] 💾 Post-ship UI revisions, driven directly by the human: fixed 504pt panel width to kill the reposition flicker; camera picker moved into the button row; mirror toggle removed and mirroring hardcoded on; record and stop collapsed into one tinted toggle; uniform glyph sizing and a constant outline on every control
  - [x] 💾 **Photo Booth launch removed.** The camera toggle had been doing two jobs (show preview, capture video), which surprised the human. Recording is now audio only. NOTE: the app consequently has NO video capture at all -- a real product gap, logged to `BACKLOG.md`
  - [x] 💾 Docs resynced to the shipped UI: `CLAUDE.md`, `README.md`, `projects/master/`

### Stage 5: Quality Assurance

- [-] SKIPPED -- phase config. NOTE: the feature shipped without any test coverage. There are no unit tests for `CameraManager`'s permission, fallback or persistence logic, and no QA pass against the PRD's acceptance criteria. This is a known gap, not an oversight of the tracker.

### Stage 6: Master Baseline Update

- [x] 💾 **PM:** merge this feature's PRD into `projects/master/product-specs/prd.md` → [projects/master/product-specs/prd.md](../../master/product-specs/prd.md) -- done when: master PRD includes the live camera preview
- [x] 💾 **DESIGNER / macOS DESIGNER:** merge this feature's mocks into `projects/master/mocks/` → [projects/master/mocks/index.html](../../master/mocks/index.html) -- done when: master mocks include the preview panel
- [x] 👤💾 **HUMAN:** confirm master is current -- done when: human confirms

### Stage 7: README and CLAUDE.md

- [-] **EM:** generate `scripts/dev.sh` -- SKIPPED (Xcode app, no BE/FE processes to run; kickoff plan Q3)
- [x] 💾 **EM:** update `README.md` and `CLAUDE.md` to document the design intent, clearly marked as not implemented -- done when: both files describe the feature and its not-implemented status
- [x] 👤💾 **HUMAN:** review and approve README and CLAUDE.md -- done when: human approves

### Stage 8: Release

- [ ] **Design Sign-off** (redefined from release readiness for this design-only pass)
  - [x] 💾 **EM:** verify all design artifacts are complete and approved -- done when: PRD, mocks, and master baseline are all approved
    - Verified 2026-09-04 by the orchestrator, NOT by EM: the specialist agents were unavailable in the resumed session. Kickoff plan and PRD both stamped `Approved — Human`; 7 feature mock pages present and approved at the Stage 2 gate; master PRD carries 15 `[DESIGN ONLY — NOT SHIPPED]` markers and 5 master mock pages carry `[NOT SHIPPED]` in their titles; `MacRecordWidget/` sources and `Info.plist` unchanged, as a design-only pass requires.
    - Signed off with three assumptions UNVERIFIED: panel trailing-edge pinning and ~304pt leftward growth; whether a `MenuBarExtra(.window)` panel animates or snaps a width change; whether this app and Photo Booth can hold the same camera simultaneously on macOS 14 (the "preview keeps running during recording" decision depends on it).
  - [ ] 👤💾 **HUMAN:** review and approve design sign-off -- done when: human approves
