---
name: epic-analyze-metrics
description: >-
  Analyzes experiment metrics from live dashboards: evaluates statistical superiority
  or non-inferiority, checks sample ratio mismatch (SRM), computes required sample sizes,
  and determines the winning variant.
---

# Epic Analyze Metrics

Read `docs/workflow-contract.md` for authorization, ownership, tracking, and repository boundaries.

Evaluates experiment metrics against statistical decision rules:
1. Is the sample size sufficient to reach decision power (80% power at alpha 0.05)?
2. Is there evidence of Sample Ratio Mismatch (SRM chi-square `p < 0.001`)?
3. Has a variant proven statistical superiority or non-inferiority against control?

## Usage

```bash
/epic-analyze-metrics <dashboard-url> [from=YYYY-MM-DD] [type=superiority|noninferiority] [mde=<relative-lift>] [epic=<epic-hint>]
```

## Statistical Analysis Script

Run the statistical analyzer directly:
```bash
python3 skills/epic/epic-analyze-metrics/scripts/experiment_stats.py <payload.json>
```

Outputs:
- Absolute and relative conversion rates per arm.
- Confidence intervals and p-values.
- Sample size requirements and estimated completion date (ETA).
- Winning variant declaration when significant.

## Recording Verdict in Epic Dossier

Record the analysis in `<epic>/findings/<date>-experiment-metrics.md`.
If a variant has decisively won, advance to `/epic-rollout`.
