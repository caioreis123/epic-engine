---
name: epic-status
description: "Displays the status of an epic dossier and identifies the next sequential step from tracked evidence. Use to check progress, open items, or resume context."
---

# Epic Status

Read `docs/workflow-contract.md` for authorization, ownership, tracking, and repository boundaries.

Inspects frontmatter metadata from findings, decisions, technical specs, tracking plans, and validation verdicts without reading entire file bodies. Computes the canonical next step.

## Usage

```bash
/epic-status [<epic-hint>] [--live]
```

Or execute directly:
```bash
python3 skills/epic/epic-status/epic-status.py <epic-dir> [--live]
```

## Lifecycle State Machine Transitions

The status panel transitions strictly across sequential stages:
```
/epic-plan
  → /epic-implement
  → /epic-review
  → /epic-split
  → /epic-validate-pre-merge
  → /epic-merge
  → /epic-validate-post-merge
  → /epic-validate-post-experiment
  → /epic-release-experiment
  → /epic-analyze-metrics
  → /epic-rollout
  → /epic-release-delivery
```
