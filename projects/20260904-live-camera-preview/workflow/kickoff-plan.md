> Status: Approved — Human
> Approved: 2026-09-04

# Kickoff Plan: Live Camera Preview

**Feature folder:** `projects/20260904-live-camera-preview`
**Prepared by:** EM
**Date:** 2026-09-04

## Summary

MacRecordWidget is a two-file SwiftUI menu bar app whose popover is currently a single 200pt-wide row of four controls. This feature adds a live camera preview underneath that row: flipping the video toggle on opens a 480x270pt (16:9) preview so the user can frame the shot before recording, instead of finding out the angle was wrong once Photo Booth is already rolling. The preview is display-only — Photo Booth remains the actual capturer and the preview never writes a file. Two new persisted user controls come with it: a camera picker across connected devices and a mirror toggle (default on). The camera session starts on toggle-on, stops when the popover closes, and resumes on reopen. Permission, no-camera, and disconnected-mid-session states all degrade to an inline message and must never block the record or stop buttons.

**This is a design-only pass.** `feature-setup.md` has Stage 3 (Technical Planning), Stage 4 (Engineering), and Stage 5 (QA) marked `[-]`. Active stages are 1, 2, 6, 7, and 8. No Swift code will be written in this pass. The output is an approved PRD and an approved set of mocks, merged into the master baseline, with documentation and sign-off closing the pass.

### Delivery phases

| Stage | Status | What it produces | Owner |
|---|---|---|---|
| 1. Discovery | Active | Full PRD from the requirements frontmatter | PM 👤 |
| 2. Design | Active | Mocks for all preview states and controls | macOS Designer 👤 |
| 3. Technical Planning | Skipped | — | — |
| 4. Engineering | Skipped | — | — |
| 5. Quality Assurance | Skipped | — | — |
| 6. Master Baseline Update | Active (never skippable) | Merged master PRD + master mocks | PM + macOS Designer 👤 |
| 7. README and CLAUDE.md | Active (never skippable) | Docs updated | EM 👤 |
| 8. Release | Active (never skippable) | Sign-off | EM 👤 |

### Key risks at a glance

| | Risk | Why it matters |
|--|---|---|
| 🔴 | Master baseline is stale | The previous feature (`20260521-popover-button-layout`) shipped code but never ran its Stage 6. `projects/master/` does not describe the single-row popover this feature builds on. `product-baseline-rule.md` hard-blocks PM and Designer on this. |
| 🟡 | Stage 8 active while Stage 5 skipped | Broken stage dependency by construction. Stages 6/7/8 cannot be turned off. Needs a redefined meaning, not a halt. |
| 🟡 | Four open `RecordingManager` defects | The preview adds AVFoundation and more concurrency to the same class that already has an off-main-actor mutation bug. |
| 🟡 | No `NSCameraUsageDescription`, no persistence layer | Both are hard engineering prerequisites with no home in this pass, since Stage 4 is off. |
| 🟢 | Panel resize 200pt → 504pt | Unresolved design question carried over from the size study. |

---

## 1. What I understood

### Big picture

The video toggle currently does one thing: it decides whether `startRecording()` also launches Photo Booth. This feature gives that toggle a second, immediate consequence — it opens an AVFoundation capture preview inside the popover itself. The preview is a parallel, read-only view of a camera device; it does not participate in recording at all. That separation is the whole design: the preview is a framing aid, Photo Booth is the recorder, and the two are deliberately allowed to disagree about which camera they are using. The panel grows from 200x~76pt to 504x346pt while the toggle is on and collapses when it is off. Two persisted settings (selected camera, mirror on/off) are new state the app has nowhere to put today.

### Folder structure check

| Required | Present |
|---|---|
| `projects/20260904-live-camera-preview/workflow/feature-setup.md` | ✅ |
| `projects/20260904-live-camera-preview/product-specs/prd.md` | ✅ |
| `projects/20260904-live-camera-preview/generated-docs/design/` | ✅ (contains `preview-size-study.html`) |

All required paths exist. `workflow/delivery-tracker.md` also exists, seeded with only the legend line — expected, and not seeded further until this plan is approved.

### Input quality check

**Clean:**

- `prd.md` contains a requirements frontmatter block and no PRD body. This is the expected post-`/feature-init` state. Not flagged, PM not invoked; Stage 1 produces the full PRD.
- No unfilled placeholders, `TODO`, or `TBD` in `feature-setup.md` or `prd.md`.
- Deployment target is `local`, consistent with a menu bar app built unsigned via GitHub Actions. No DevOps or infra work in scope.
- The settled decisions in the frontmatter (preview below the row, size L, preview live during recording, session stops on popover close, mirror toggle default on, camera picker in scope, picker affects preview only) are internally consistent and consistent with the current code.

**🔴 Blocker — master baseline is stale.** `projects/master/` was last updated 2026-05-19. The `20260521-popover-button-layout` feature shipped after that (commits `bb6cfa4`, `ab33c53`) and its Stage 6 is still unchecked in `projects/20260521-popover-button-layout/workflow/delivery-tracker.md`. Neither `projects/master/product-specs/prd.md` nor any file in `projects/master/mocks/` mentions the single-row button layout that is now live. `product-baseline-rule.md` states PM must not author a new PRD and Designer must not create new mocks until master is current. Since this feature's preview sits directly below that button row, the mocks would be drawn against a baseline that does not exist in the product. See open question 1 — this needs a human decision before Stage 1 starts.

**🟡 Broken stage dependency (documented, not blocking).** `feature-setup.md` has Stage 8 Release active with Stage 5 QA skipped, which the kickoff prompt would normally block on. Stages 6, 7, and 8 are never-skippable by rule, so this cannot be resolved by toggling. It is an inherent consequence of a design-only pass, not a configuration mistake. Proposed handling is in Risks below.

**🟡 Two design questions left open in the frontmatter.** The Designer already raised, and did not resolve: (a) the panel resizing 200pt → 504pt on every toggle flip, and (b) the permission-denied and no-camera states not being covered by the size study. Both land inside Stage 2, but (a) needs a human call because it changes the resting state of the panel — see open question 2.

**Not a contradiction, but worth stating:** the human chose preview size L over the Designer's M recommendation after reviewing `generated-docs/design/preview-size-study.html`. That decision is settled and Stage 2 will not reopen it.

### Risks and unknowns

**1. Stage 8 Release with no implementation to release (🟡).**
Stage 5 QA is skipped and Stage 4 produces no code, so there is nothing to test and nothing to ship. Rather than halt, I propose redefining Stages 7 and 8 for this pass:

- **Stage 7** — `README.md` and `CLAUDE.md` are updated to describe the *approved design intent* for the live camera preview, clearly marked as designed-not-yet-implemented, plus the recorded engineering prerequisites (`NSCameraUsageDescription`, persistence location, AVFoundation adoption). No claim that the feature exists in the shipped app. The `scripts/dev.sh` step in Stage 7 does not apply — this is an Xcode app with no BE or FE processes to spawn, and per project memory nothing is built locally. It should be marked SKIPPED with that reason when the tracker is seeded.
- **Stage 8** — becomes **design sign-off**, not release readiness. EM verifies that the PRD and mocks are approved, that every state in the PRD has a mock, that master is current, and that the open engineering prerequisites are documented and carried forward. The human approves that the design is complete and ready for a future implementation pass. No build, no artifact, no version bump.

I want this confirmed explicitly (open question 3) rather than assumed, because "release" appearing checked in the tracker could later be misread as "the feature shipped."

**2. Existing `RecordingManager` defects intersect this feature directly (🟡).**
Four items were logged to `BACKLOG.md` triage today against `MacRecordWidget/RecordingManager.swift`:

| Item | Interaction with this feature |
|---|---|
| Class is not `@MainActor`; `isRecording`/`isInFlight` mutate off-main | **Highest relevance.** The preview adds an `AVCaptureSession` (which must be configured and started off the main thread) plus new observable state (`selectedDeviceID`, `mirrored`, permission status, session running). Building that on top of a class that already races is how you get intermittent UI bugs that are very hard to reproduce. Whoever implements the preview should fix the actor isolation **first**, as a prerequisite, not alongside. |
| `NSWorkspace.open` returning true proves nothing about the Shortcut existing | Unrelated to the preview. Independent fix, no sequencing constraint. |
| Dead `RecordingError.accessibilityDenied` case | Mildly relevant: this feature introduces a *real* permission-denied path (camera). Leaving a stale accessibility-denied error next to a new camera-denied error invites confusion in the error enum and the alert copy. Cheap to remove while the error surface is being touched. |
| Locale-dependent recording filename | Unrelated. Independent fix. |

My recommendation: fix the `@MainActor` isolation and delete the dead error case as a prerequisite to any preview implementation; treat the other two as independent backlog items on their own schedule. **None of this can happen in this pass** — Stage 4 is off. So the concrete ask is that these be recorded as sequencing constraints in the PRD's engineering-prerequisites section, so the future implementation pass inherits them. Open question 4 confirms this.

**3. Engineering prerequisites with no home in a design-only pass (🟡).**
Two hard prerequisites exist and neither has an owner in the active stages:

- `MacRecordWidget/Info.plist` currently contains only `LSUIElement`. There is no `NSCameraUsageDescription`. Without it, the first `AVCaptureDevice.requestAccess(for: .video)` call causes an immediate crash, not a denial. This is not optional and not a nicety.
- The app has no persistence of any kind today — no `UserDefaults` usage, no SwiftData, no settings store. The mirror toggle and camera selection both must survive relaunch.

Since Stage 3 and 4 are skipped, these must be captured as an explicit "engineering prerequisites" section in the PRD so they are not rediscovered later. They should not be quietly implemented in this pass.

**4. Panel resize behavior is unresolved (🟢).**
A 200pt → 504pt jump on every toggle flip is a 2.5x width change in a menu bar panel anchored to the status item. Two viable directions, both for the Designer to mock, but the choice affects the idle appearance of the app: a permanently 504pt-wide panel (stable, but a large idle footprint for four buttons) versus an animated resize gated on `accessibilityReduceMotion` (small at rest, motion on every flip). Open question 2.

**5. Source layout deviates from the documented convention (🟢).**
`tech-config.md` and the EM hard constraints say source code lives under `src/`. In this repo `src/` is empty and the Swift sources live in `MacRecordWidget/` alongside `MacRecordWidget.xcodeproj`, which is the standard Xcode layout. This predates the feature and is not something to change here — relocating source files would require rewriting the Xcode project's file references for no functional gain. I am flagging it so it is a recorded, deliberate exception rather than drift, and recommending it be logged to `BACKLOG.md` triage (Area: `Swift`, Type: `debt`) and reflected in `tech-config.md` at some point. Open question 7.

**6. `tech-config.md` impact assessment.**
`tech-config.md` has not changed for this feature and this feature does not require a change to it. The macOS row (Swift 5.10 + SwiftUI, Observation, SwiftData, URLSession) still covers the work. No refactor, no regression risk from config drift. The only caveat is the SwiftData-versus-`@AppStorage` question in the stack section below, which is a within-platform choice, not a config change.

**7. Known limitation accepted by the human.**
The camera picker affects the preview only. Photo Booth records from whatever camera Photo Booth is set to, which may be a different device. The human accepted this and asked for no user-facing warning. The residual risk is a support-style complaint ("I previewed my BRIO but the recording is the FaceTime camera"). It is documented in the PRD as a limitation and that is the extent of the mitigation. Open question 6 confirms the design carries no affordance at all.

### Out of scope

- **Any Swift implementation.** Stages 3, 4, and 5 are skipped. No code, no detailed design, no HLD, no tests are produced in this pass.
- **System architecture and technical planning.** Stage 3 skipped — no `sys-arch.md`, no `hld.md`, no `implementation-plan.md`.
- **QA.** No test plan, no XCUITests, no automation. Stage 5 skipped.
- **Recording via the preview.** The preview never writes a file. Photo Booth remains the sole capturer.
- **Changing what Photo Booth records.** The camera picker does not drive Photo Booth's device selection.
- **Audio.** No audio monitoring, level meters, or microphone selection.
- **Backend, frontend, database, infrastructure.** None exist and none are added. Deployment target is `local`.
- **Signing, notarization, distribution.** CI continues to build unsigned.
- **Fixing the `RecordingManager` backlog items.** Recorded as prerequisites for a future pass, not fixed here.
- **Full-screen Photo Booth, Accessibility permission.** Deliberately removed previously; stays removed.

### Software stack

An existing stack is in place. Confirmed by inspecting the repo:

| Layer | Technology | Notes |
|---|---|---|
| macOS app | Swift 5.10 + SwiftUI, `MenuBarExtra(.window)` | `MacRecordWidget/MacRecordWidgetApp.swift` (146 lines) |
| State | Observation framework (`@Observable`) | `MacRecordWidget/RecordingManager.swift` (84 lines) |
| Integration | `NSWorkspace.open` against `shortcuts://` URLs | Requires user-created "Start" and "Stop" Shortcuts |
| Build | Xcode project, GitHub Actions, unsigned artifact | Deployment target macOS 14.0 |
| Persistence | **None today** | New requirement from this feature |
| Tests | **None** | Stage 5 skipped; not added here |
| BE / FE / DB / Infra | Not present, not needed | `src/` is empty |

This matches the `macOS` row of `tech-config.md`. No layer is missing for the requirements, and nothing in the PRD is unaddressable with this stack.

**Additions this feature implies, with my assessment:**

- **AVFoundation** — required for `AVCaptureSession`, `AVCaptureVideoPreviewLayer`, and `AVCaptureDevice.DiscoverySession`. This is a first-party framework in the platform SDK, not a third-party dependency, and it is the only way to render a live camera preview on macOS. In my reading of the contract-first rule, first-party Apple frameworks are part of the already-approved macOS platform stack and do not constitute "adopting an unlisted technology," so no Arch sign-off is needed. I am surfacing it explicitly anyway, per the kickoff prompt, and note that Arch is not engaged in this pass at all since Stage 3 is skipped. If the human disagrees, this needs an Arch review before Stage 2 concludes.
- **Persistence — recommend `@AppStorage` / `UserDefaults`, not SwiftData.** `tech-config.md` lists SwiftData for the macOS layer. For two scalar values (a device unique ID string and a boolean), SwiftData is materially over-weight: it means a model container, a schema, migration concerns, and app-startup cost for what is a two-key preference store. `@AppStorage` is the proven, idiomatic SwiftUI choice for user preferences at this size, ships with the platform, and needs no new dependency. Concrete alternative if the human prefers to stay literal to `tech-config.md`: adopt SwiftData now to avoid a migration later — but there is no plausible growth path here that turns two preferences into a relational model, so I do not recommend it. This is a design-time recommendation to be recorded in the PRD, not an implementation decision, since Stage 4 is off. Open question 5.

**No new library, package, or SPM dependency is proposed.** The stack stays the smallest thing that covers the requirements: SwiftUI + Observation + AVFoundation + `@AppStorage`.

**Source layout note.** Per the EM hard constraint, no feature-named subfolder will be created under `src/`. The existing Xcode layout under `MacRecordWidget/` is retained (see risk 5).

---

## 2. Open questions

1. ❓✅ **Master baseline is stale and hard-blocks Stage 1 and Stage 2.** `projects/master/` predates the shipped `20260521-popover-button-layout` single-row popover, and that feature's Stage 6 was never run. Which do you want: (a) backfill master now from the `20260521` feature before this feature starts, (b) fold the backfill into this feature's Stage 6 and accept that the Designer works against the live code rather than master for Stage 2, or (c) explicitly waive the rule for this pass? -- **Resolved 2026-09-04:** Backfill master now. PM and Designer bring `projects/master/` current with the shipped `20260521-popover-button-layout` feature BEFORE this feature's PRD is authored.
2. ❓✅ **Panel resize behavior.** Should the popover be permanently 504pt wide (stable, larger idle footprint), or animate 200pt → 504pt on toggle with the animation gated on `accessibilityReduceMotion` (small at rest, motion on every flip)? This changes the idle look of the app, so I do not want the Designer choosing it alone. -- **Resolved 2026-09-04:** Animate 200pt to 504pt on toggle, with the animation gated on `accessibilityReduceMotion`.
3. ❓✅ **Stage 7 and Stage 8 semantics for a design-only pass.** Do you accept the redefinition proposed in Risks — Stage 7 documents design intent only and clearly marks the feature as not implemented (with the `scripts/dev.sh` step marked SKIPPED as non-applicable to an Xcode app), and Stage 8 becomes design sign-off rather than release readiness? -- **Resolved 2026-09-04:** Accepted as proposed. Stage 7 documents design intent clearly marked not-implemented, Stage 8 becomes design sign-off, and the `scripts/dev.sh` step is seeded as SKIPPED.
4. ❓✅ **`RecordingManager` backlog items.** Confirm they are *not* fixed in this pass (Stage 4 is off), and that instead the PRD records the `@MainActor` isolation fix and the dead `accessibilityDenied` case removal as prerequisites that must land before or with the preview implementation. Or do you want a separate implementation-enabled pass scheduled for them first? -- **Resolved 2026-09-04:** Confirmed deferred. The `RecordingManager` backlog items are not fixed in this pass; the PRD records the `@MainActor` isolation fix as a prerequisite for implementation.
5. ❓✅ **Persistence mechanism.** Confirm `@AppStorage` / `UserDefaults` for the mirror and camera-selection settings, rather than SwiftData as listed in `tech-config.md`. -- **Resolved 2026-09-04:** `@AppStorage` / `UserDefaults`, not SwiftData. Log the deviation from `tech-config.md` alongside the Q7 exception.
6. ❓✅ **Preview/Photo Booth camera mismatch.** The PRD documents it as a known limitation with no user warning. Confirm the mocks should carry no affordance at all for it — not even a subtle hint in the picker — so the Designer does not invent one. -- **Resolved 2026-09-04:** CHANGED from the earlier requirements capture. The preview must carry a passive indicator naming the camera it is showing (e.g. "Logitech BRIO"), so a mismatch with Photo Booth is visible. No alarming warning affordance. The PRD's known-limitation wording must be updated to match.
7. ❓✅ **Source layout exception.** Confirm the Swift sources stay in `MacRecordWidget/` rather than moving under `src/`, and that this exception should be logged to `BACKLOG.md` triage and reflected in `tech-config.md` later. -- **Resolved 2026-09-04:** Sources stay in `MacRecordWidget/`; log the exception to the `src/` convention in `tech-config.md`.

---

## 3. Next step

Once approved — and once question 1 is resolved, since it hard-blocks PM — PM produces the full PRD at `projects/20260904-live-camera-preview/product-specs/prd.md` from the existing requirements frontmatter, which is the first unchecked step in `delivery-tracker.md`.
