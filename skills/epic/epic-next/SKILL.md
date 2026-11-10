---
name: epic-next
description: >-
  Displays the next sequential step for an epic derived from the status panel,
  and confirms before dispatching. Use to advance epic execution.
---

# Epic Next

Evaluates the active epic state using `epic-status.py` and proposes the next sequential command.
Executes the next step only after operator confirmation.

Heavy steps (such as full implementation plans or multi-repo execution) are dispatched to dedicated sessions to prevent context window bloat in the orchestrator pane.

## Workflow

### 1. Read Fast Status Panel

```bash
EPIC="$(lib/epic-lib/epic-context.sh --path <epic-hint>)"
python3 skills/epic/epic-status/epic-status.py "$EPIC"
```

Reads frontmatter metadata from disk without making remote git fetches or API calls.

### 2. Confirm Live Status if Required

When the status panel indicates `(requires --live)`:
```bash
python3 skills/epic/epic-status/epic-status.py "$EPIC" --live
```

Fetches remote PR statuses and active Herdr pane states.

### 3. Present Proposal and Await Confirmation

State the proposed step and its rationale. Upon operator confirmation, dispatch the corresponding skill:
- `/epic-plan`
- `/epic-implement`
- `/epic-review`
- `/epic-split`
- `/epic-validate-pre-merge`
- `/epic-merge`
- `/epic-validate-post-merge`
- `/epic-validate-post-experiment`
- `/epic-release-experiment`
- `/epic-analyze-metrics`
- `/epic-rollout`
- `/epic-release-delivery`
