---
name: epic-rollout
description: >-
  Graduates a finished experiment: makes the winning variant permanent for all users
  and removes feature flag gating code. Opens draft pull requests across affected repositories.
---

# Epic Rollout

Read `docs/workflow-contract.md` and `docs/integration-pr-model.md` for authorization, ownership, tracking, and repository boundaries.

Promotes the winning variant of a concluded experiment into permanent production code. Removes temporary feature flag gating, deletes superseded variant branches, and opens draft cleanup PRs across affected repositories (`acme/web-app` and `acme/graphql-bff`).

## Usage

```bash
/epic-rollout <epic-hint> winner=<variant> [flagKey=<key>]
```

Example:
```bash
/epic-rollout annual-upgrade winner=variant-b
```

## Principles

1. **Winning variant is an explicit input:** Derived from statistical evaluation (`/epic-analyze-metrics`) and approved by business stakeholders.
2. **Confirm deletion targets before modifying code:** Present touched files and eliminated code paths for confirmation.
3. **Remove gating, preserve eligibility:** Eliminate conditional flag checks while maintaining core business logic.
4. **Draft PRs:** Open all graduation PRs in **draft** status linked to the tracking card.

## Workflow

### 1. Identify Callsites
Search for feature flag evaluation sites across backend resolvers and frontend component render trees.

### 2. Settle Code Paths on the Winner
- Backend: remove variant enum branches and serve winning values directly.
- Frontend: replace conditional component rendering with the winning component.
- Remove obsolete styles, unused assets, and test mocks associated with discarded variants.

### 3. Open Graduation Pull Requests
Open draft PRs across participating repositories.
Proceed to `/epic-release-delivery` once graduation PRs are merged.
