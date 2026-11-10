---
name: epic-merge
description: >-
  Dispatches an executor to merge open pull requests of an epic in the exact sequence
  defined by the review-wave table, waiting for deployments when cross-service dependencies require.
---

# Epic Merge

Read `docs/workflow-contract.md` and `docs/integration-pr-model.md` for authorization, ownership, tracking, and repository boundaries.

Sequences and merges pull requests across repositories in the exact order specified by the `<!-- review-wave:start -->` table.

## Prerequisites

- Pre-merge validation has passed with a `GO` verdict (`/epic-validate-pre-merge`).
- Pull requests are approved by human reviewers or automated review gates.
- CI checks are green on all participating branches.

## Execution Order and Deployment Dependencies

Review the review-wave table:
1. Upstream backend schemas and APIs (e.g. `graphql-bff`) merge first.
2. If downstream services require production schema deployment before compilation succeeds, the merge executor waits for deployment completion.
3. Frontend applications (e.g. `web-app`) merge second.
4. Target regression suites and baselines merge last, using [references/review-fix-merge-loop.md](references/review-fix-merge-loop.md).

## Finalizing the Merge Step

When all PRs in the review wave are merged:
Record `findings/<date>-merge.md` with frontmatter:
```yaml
---
stage: merge
status: completed
merged_prs:
  - "https://github.com/acme/graphql-bff/pull/101"
  - "https://github.com/acme/web-app/pull/201"
---
```

Update issue sub-tasks to `Done`.
Advance to `/epic-validate-post-merge`.
