---
name: epic-release-delivery
description: >-
  Prepares and publishes the final delivery announcement for a feature that has rolled out
  to 100% of production traffic, documenting performance data and business impact.
---

# Epic Release Delivery

Read `docs/workflow-contract.md` for authorization, ownership, tracking, and repository boundaries.

Publishes the final milestone announcement closing the epic lifecycle: summarizes what landed in production for all users, why, and what empirical metrics demonstrated during the experiment phase.

## Prerequisites

- Winning variant graduated to 100% traffic via `/epic-rollout`.
- Graduation pull requests merged to main branch.
- Performance and business metrics finalized in `/epic-analyze-metrics`.

## Workflow

### 1. Ingest Verified Results

From the epic dossier:
- `00-BRIEFING.md`: initial business driver and hypothesis.
- `findings/`: statistical analysis report with conversion rates and confidence intervals.
- Graduation PRs: links to finalized code changes.

### 2. Format Announcement Copy

Include:
- **Title and Card:** `[EPIC-101] Full Rollout: Annual Upgrade Modal`
- **What Landed:** Plain-language description of feature now active for all users.
- **Empirical Results:** Conversion rates, relative lift over control, and statistical confidence.
- **Artifact Links:** Jira story, graduation PRs, and finalized analytics dashboards.

### 3. Record in Epic Dossier

Record the published message permalink in `<epic>/links.md` and mark the epic delivery completed.
