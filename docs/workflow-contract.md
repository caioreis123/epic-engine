# Shared Epic Workflow Contract

Read this contract when planning, executing, reviewing, splitting, or resuming an epic. Specific instructions for each stage complement this contract.

## Authorization and Ownership

Record authorized deliverables, boundaries, and ticketing ownership in the active plan or brief.
Authorization granted during discussion remains valid for subsequent stages.
Do not prompt the user for additional confirmations on already authorized work.
Request a decision only when required information is missing or when an action exceeds authorized scope.
Completing a stage does not authorize merging, publishing, or external notifications on its own.

| Role | Responsibility |
|---|---|
| Epic Orchestrator | Plan, tracking table, ticket tracking, `links.md`, dossier commits, and authorized stage promotion |
| Epic Executor (`agent-executor`) | Assigned task, commit, integration PR, and evidence; does not merge or mutate project tracking |
| Investigator | New finding file, evidence gathering, and notifying orchestrator |
| Agent Runtime (`agent-*`) | Spawn or resume session, deliver context; does not define ticketing or delivery policies |

For autonomous executors, the brief specifies who updates issue trackers and which deliverable closes the task. In the epic dossier, only the orchestrator modifies shared files or updates findings.

## Tracking and Identity

The epic plan maintains a `## Tracking` table containing `#`, `Task`, `Stage`, `Repo`, `Card`, and `Evidence`.
Each task identifier is unique and permanent: `task-<N>`. Never renumber existing tasks.
The `Card` column records issue tracking keys (e.g., `EPIC-101`).

Stamp every commit with `task-<N>` and, when applicable, the issue key:
`feat(payload): add eligibility (task-1, EPIC-101)`.

Tasks without code changes record the resulting artifact path in the `Evidence` column.
The artifact records `task: task-<N>` and `status: completed` upon verification.
Deliveries consisting solely of documentation or research skip PR review and split stages, moving directly to validation once all artifacts are verified.

Git branches, PRs, and dossier artifacts are the sole sources of truth for delivery progress. Never create secondary progress trackers.
The status panel uses `--live` to fetch remote commits before advancing to review or split.

## Review and Slicing

Existing directories do not prove task completion. The final review report must contain concrete evidence and frontmatter metadata:

```yaml
---
status: completed
heads:
  - "web-app | <full SHA reviewed>"
  - "graphql-bff | <full SHA reviewed>"
---
```

Use this format in `reviews/<round>/BATCH-REPORT.md` and `plans/<round>-split.md`.
List all repositories participating in the integration. In the split plan, SHAs identify the exact integration baseline.
Mark splitting as complete only after verifying diff equivalence, opening draft child PRs, and inserting review-wave tables.
Repositories that do not require splitting must remain in the tracking map with an explicit rationale.
Never modify the SHA of an older review to make it appear current.
If commits change, re-review the delta or child PR and record fresh evidence.
