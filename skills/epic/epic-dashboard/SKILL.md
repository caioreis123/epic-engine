---
name: epic-dashboard
description: >-
  Creates or updates an analytics monitoring dashboard for an epic's A/B experiment:
  funnel conversion rates per variant, daily exposure volume, and date filtering.
---

# Epic Dashboard

Read `docs/workflow-contract.md` for authorization, ownership, tracking, and repository boundaries.

Generates an analytics monitoring dashboard to track live experiment funnels:
- Conversion metrics and lift per variant.
- Funnel stage progression (impressions -> interactions -> conversions).
- Daily timeseries volume monitoring.
- Date filters mapped across all dashboard cards.

## Workflow

### 1. Ingest Event Telemetry Specifications
Identify outbound event names and parameters from merged PRs or the epic specification:
- Exposure event: `experiment_events` (experiment ID, variation, user ID).
- Interaction events: modal views, CTA clicks, checkout submissions.

### 2. Formulate Metrics Queries
Write SQL queries computing:
- Unique participants per variation.
- Absolute and percentage conversion rates across each funnel step.
- Lift relative to control.

### 3. Record Dashboard in Epic Dossier
Add dashboard permalinks to `<epic>/links.md`.
Advance to `/epic-analyze-metrics` once traffic accumulates.
