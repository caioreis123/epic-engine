---
question: "Can subscription tenure be determined directly from existing billing models?"
short_answer: "Yes, active subscriptions expose consecutive billing cycles in billing_db."
conclusions:
  - "confirmed | 2026-10-01T10:00:00Z | (original)"
investigator: "inv-tenure-check"
---

## Answer

Existing subscription records in `billing_db.subscriptions_view` track consecutive active billing intervals without requiring additional database migrations.

## Evidence

| statement | provenance |
|---|---|
| Tenure is stored as integer cycle count | **code** — `graphql-bff@main` `src/services/subscription.ts:42` |
| Zero migration needed | **doc** — Billing Service Architecture Spec |

## How to reproduce

```bash
psql -c "SELECT id, user_id, consecutive_cycles FROM subscriptions WHERE user_id = '100001';"
```
