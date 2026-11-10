# Technical Specification: Annual Plan Upgrade Popover

## System Overview

Introduces an annual upgrade popover for eligible monthly subscribers across `acme/graphql-bff`, `acme/web-app`, and `acme/visual-check`.

```
User Browser (web-app)
   │
   ├─► Query: AnnualUpgradeOffer (graphql-bff)
   │     │
   │     ├─► SubscriptionService (Tenure & Plan Check)
   │     └─► FeatureFlagService (Variant Assignment)
   │
   └─► Render UpgradeModal (if eligible)
         │
         └─► Emit Telemetry (analytics_prod)
```

## GraphQL Schema Additions (`acme/graphql-bff`)

Per `docs/server-payload-rules.md`, server-driven copy and calculated pricing are delivered via a single typed object:

```graphql
type AnnualUpgradeOffer {
  isEligible: Boolean!
  annualPlanId: ID
  headlineText: String
  subheadlineText: String
  monthlyInstallmentPriceText: String
  totalAnnualPriceText: String
  savingsPercentageText: String
  ctaLabelText: String
  checkoutUrl: String
}

extend type Query {
  annualUpgradeOffer: AnnualUpgradeOffer!
}
```

## Frontend Components (`acme/web-app`)

- `AnnualUpgradeModalContainer`: Queries `annualUpgradeOffer`, controls session dismissal cookies.
- `AnnualUpgradeModal`: Pure UI presentation matching Figma tokens (`implement-ui`).
- `useUpgradeTelemetry`: Dispatches `component_view` and `upgrade_cta_click` (`implement-events`).

## Visual Regression Suite (`acme/visual-check`)

- Scenarios: `annual-upgrade-modal-desktop`, `annual-upgrade-modal-mobile`.
- Minimal-mock assertions verifying modal geometry and responsive layouts.
