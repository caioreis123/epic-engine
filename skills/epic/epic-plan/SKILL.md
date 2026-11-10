---
name: epic-plan
description: "Produces technical specification, implementation plan, and tracking breakdown for an epic. Use to plan delivery; creates sub-tasks when authorized."
---

# Epic Plan

Read `docs/workflow-contract.md` and `docs/integration-pr-model.md` for authorization, ownership, tracking, and repository boundaries.

Orchestrates: Dossier → Architecture Spec + Plan → Operator Approval → Task Decomposition → Handoff to `epic-implement`.

## 1. Resolve the Epic Dossier

```bash
EPIC="$(lib/epic-lib/epic-context.sh --path <epic-hint>)"
```

Exit 5 (not found): Stop. Epic planning requires an existing dossier initialized by `/epic-start`.

## 2. Ingest Inputs and Architecture Rules

Read in order:
- `00-BRIEFING.md`: verbatim requirements.
- `decisions/` and `findings/`: established constraints and evidence.
- Repository architectural guidelines.
- `docs/server-payload-rules.md`: rules for GraphQL BFF payloads and copy ownership.
- `docs/web-events-rules.md`: telemetry guidelines and event parameter standards.

## 3. Generate Technical Specification (`specs/<date>-<topic>-spec.md`)

Cover:
- System overview and sequence diagrams across participating repositories.
- Schema definitions and API contracts.
- Frontend component hierarchy and state management.
- Telemetry event contracts and warehouse targets.

## 4. Generate Implementation Plan (`plans/<date>-<topic>-plan.md`)

Structure implementation according to the **Integration PR Model**:
- One integration branch per repository (`epic/<slug>`).
- One commit per task, stamped with `task-<N>` and issue key (`EPIC-101`).
- Explicit binding of task types to specialization playbooks:
  - UI tasks -> `implement-ui`
  - Analytics tasks -> `implement-events`
  - Target repository tasks -> `implement-target-repo`

Include the canonical tracking table:

```markdown
## Tracking

| # | Task | Stage | Repo | Card | Evidence |
|---|---|---|---|---|---|
| 1 | Server-side eligibility check | implement | graphql-bff | EPIC-102 | |
| 2 | Annual upgrade modal component | implement | web-app | EPIC-103 | |
| 3 | Telemetry event dispatching | implement | web-app | EPIC-104 | |
| 4 | Visual regression baselines | implement | visual-check | EPIC-105 | |
```
