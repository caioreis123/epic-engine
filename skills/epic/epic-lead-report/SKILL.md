---
name: epic-lead-report
description: >-
  Generates a concise 1-minute lead status report ("what remains") from the tech lead
  for the current delivery wave. Event-driven via Herdr prompt callback.
---

# Epic Lead Report

Generates an executive "what remains" report from the tech lead in one command. Communication is strictly event-driven: the requester session never waits in a loop.

## Requesting the Report

```bash
/epic-lead-report [label] [--dry-run]
```

- If running inside the tech lead pane: formats the report immediately.
- If running in another tab: sends an asynchronous request to the lead pane and ends turn. The completed report is typed back into the requester pane upon completion.

## Report Structure

```markdown
# Lead Report: <Epic Name> (<Card Key>)

## In Flight
- <Task identifier>: <Current state, assigned worker pane, and ETA>

## Waiting on Operator
- PR #<Number> (<repo>): <Exact decision required, e.g. merge approval, design signoff>

## Blockers & Divergences
- <Any open blocker or discrepancy between tracking plan and git branch>

## Next Steps
- <Immediate next milestone once blockers resolve>
```
