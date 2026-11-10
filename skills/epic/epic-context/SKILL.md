---
name: epic-context
description: "Locates an epic dossier and guides reading requirements, decisions, findings, and designs. Use before planning or implementing work that depends on epic context."
---

# Epic Context

Read `docs/workflow-contract.md` for authorization, ownership, tracking, and repository boundaries.

Source code lives in repositories. The **rationale, contracts, and validation evidence** live in `${EPIC_ROOT:-$HOME/epics}/`. Every durable artifact—briefing, plans, findings, decisions, exported designs, review reports—is maintained in the epic dossier.

## The Epic Lifecycle

| Stage | Skill | Produces |
|---|---|---|
| 1 | `/epic-start` | Epic dossier: briefing, links, assets, and design references |
| 2 | `/agent-executor --delivery finding` | One brief per question; findings recorded in `findings/` |
| 3 | `/epic-plan` | Architecture spec, task tracking plan, and issue cards |
| 4 | `/epic-implement` | Integration PRs (`epic/<slug>`), one per participating repo |
| 5 | `/epic-review` | Batch review reports pinned by commit SHA in `reviews/` |
| 6 | `/epic-split` | Atomic reviewable PRs sliced from integration commits |
| 7 | `/epic-validate-pre-merge` | Minimum injection point validation and `GO` verdict |
| 8 | `/epic-merge` | Sequenced merges respecting review-wave dependencies |
| 9 | `/epic-validate-post-merge` | Staged journey recordings across `state × surface` in production |
| 10 | `/epic-validate-post-experiment` | Post-activation telemetry audit, hash bucketing, and SRM check |
| 11 | `/epic-release-experiment` | Feature flag activation announcement |
| 12 | `/epic-analyze-metrics` | Statistical evaluation of experiment variants |
| 13 | `/epic-rollout` | Permanent rollout PRs removing flag gates |
| 14 | `/epic-release-delivery` | Final delivery announcement |

## Resolving an Epic

```bash
lib/epic-lib/epic-context.sh <hint>          # Prints identity and document inventory
lib/epic-lib/epic-context.sh --path <hint>   # Prints dossier path only
```

The hint can be a slug, card key (`EPIC-101`), or name substring. Matching prioritizes directory names followed by the frontmatter `card:` field.

| Exit Code | Meaning | Action |
|---|---|---|
| 0 | Found | Proceed |
| 2 | Empty hint or outside dossier | Prompt operator for epic hint |
| 3 | Ambiguous | Review candidates printed on stderr and specify slug |
| 5 | Not found | Create dossier with `/epic-start` |

## Searching Dossier Content

Search across all epic dossiers by keyword:
```bash
lib/epic-lib/epic-context.sh --search "<term>"
```
