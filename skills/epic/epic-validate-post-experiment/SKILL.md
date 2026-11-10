---
name: epic-validate-post-experiment
description: >-
  Audits a live experiment in production immediately after feature flag activation:
  evaluates SDK payload rules, hashes real user IDs per variant, runs read-only GraphQL probes
  without force cookies, verifies warehouse exposure events, and checks for Sample Ratio Mismatch (SRM).
---

# Epic Validate Post-Experiment

Read `docs/workflow-contract.md` for authorization, ownership, tracking, and repository boundaries.

Validates the live experiment in production **immediately after feature flag enablement**.
Proves that real traffic receives intended variants, offline hashing matches runtime routing, and telemetry events flow into data warehouse tables with balanced sample ratios.

## Why This Step is Essential

Pre-merge and post-merge validation rely on explicit variant forcing (`forceExperiment` overrides). Overrides do not traverse the feature flag evaluation engine or fire live participation tracking. Only post-activation validation confirms that live hashing, bucketing, and telemetry function end-to-end.

## Audit Checks

### 1. Live Feature Flag Payload Rules
Inspect the live SDK connection payload:
- Confirm the rule is active and matches the target rollout percentage and variation weights.
- Verify hashing attribute (e.g. `userId` or `deviceId`) and seed string.

### 2. Offline Hash Bucketing
Run offline SDK hash evaluation against known user IDs to identify at least one real eligible user ID per variant.

### 3. Read-Only Production Probes (Without Override Cookies)
Probe production GraphQL endpoints using impersonation headers for the identified user IDs:
- Confirm Variant A user receives Variant A payload and copy.
- Confirm Variant B user receives Variant B payload and copy.
- Do not pass force cookies.

### 4. Telemetry and Warehouse Exposure Audit
Query analytics warehouse tables to verify participation events are recorded:
- Confirm exposure events arrive in `analytics_prod.experiment_events`.
- Verify event attributes: `experiment_id`, `variation_id`, and `user_id`.

### 5. Sample Ratio Mismatch (SRM) Gate
Run a chi-square test on early traffic allocations:
- Compute expected vs. observed participant counts per variation.
- An SRM failure (`p < 0.001`) indicates severe bucketing bias or upstream filtering failure.

## Output

Record findings in `<epic>/findings/<date>-validate-post-experiment.md`:
```yaml
---
stage: validate-post-experiment
status: completed
verdict: GO
question: "Does the live experiment bucket correctly, serve expected payloads, and record participants?"
short_answer: "Verified live rules, hash routing, warehouse exposures, and SRM balance."
---
```

A `GO` verdict authorizes proceeding to `/epic-release-experiment`.
