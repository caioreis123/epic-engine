# Delivery Mode: Lead Coordinator (`lead`)

Read this guide when dispatching an agent to coordinate multiple parallel worker executors.

The workflow:
```
context + lead brief → tab in epic dossier → lead writes worker briefs → parallel executors
  → lead verifies PRs & contracts → closes worker tabs → reports completion to epic inbox.jsonl
```

## When to Use

- **Use** when two or more deliverables across different repositories depend on a shared schema or API contract and execute in parallel.
- **Do not use** for single-repository tasks. Dispatch the worker directly via `--delivery pr`.
- **Do not use** for unbounded investigations. A standalone question requires `--delivery finding`.

## Orchestrator Prerequisites

The lead coordinates rather than explores. The orchestrator must document the context package before dispatching:
- Verified facts, citations, and commit SHAs (`repo@sha`).
- Established decisions and provisional assumptions.
- Scope matrix against the issue card.
- Contract specification between participating repos (field names, types, GraphQL schemas, units).
- Verification requirements, lint commands, and issue tracking keys.

## Dispatching the Lead

```bash
skills/agent/agent-executor/agent-executor.sh - <slug> <tab-name> <lead-brief-path> --delivery lead
```

The first argument `-` signifies that the lead coordinates across repositories rather than residing in a single repository worktree. The wrapper opens the tab inside the epic dossier using the `lead` model role.

The wrapper allocates a dedicated inbox for the lead: `<epic>/inbox-<name>.jsonl`.
This isolates worker events for this lead while preserving the main `<epic>/inbox.jsonl` for orchestrator-level tracking.

## Responsibilities of the Lead

1. Compares card requirements with context. Scope discrepancies are immediately flagged back to the orchestrator as `blocked`.
2. Generates atomic briefs for each worker executor directly from the verified context.
3. Spawns executors in parallel and ends turn. Worker completion events wake the lead via dedicated inbox drain.
4. As each worker finishes (`done`), verifies deliverables against concrete artifacts: draft PR created, Jira linkage, reviewer findings resolved, and test evidence recorded.
5. Verifies cross-repo contract parity across the PR diffs.
6. Slices review-wave tables into PR descriptions.
7. Closes finished worker tabs.
8. Writes a single completion event line into the main `<epic>/inbox.jsonl` and notifies the orchestrator pane.
