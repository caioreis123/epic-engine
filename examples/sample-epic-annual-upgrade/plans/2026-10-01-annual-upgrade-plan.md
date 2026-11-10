# Implementation Plan: Annual Plan Upgrade Popover

## Tracking

| # | Task | Stage | Repo | Card | Evidence |
|---|---|---|---|---|---|
| 1 | Server-side eligibility and copy payload | implement | graphql-bff | EPIC-102 | |
| 2 | Upgrade modal component and layout | implement | web-app | EPIC-103 | |
| 3 | Telemetry event dispatching | implement | web-app | EPIC-104 | |
| 4 | Visual regression test baselines | implement | visual-check | EPIC-105 | |

## Task Definitions

### Task 1: Server-side eligibility and copy payload
- **Repo:** `acme/graphql-bff`
- **Branch:** `epic/annual-upgrade`
- **Skill:** `agent-executor`
- **Deliverable:** Resolver implementing `annualUpgradeOffer` query with eligibility predicate and tenure checking.

### Task 2: Upgrade modal component and layout
- **Repo:** `acme/web-app`
- **Branch:** `epic/annual-upgrade`
- **Skill:** `agent-executor` (loading `implement-ui`)
- **Deliverable:** React modal component matching Figma tokens (`<= 3pp` bounding box delta, `< 40` icon RGB distance).

### Task 3: Telemetry event dispatching
- **Repo:** `acme/web-app`
- **Branch:** `epic/annual-upgrade`
- **Skill:** `agent-executor` (loading `implement-events`)
- **Deliverable:** Integration of `component_view` on modal render and `upgrade_cta_click` on CTA interaction.

### Task 4: Visual regression test baselines
- **Repo:** `acme/visual-check`
- **Branch:** `epic/annual-upgrade`
- **Skill:** `agent-executor` (loading `implement-target-repo`)
- **Deliverable:** Baseline image generation for desktop and mobile viewport scenarios.
