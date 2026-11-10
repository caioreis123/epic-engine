# Web Analytics Telemetry Rules: Instrumentation & Event Hygiene

Policy for component event instrumentation in web applications. Governs analytics contracts from React component dispatchers through the data layer to downstream warehouse tables.

## Standardized Telemetry Over Ad-Hoc Logging

Instrument component interactions using the standardized analytics dispatcher (`useAnalyticsDispatcher` / `dispatcher.send()`).
Do not invent secondary logging pipelines under the premise of needing user IDs for experiment joins: standard dataLayer providers automatically attach `user.id` to every outbound event, enabling seamless warehouse joins with `experiment_users` tables.

Standard dispatchers provide built-in capabilities:
- Standardized application context (`app_id`)
- Viewport intersection tracking via `IntersectionObserver`
- Impression deduplication
- Automatic viewport throttling

## Avoid Generic Ambiguous Selectors

Do not send generic selection parameters (such as `selectedOption`) that flatten conversions and dismissals into identical records. Sending ambiguous parameters results in identical events in data warehouses, making it impossible to distinguish conversions from modal dismissals.

Standard pattern: assign a distinct `componentName` to each clickable element (e.g., `confirm_upgrade_button`, `close_modal_button`).

## Unclassified Event Dimensions Require Platform Alignment

Analytics event schemas support standard properties: panel, component, and resource identifiers. When an initiative requires an unclassified dimension, coordinate with the analytics platform team before introducing custom parameter classes. In epic planning, unclassified dimensions represent platform dependencies, not autonomous implementation tasks.

## In-Place Navigation and Unload Race Conditions

Standard browser navigation (`<a href>` without `target="_blank"`) can abort pending tracking beacons on page unload. If a conversion action navigates within the same tab, specify in the epic plan whether to use `target="_blank"` or accept beacon drop rates.

## Experiment Variant Names Do Not Belong in Event Names

Panel names capture the surface and initiative (`<initiative>_<surface>` in snake_case, e.g., `annual_loyalty_modal`).
Never embed experiment arm or variant names in panel, component, or property names.
Variant assignment is an exposure attribute recorded by feature flag evaluations; overloading interaction event names with variant identifiers pollutes analytics taxonomies and breaks cross-variant funnel comparisons.
