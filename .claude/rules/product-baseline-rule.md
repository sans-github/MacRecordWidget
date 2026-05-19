# Rule: Master PRD and Mocks

A consolidated, up-to-date copy of the full product PRD and HTML mocks must be maintained at `projects/master/`. This is the baseline every new feature starts from.

## Structure

```
projects/
└── master/
    ├── product-specs/
    │   └── prd.md   # full product PRD, merged across all shipped features
    └── mocks/       # current HTML mocks reflecting the live product UI
```

## When to update

`projects/master/` is updated as part of **Stage 6: Master Baseline Update** in every feature's `feature-setup.md`. Stage 6 runs after Stage 5 sign-off and is never skippable.

- **PM** merges the feature PRD into `projects/master/product-specs/prd.md`: add new sections, update changed sections, do not duplicate. If master is empty, copy as-is.
- **Designer** merges the feature mocks into `projects/master/mocks/`: add new pages, replace updated pages, remove obsolete pages. If master is empty, copy as-is.
- **Human** confirms master is current before Stage 6 closes.

Stage 6 is the enforcement mechanism for this rule. Do not update master ad-hoc during a feature -- consolidate at Stage 6.

## QA gate

QA compares the working product against `projects/master/product-specs/prd.md` and `projects/master/mocks/` during validation:

- If a UI element differs from the mocks -- file a GH issue, assign to Designer to update the mocks or flag the discrepancy to PM
- If product behavior differs from the PRD -- file a GH issue, assign to PM to update the PRD or confirm the change is intentional

QA does not resolve these discrepancies. They surface them. PM and Designer decide whether the product or the spec is wrong and update accordingly.

## Hard block on new features

PM and Designer must not begin work on a new feature until `projects/master/` is current:

- PM must confirm `projects/master/product-specs/prd.md` reflects all previously shipped phases before authoring a new PRD
- Designer must confirm `projects/master/mocks/` is current before creating new mocks

If the master is stale, update it first. Do not use a feature-specific PRD or mock as the baseline -- always use `projects/master/`.

## Ownership

- **PM** owns `projects/master/product-specs/prd.md` -- updated in Stage 6
- **Designer** owns `projects/master/mocks/` -- updated in Stage 6
- **EM** verifies Stage 6 is complete before signing off on a feature
