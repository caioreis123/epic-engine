---
name: epic-release-experiment
description: "Prepares and publishes the announcement for a live experiment that has just been enabled, using verified sources from the epic dossier."
---

# Epic Release Experiment

Read `docs/workflow-contract.md` for authorization, ownership, tracking, and repository boundaries.

Drafts and publishes the launch announcement for a newly activated experiment.
Preview output defaults to `#eng-releases` for verification before posting to team channels.

## Prerequisites

Experiment activation announcements require a verified `GO` verdict from `/epic-validate-post-experiment` recorded in `<epic>/findings/`.

## Workflow

### 1. Ingest Verified Dossier Sources

Load the epic dossier:
```bash
lib/epic-lib/epic-context.sh <epic-hint>
```

Read:
- `00-BRIEFING.md`: core objectives and hypotheses.
- `links.md`: experiment specification and tracking dashboard URLs.
- `findings/`: post-experiment audit proving live bucketing and warehouse exposure.

### 2. Format Announcement Copy

Include:
- **Experiment Title and Card:** e.g. `[EPIC-101] Annual Upgrade Modal Experiment`
- **Hypothesis:** What behavior change is expected and why.
- **Audience & Traffic Split:** Target segment, rollout percentage, and variation allocation.
- **Variants:** Concise breakdown of Control vs. Variant arms.
- **Monitoring Dashboard:** Direct link to tracking dashboard.
- **Stakeholders:** Team and technical owners.

### 3. Record in Epic Dossier

Record the published message permalink in `<epic>/links.md`.
Proceed to `/epic-analyze-metrics` as participants accumulate.
