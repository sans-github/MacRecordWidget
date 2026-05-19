# Introduction

A collection of reusable, generic Claude Code agent definitions for a software engineering team. Each agent represents a distinct engineering or product role with well-defined expertise, collaboration style, and hard constraints.

See [SETUP-GUIDE.md](.claude/SETUP-GUIDE.md) to install and run your first project.

## Project folder structure

```
.claude/                                # agent definitions, rules, skills, templates (managed by install.sh)
projects/
├── master/                             # consolidated product baseline (copy once from template/master)
│   ├── product-specs/
│   │   └── prd.md                      # full PRD merged across all shipped features
│   └── mocks/                          # current UI mocks
└── YYYYMMDD-feature-name/              # copy per feature from template/feature
    ├── generated-docs/                 # all design/planning artifacts (Designer + EM output)
    │   ├── design/                     # mocks and diagrams (Designer)
    │   ├── architecture/               # sys-arch, HLD (Arch + EM)
    │   ├── contracts/                  # API contract (BE + FE)
    │   └── qa/                         # test plan (QA)
    ├── product-specs/                  # PRD and other product artifacts (PM input)
    └── workflow/
        ├── feature-setup.md           # filled in by /feature-init (phase config, deployment target)
        └── delivery-tracker.md    # seeded at kickoff; progressively filled by EM; human gates + agent steps
src/                                    # all production artifacts (source code, db, migrations, seeds, IaC)
```

---

## Agents

| Agent | Description |
|-------|-------------|
| `senior-engineering-manager` | Owns architecture, delivery planning, API contracts, QA plan, and phase sign-off across all workstreams |
| `senior-product-manager` | Owns PRD and acceptance criteria; defines delivery phases and drives cross-functional alignment |
| `senior-software-architect` | Owns system-wide technical direction, structural integrity, and critical path design review |
| `senior-frontend-engineer` | Builds accessible, performant UI with full ownership of components, state, routing, and API integration (React 18, TypeScript, Redux Toolkit, Playwright) |
| `senior-backend-engineer` | Designs and implements the full backend stack including DB schema, API, auth, and Terraform infra |
| `senior-devops-engineer` | Owns CI/CD pipelines, cloud infrastructure (IaC), observability stack, and security posture end-to-end |
| `senior-qa-automation-engineer` | Owns full test pipeline including strategy, test files, CI wiring, and quality gates |
| `senior-ux-ui-designer` | Creates distinctive, production-grade interfaces and complete design artifacts |
| `senior-macos-designer` | Creates platform-native macOS interfaces respecting the Human Interface Guidelines, with full ownership of mocks, component specs, dark mode, and menu design |
| `senior-swift-engineer` | Builds SwiftUI-first macOS apps with full ownership of the view layer, architecture, persistence, networking, Xcode project configuration, and App Store delivery |

Agent files live in `.claude/agents/` and are automatically loaded by Claude Code.

## Structure

Each agent definition covers:
- **Qualities** -- role mindset, quality standards, and operating principles
- **Collaboration** -- who this role works with and how
- **Ownership** -- what this role owns end-to-end
- **Decision-making** -- how this role makes and escalates decisions
- **Communication** -- how this role communicates blockers, reviews, and handoffs
- **Hard constraints** -- non-negotiable rules that govern the role
- **Commit conventions** -- role-specific commit rules, inline in the agent file

Collaboration contracts (depends-on, produces, gatekeeps per pair) live in `.claude/skills/collaboration-contracts/SKILL.md` -- the single source of truth for artifact flows. All agents load this skill at runtime.

## Skills

Standalone domain skills live under `.claude/skills/{skill}/`, each with a `SKILL.md`. Agents reference skills in their `skills:` frontmatter. Skills load progressively: frontmatter at startup, body when triggered, referenced files on demand.

Skill names must be unique across all skill files.

```mermaid
mindmap
  root((Agents))
    [Backend Engineer]
      )db-schema(
      )java-springboot(
      )api-design-principles(
      )java-testing(
      )be-logging(
      )collaboration-contracts(
    [Engineering Manager]
      )db-schema(
      )java-springboot(
      )api-design-principles(
      )react-typescript(
      )terraform(
      )java-testing(
      )be-logging(
      )fe-logging(
      )collaboration-contracts(
    [UX Designer]
      )frontend-design(
      )brand-guidelines(
      )ui-simplicity(
      )collaboration-contracts(
    [Product Manager]
      )prd-craft(
      )brand-guidelines(
      )collaboration-contracts(
    [Software Architect]
      )api-design-principles(
      )db-schema(
      )collaboration-contracts(
    [Frontend Engineer]
      )api-design-principles(
      )react-typescript(
      )fe-testing(
      )brand-guidelines(
      )fe-logging(
      )collaboration-contracts(
    [DevOps Engineer]
      )terraform(
      )collaboration-contracts(
    [QA Engineer]
      )api-design-principles(
      )fe-testing(
      )brand-guidelines(
      )collaboration-contracts(
    [macOS Designer]
      )macos-hig(
      )ui-simplicity(
      )collaboration-contracts(
    [Swift Engineer]
      )swiftui-macos(
      )swift-testing(
      )collaboration-contracts(
```


## Collaboration map

Agents collaborate by exchanging artifacts. The Gatekeeper is the role with final say -- they review, raise concerns, and resolve with the owner before downstream work proceeds.

---

**Timeline** (phases and artifacts at a glance)

```mermaid
timeline
    title Collaboration Flow
    Discovery          : Reqs
                       : PRD & ACs
                       : Mocks
    System Design      : Sys Arch
                       : Eng Plans (HLD)
    Engineering Design : BE Detailed Design
                       : FE Detailed Design
                       : API Contract
    Implementation Planning : Test Plan
                       : Issues List
    Implementation     : BE Artifacts
                       : FE Artifacts
                       : BE & FE Test Docs
    Validation         : Automation
```

<details>
<summary>Sequence diagram (who hands what to whom, in order)</summary>

```mermaid
sequenceDiagram
    participant User
    participant PM
    participant Design
    participant EM
    participant Arch
    participant BE
    participant FE
    participant QA

    rect rgb(219, 234, 254)
        Note over User,QA: 1. Discovery
        User->>PM: Reqs
        Note right of PM: Produces: PRD, ACs
    end
    rect rgb(237, 233, 254)
        Note over User,QA: 2. Design
        rect rgb(196, 181, 253)
            Note over PM,Design: PM <> Designer
            loop until PM approves
                PM->>Design: PRD, ACs
                Design-->>PM: Mocks (draft)
            end
            Note right of Design: Produces: Mocks (approved)
        end
        rect rgb(196, 181, 253)
            Note over PM,EM: PM → EM handoff
            PM->>EM: PRD, Reqs, Mocks, ACs
        end
    end
    rect rgb(254, 249, 195)
        Note over User,QA: 3. Eng Planning
        rect rgb(254, 240, 138)
            Note over EM,Arch: EM <> Arch
            loop until EM approves
                EM->>Arch: PRD, ACs
                Arch-->>EM: Sys Arch
            end
            Note right of Arch: Produces: Sys Arch
            EM->>EM: Authors HLD
        end
        rect rgb(254, 240, 138)
            Note over EM,BE: EM <> BE
            EM->>BE: HLD, PRD, Reqs, ACs
            loop until EM approves
                BE-->>EM: BE Detailed Design
                EM-->>BE: feedback
            end
            EM-->>BE: Approved
            Note right of BE: Produces: BE Detailed Design
        end
        rect rgb(254, 240, 138)
            Note over EM,FE: EM <> FE
            EM->>FE: HLD, PRD, Reqs, ACs, Mocks
            loop until EM approves
                FE-->>EM: FE Detailed Design
                EM-->>FE: feedback
            end
            EM-->>FE: Approved
            Note right of FE: Produces: FE Detailed Design
        end
        rect rgb(254, 240, 138)
            Note over BE,EM: BE <> FE → EM
            loop until aligned
                BE->>FE: API Contract draft
                FE-->>BE: feedback
            end
            BE->>EM: API Contract (joint w/ FE)
            EM-->>BE: Approved
            Note right of BE: Produces: API Contract
        end
    end
    rect rgb(220, 252, 231)
        Note over User,QA: 4. Implementation
        rect rgb(167, 243, 208)
            Note over EM,BE: EM <> BE
            BE->>EM: Issues List
            EM-->>BE: Approved
            BE->>BE: Create GH Issues → Implement
            Note right of BE: Produces: BE Artifacts, BE Test Docs
        end
        rect rgb(167, 243, 208)
            Note over EM,FE: EM <> FE
            FE->>EM: Issues List
            EM-->>FE: Approved
            FE->>FE: Create GH Issues → Implement
            Note right of FE: Produces: FE Artifacts, FE Test Docs
        end
        rect rgb(167, 243, 208)
            Note over EM,QA: EM <> QA
            EM->>QA: PRD, Mocks, ACs, BE + FE Detailed Designs
            loop until EM approves
                QA->>EM: Test Plan
                EM-->>QA: feedback
            end
            EM-->>QA: Approved
            QA->>EM: Issues List
            EM-->>QA: Approved
            QA->>QA: Create GH Issues → Implement
            BE->>QA: BE Artifacts + BE Test Docs
            FE->>QA: FE Artifacts + FE Test Docs
        end
    end
    rect rgb(254, 226, 226)
        Note over User,QA: 5. Validation
        rect rgb(252, 165, 165)
            Note over QA,EM: QA → EM
            QA->>QA: Author automation suite
            QA->>EM: Automation suite
            EM-->>QA: Approved
            Note right of QA: Produces: Automation suite
        end
    end
```

</details>

### Discovery
| Artifact | Owner | Key collaborators | Gatekeeper |
|---|---|---|---|
| Reqs | User | PM gathers | -- |
| PRD, ACs | PM | EM reviews | PM |
| Mocks | Design | PM refines jointly | PM |

### System Design
| Artifact | Owner | Key collaborators | Gatekeeper |
|---|---|---|---|
| Sys Arch | Arch | EM drives, Arch authors | Arch |
| Eng Plans (HLD) | EM | Arch contributes, FE+BE align | EM |

### Engineering Design
| Artifact | Owner | Key collaborators | Gatekeeper |
|---|---|---|---|
| BE Detailed Design | BE | EM monitors; intercepts and collaborates to resolve on red flag | EM |
| FE Detailed Design | FE | EM monitors; intercepts and collaborates to resolve on red flag | EM |
| API Contract | FE + BE | EM monitors; intercepts and collaborates to resolve on red flag | EM |

### Implementation Planning
| Artifact | Owner | Key collaborators | Gatekeeper |
|---|---|---|---|
| Test Plan | QA | EM monitors; intercepts and collaborates to resolve on red flag | EM |
| Issues List | BE / FE / QA | EM signs off each list | EM |

### Implementation
| Artifact | Owner | Key collaborators | Gatekeeper |
|---|---|---|---|
| CI/CD Pipeline + IaC | DevOps | EM monitors; intercepts and collaborates to resolve on red flag | EM |
| Deployment Smoke Check | QA | DevOps hands off live URL; QA runs API-level + E2E checks; failures loop back to DevOps for remediation | EM |
| BE Artifacts | BE | QA tests, Arch reviews, EM monitors; intercepts and collaborates to resolve on red flag | EM |
| FE Artifacts | FE | QA tests, EM monitors; intercepts and collaborates to resolve on red flag | EM |
| BE Test Docs | BE | QA consumes | EM |
| FE Test Docs | FE | QA consumes | EM |

### Validation
| Artifact | Owner | Key collaborators | Gatekeeper |
|---|---|---|---|
| Automation | QA | EM monitors; intercepts and collaborates to resolve on red flag | EM |
---

<details>
<summary>Step-by-step flow</summary>

1. **User** shares requirements with **PM**.
2. **PM** gathers requirements and produces the PRD and ACs.
3. **PM** sends PRD to **Design**, who creates Mocks. PM reviews and refines jointly with Design.
4. **PM** sends PRD, Reqs, Mocks, and ACs to **EM**. EM is the single intake point for engineering -- no direct PM handoff to BE, FE, QA, or DevOps.
5. **EM** engages **Arch** and collaborates to produce Sys Arch based on PRD and system constraints.
6. **EM** authors Eng Plans (HLD) based on Sys Arch and PRD. Arch contributes; FE and BE align on scope.
7. **EM** kicks off **BE** with HLD, PRD, Reqs, and ACs. BE authors BE Detailed Design and iterates until EM approves.
8. **EM** kicks off **FE** with HLD, PRD, Reqs, ACs, and Mocks. FE authors FE Detailed Design and iterates until EM approves.
9. **FE and BE** jointly author the API Contract, aligned on their Detailed Designs. EM approves before implementation begins.
10. **EM** kicks off **QA** in two waves: first with PRD, Mocks, and ACs (concurrent with BE/FE kickoff) so QA can begin Test Plan authoring; then with approved BE/FE Detailed Designs once available for detailed QA planning. QA iterates the Test Plan with EM until approved.
11. **BE**, **FE**, and **QA** each independently author their own Issues List and submit to **EM** for sign-off.
12. **EM** approves each Issues List. Each role then creates GH Issues and begins implementation.
13. **BE** implements BE Artifacts per BE Detailed Design and API Contract. **FE** implements FE Artifacts per FE Detailed Design and API Contract.
14. **BE** and **FE** each produce Test Docs for QA to use in automation.
15. **QA** authors the automation suite against FE/BE artifacts and test docs. EM approves before delivery.

</details>

## Rules

Rules in `.claude/rules/` apply automatically to every session:

- **workflow-phases-rule** -- multi-step work must be defined as a phased workflow with numbered steps, responsible roles, and concrete artifacts
- **progress-tracking-rule** -- `delivery-tracker.md` is the single source of truth for human gates and phase progress; agents check off steps and resume from it directly
- **backlog-reporting-rule** -- append discovered bugs and tech debt to `BACKLOG.md` triage table
- **contract-first-rule** -- governs agent-to-agent technical contracts (HLD, DB Schema, BE Detailed Design, FE Detailed Design, API Contract, Test Plan, Issues Lists); human milestone gates are tracked in `workflow/delivery-tracker.md`
- **db-schema-change-rule** -- all schema changes require a versioned migration file and an updated ER diagram (`src/db/er-diagram.md`) in the same commit; no raw DDL outside migration files
- **product-baseline-rule** -- maintain a consolidated master PRD and mocks at `projects/master/`; PM and Designer are blocked from starting a new feature until it is current

## Usage guide

```bash
bash install.sh          # sync latest
bash install.sh v1.2.0   # pin a tag or branch
```

This clones the upstream repo and overwrites everything under `.claude/` (agents, rules, skills, template, guide docs) except your `settings.json`. Commit the result to lock the version.

Default file locations (e.g. `src/db/er-diagram.md`, `BACKLOG.md`) can be overridden in your project's `CLAUDE.md`. See [CONTRIBUTING.md](CONTRIBUTING.md) for details.