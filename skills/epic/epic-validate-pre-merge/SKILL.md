---
name: epic-validate-pre-merge
description: "Plans and executes pre-merge validation for an epic using observable pass/fail criteria, concrete command evidence, and the Minimum Injection Point method."
---

# Epic Validate Pre-Merge

Read `docs/workflow-contract.md` for authorization, ownership, tracking, and repository boundaries.

Validates the delivery **before merging** to main. Produces an executable validation plan and records the final verdict in `<epic>/validations/<date>-pre-merge.md`.

## The Minimum Injection Point Method

The primary objective is finding the **minimum injection point**: the closest boundary to the modified code where real input can be injected and observable output verified, bypassing upstream triggering layers that did not change.

| Injection Point | When to Use |
|---|---|
| Direct API / RPC endpoint on modified service | The service accepts the payload upstream would deliver (fastest, lowest noise) |
| Message queue / event stream | Asynchronous consumers where an event can be published directly |
| Service CLI or test runner script | The repository contains an entrypoint exercising the exact logic path |
| Upstream state override | Plan swap, forced experiment bucket, or mocked user entitlement |
| Full end-to-end user journey | Used only when behavior genuinely depends on cross-service chaining |

## Workflow

### 1. Identify Changed Scope and Observable Effect

Read PR links in `links.md` and review reports in `reviews/`.
Define the observable effect: visible UI element, updated database row, emitted webhook, or completed transaction. "Code runs without error" is invalid.

### 2. Formulate Test Scenarios

Document:
- Prerequisites: seed data, port-forwards, environment variables.
- Step-by-step reproduction commands.
- Observable pass/fail criteria verifiable by an independent observer.

### 3. Execute and Record Verdict

Run test commands and record output in `<epic>/validations/<date>-pre-merge.md`:

```yaml
---
epic: <slug>
title: "<Validation Title>"
created_at: <YYYY-MM-DD-HHMM>
status: completed
environment: staging
verdict: GO
---
```

A `GO` verdict is required before proceeding to `/epic-merge`.
