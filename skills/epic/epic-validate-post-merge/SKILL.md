---
name: epic-validate-post-merge
description: >-
  Validates deployed code in production after merge and before experiment flag activation.
  Builds the state x surface eligibility matrix, verifies deployed buildId SHAs, forces variants
  on eligible test profiles with zero mocks, and captures split-screen journey recordings.
---

# Epic Validate Post-Merge

Read `docs/workflow-contract.md` for authorization, ownership, tracking, and repository boundaries.

Validates the deployed code in production **after merging to main and before activating the feature flag for live traffic**.
Verifies that real eligible users see the correct experience with zero mocks across the entire `state × surface` matrix.

## The State × Surface Matrix

Construct the eligibility matrix directly from `00-BRIEFING.md` and feature specifications:
- **States:** Target user cohorts (e.g. active monthly subscribers, expired winbacks, trial users, non-eligible excluded users).
- **Surfaces:** Entry points (e.g. in-app notification, navigation banner, feature modal, landing page).

For each cell in the matrix, determine the expected visual outcome, copy variants, and telemetry events.

## Workflow

### 1. Verify Production Deployment

Confirm that the latest merged commits are deployed:
- Probe the frontend application `buildId` or version endpoint to verify it matches the merged commit SHA.
- Probe backend services to confirm updated resolvers are live.

### 2. Force Variant on Dedicated Test Profiles

Use dedicated test accounts (`100001`, `100002`, `100003`):
- Configure test user state in production services to satisfy eligibility predicates.
- Probe GraphQL resolvers to confirm eligibility returns `true` without mocking.

### 3. Capture Split-Screen Journey Recordings

Following [references/recording.md](references/recording.md), record synchronized split-screen videos:
- **Top:** Real browser viewport showing user interactions from entry trigger to checkout.
- **Bottom:** Real-time analytics event dispatch stream displaying fired event names and payload attributes.

### 4. Record Results

Save video recordings and execution logs in `<epic>/validations/post-merge/<timestamp>/`.
Record a summary finding in `findings/<date>-validate-post-merge.md` with:
```yaml
---
stage: validate-post-merge
status: completed
verdict: GO
---
```

Once post-merge validation is verified, proceed to `/epic-validate-post-experiment`.
