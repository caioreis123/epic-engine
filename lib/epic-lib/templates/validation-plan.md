---
epic: <epic-slug>
title: "<what this plan validates>"
created_at: <YYYY-MM-DD-HHMM>
status: draft
environment: <local | staging | production-readonly>
verdict: <GO | CONDITIONAL-GO | NO-GO>
---

# <title>

## What changed

| PR | repo | what changes |
|---|---|---|
| | | |

## Observable effect

What changes in the system if the code works. "Code runs" is invalid — it must be observable: visible text, updated database record, completed transaction.

## Minimum Injection Point

The closest point to the changed code where real input can be injected and real output observed. Document why upstream points were discarded.

## What is NOT being validated

Everything upstream or downstream of the injection point. Avoid confusing "validated effect" with "validated entire end-to-end flow".

## Prerequisites

Required running services, port-forwards, credentials, seed data.

## Steps

1.

## Pass criteria

Observable criteria verifiable by another person without asking.

## Failure criteria and interpretation

Distinguish code regressions from environment or trigger failures.

## Execution result
