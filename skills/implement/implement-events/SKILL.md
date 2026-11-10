---
name: implement-events
description: >-
  Use when adding, modifying, or auditing analytics telemetry events: verifies the full telemetry contract
  from frontend component props and backend resolvers to downstream data warehouse columns.
---

# Implement Events

Read `docs/workflow-contract.md` and `docs/web-events-rules.md` for authorization, ownership, tracking, and repository boundaries.

An analytics event is only verified when it lands in warehouse tables with the exact schema dimensions expected by analytics models.
Code diff inspection alone is insufficient: payloads passed to the data layer depend on runtime context providers, inherited wrappers, and backend GraphQL resolvers.

## Workflow

### 1. Telemetry Funnel Contract
Establish the mapping table before modifying code:
- **Business Question:** What user behavior is being evaluated?
- **Trigger Event:** Component view (`IntersectionObserver`) or interaction click.
- **Payload Attributes:** Surface name, initiative identifier, user ID, component class.
- **Warehouse Target:** Target table and column mapping (e.g. `analytics_prod.experiment_events`).

### 2. End-to-End Funnel Audit
Map the complete funnel progression across all user paths:
- Entry surface (popover, modal, email, navigation banner) -> click event.
- Intermediate landing surface -> view and interaction events.
- Checkout / Conversion surface -> transaction submission event.

Each step requires a dedicated view event. Do not overload one event name with multiple funnel stages.

### 3. Inherited Component Telemetry Audit
When reusing shared components:
- Inspect child leaf components to identify inherited event dispatchers.
- Avoid duplicate events where both parent and child containers emit redundant telemetry.
- Verify parameters follow clean naming standards without ambiguous selectors (`selectedOption` is forbidden).

### 4. Verification
Execute local integration tests asserting that event dispatchers receive expected parameters. Attach verified telemetry logs to the PR description.
