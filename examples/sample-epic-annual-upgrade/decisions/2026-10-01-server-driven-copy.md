---
title: "Server-driven copy for modal headline and discount badges"
status: accepted
date: 2026-10-01
---

# Decision: Server-Driven Copy for Upgrade Modal

## Context
Figma specifies dynamic discount percentages and promo text based on subscriber tenure.

## Decision
All user-facing copy strings are computed and delivered via `graphql-bff` in the `AnnualUpgradeOffer` payload per `docs/server-payload-rules.md`. The web client performs zero string concatenation or hardcoded price text formatting.
