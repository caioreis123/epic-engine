---
name: epic-split
description: "Breaks stable integration pull requests into small, atomic, stacked child PRs while preserving diff equivalence and dependency ordering."
---

# Epic Split

Read `docs/workflow-contract.md` and `docs/integration-pr-model.md` for authorization, ownership, tracking, and repository boundaries.

Breaks the **integration pull requests** of an epic—one per participating repository produced during `/epic-implement`—into small, reviewable, stacked child pull requests.

Splitting is the final mechanical step performed only after implementation stabilizes and the integration review (`/epic-review`) has passed.

## Prerequisites

- Active, open draft integration pull requests (`epic/<slug>`).
- One commit per task on the integration branch (stamped with issue keys).
- Stable code: UI and business logic changes are complete.
- Integration review completed with findings resolved.

## Review Gates & Size Constraints

All child PRs must clear the four review size gates documented in [references/size-gates.md](references/size-gates.md):
- `< 300` changed files (hard limit)
- `< 20,000` diff lines (hard limit)
- `< 50 KB` filtered diff size
- `< 15,000` estimated tokens

## Workflow

### 1. Ingest Commit Logs from Remote

For each repository in the epic:
```bash
git fetch origin
git log --oneline origin/main..origin/epic/<slug>
```

Map integration commits to atomic child branches.

### 2. Create Sliced Child Branches

Create stacked child branches based on dependency order:
```bash
git checkout -b <slug>/01-eligibility origin/main
git cherry-pick <commit-sha-1>
git push -u origin <slug>/01-eligibility
```

### 3. Verify Diff Equivalence

Ensure no changes were lost during slicing:
```bash
git diff origin/main..<slug>/latest-slice > /tmp/child.diff
git diff origin/main..origin/epic/<slug> > /tmp/integration.diff
diff -u /tmp/child.diff /tmp/integration.diff
```
The diff must match cleanly.

### 4. Open Child PRs and Insert Review-Wave Table

Open child PRs as drafts. Splice the synchronized review-wave table into every child PR description following [references/review-wave-table.md](references/review-wave-table.md).

### 5. Close Integration PRs and Record Split Plan

Close the original integration PRs with a comment pointing to the child PR stack.
Record the slice map in `plans/<date>-split.md`:

```yaml
---
status: completed
heads:
  - "graphql-bff | <SHA>"
  - "web-app | <SHA>"
---
```
