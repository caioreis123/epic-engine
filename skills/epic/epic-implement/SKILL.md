---
name: epic-implement
description: >-
  Executes an approved epic implementation plan with sequential tasks per repository,
  parallelism across distinct repositories, and review-wave table reconciliation upon closing each wave.
---

# Epic Implement

Read `docs/workflow-contract.md` and `docs/integration-pr-model.md` for authorization, ownership, tracking, and repository boundaries.

The implementation orchestrator. Dispatches atomic tasks to dedicated **Herdr tabs** in the epic workspace, tracks completion via `inbox.jsonl`, and promotes stages sequentially.

## The Concurrency Model

- **One integration PR per repository, not per task.** Each repository maintains a dedicated worktree and an `epic/<slug>` branch. Tasks within the same repository run sequentially on this branch, each adding a single stamped commit (`task-<N>, EPIC-nnn`).
- **Parallelism occurs across repositories** (e.g., `graphql-bff` ‖ `web-app` ‖ `visual-check`), never within the same repository branch.
- **Target verification suites close the wave.** Regression baselines and integration test suites run after upstream dependencies have landed on their integration branches.

## Dispatching Tasks via Agent Executor

For each ready task in the tracking table, dispatch an executor:

```bash
skills/agent/agent-executor/agent-executor.sh <repo> <slug> <tab-name> <task-brief> --delivery pr --task task-<N>
```

The orchestrator ends turn and waits for worker callback events delivered through `<epic>/inbox.jsonl`.

## Reconciling the Review-Wave Table

Once all integration PRs for a multi-repo delivery wave exist, reconcile the review-wave table across all participating PR descriptions:
```markdown
<!-- review-wave:start -->
<!-- review-wave:end -->
```

Verify that all dependencies and PR links match before advancing the delivery wave to `/epic-review`.
