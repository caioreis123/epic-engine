---
card: EPIC-101
title: "Annual Plan Upgrade Popover Experiment"
slug: sample-epic-annual-upgrade
created_at: 2026-10-01-0900
status: in-progress
---

# Annual Plan Upgrade Popover Experiment

## Objective

Test whether presenting an annual upgrade popover modal to eligible monthly subscribers increases conversion to annual subscription plans without negatively impacting churn.

## Verbatim Requirements

1. Target active subscribers on monthly plans with tenure >= 3 months.
2. Display an upgrade popover modal upon entering the account dashboard.
3. Serve dynamic discount pricing calculated server-side in `graphql-bff`.
4. Render UI modal matching Figma tokens and layout specifications (`exported-design/upgrade-modal/`).
5. Emit standardized analytics events (`component_view` and `upgrade_cta_click`) containing surface and experiment variation dimensions.
6. Support A/B experiment variations: Control (no popover) vs. Variant B (discounted annual popover with savings badge).

## Eligibility Contract

- `is_active_subscriber == true`
- `plan_interval == 'monthly'`
- `consecutive_months_active >= 3`
- `has_pending_cancellation == false`
