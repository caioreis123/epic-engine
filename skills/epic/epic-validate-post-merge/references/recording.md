# Production Journey Recording: Zero Mock Protocol

Validates deployed production code after merge and before feature flag enablement.
A post-merge validation recording must show **what an eligible user sees in production**.
There is **no mock tier**: test users must genuinely satisfy server-side eligibility rules in production.
Every recording is preceded by a server-side probe proving the gate is open for that user ID.

## Split-Screen Video Standard

```
┌────────────────────────────────────────────────────────┐
│ Rendered Web Application (Top Half)                    │
│ Full real UI, responsive viewport, no overlapping logs │
├────────────────────────────────────────────────────────┤
│ Live Telemetry Event Log (Bottom Half)                 │
│ Synchronized tabular event dispatch stream             │
│ [Timestamp] [Event Name] [Component] [Parameters]      │
└────────────────────────────────────────────────────────┘
```

The split-screen layout pairs visible customer UI transitions with real-time analytics verification.
The journey covers entry (modal / popover / banner), intermediate lander (pricing tiers, CTA clicks), and checkout landing.

## Test User Profiles

- Dedicated QA test accounts: `100001`, `100002`, `100003`.
- State mutation (plan assignments, renewal date adjustments) is authorized strictly on dedicated test IDs.
- Mined production user IDs remain strictly **read-only**. Never mutate production user records.

## Pre-Recording Probes

Before starting video capture:
1. Probe server-side GraphQL resolvers to verify eligibility evaluates to `true`.
2. Verify deployed frontend `buildId` matches the merged commit SHA.
3. Confirm event dispatchers emit expected analytics payloads on user interaction.
