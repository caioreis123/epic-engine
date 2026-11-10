---
name: implement-target-repo
description: >-
  Repository-specific specialization playbook template. Use when executing tasks in repositories
  with strict local invariants, minimal-mock rules, custom build sequences, or specialized regression suites.
---

# Implement Target Repository Specialization

Read `docs/workflow-contract.md` for authorization, ownership, tracking, and repository boundaries.

## Overview

Complex software systems feature specialized repositories (such as end-to-end regression suites, compiler toolchains, or visual regression testing monorepos) with strict invariants that generic coding workflows easily violate.

Whenever a repository imposes strict operational constraints, create an `implement-<target-repo>` playbook that `agent-executor` dynamically loads when dispatched to that repository.

## Canonical Example: Visual Regression & Baseline Suites

Using visual regression testing as a concrete model:

### 1. Minimal-Mock Rule Hierarchy
Never mock when real services can be exercised:
1. **Tier 1 (Real Services):** Run against live local backend and frontend instances.
2. **Tier 2 (Real Seed Users):** Exercise real eligible test profiles with full database records.
3. **Tier 3 (Explicit Mocking):** Permitted only when external network dependencies are genuinely unreachable. Every mock requires a documented justification in the PR description.

### 2. Upstream Ordering Dependency
Target verification tasks close the implementation queue:
- Upstream backend APIs (`graphql-bff`) and frontend components (`web-app`) must land on their integration branches before baseline capture begins.
- Never run target regression tasks in parallel with the code changes they verify.

### 3. Local Bring-Up Sequence
Document exact prerequisites and deterministic startup commands:
- Required port-forwards and service health checks.
- Schema synchronization commands (`run-sync-schema`).
- Dedicated test runners with clean teardown hooks.

## Customizing for Your Repository

When adapting this template for other repositories (e.g., `implement-billing-worker` or `implement-graphql-bff`):
1. **Declare Invariants:** State non-obvious rules (e.g. database migration ordering, codegen requirements, lint constraints).
2. **Define Test Strategy:** Specify unit, integration, and contract test commands.
3. **Document Failure Modes:** Detail common compile or CI gotchas and their verified resolutions.
