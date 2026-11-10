# Review-Wave Table Specification

The review-wave table maps cross-repository and stacked dependencies across a multi-PR delivery wave. It must be placed at the very top of each participating PR description.

## Splicing Markers

```markdown
<!-- review-wave:start -->
<!-- review-wave:end -->
```

Everything between these HTML comment markers is managed deterministically. Content outside the markers is preserved.

## Table Structure

Tables are grouped by repository in order of dependency execution (upstream schemas/APIs first, frontend components second, validation suites last):

```markdown
<!-- review-wave:start -->
## Annual Upgrade Wave (EPIC-101)

### GRAPHQL-BFF
| Step | PR | Card | Order | Depends |
|---|---|---|---|---|
| BFF-1 · Server-side eligibility check | [#101](https://github.com/acme/graphql-bff/pull/101) | [EPIC-102] | 1 | |

### WEB-APP
| Step | PR | Card | Order | Depends |
|---|---|---|---|---|
| WEB-1 · Annual upgrade modal UI | [#201](https://github.com/acme/web-app/pull/201) | [EPIC-103] | 2 | [#101](https://github.com/acme/graphql-bff/pull/101) |
| WEB-2 · Telemetry event dispatching | [#202](https://github.com/acme/web-app/pull/202) | [EPIC-104] | 3 | [#201](https://github.com/acme/web-app/pull/201) |

### VISUAL-CHECK
| Step | PR | Card | Order | Depends |
|---|---|---|---|---|
| <mark>**VC-1 · Upgrade modal baselines**</mark> 📍This PR | **#51** | [EPIC-105] | 4 | [#201](https://github.com/acme/web-app/pull/201) |
<!-- review-wave:end -->

[EPIC-102]: https://acme.atlassian.net/browse/EPIC-102
[EPIC-103]: https://acme.atlassian.net/browse/EPIC-103
[EPIC-104]: https://acme.atlassian.net/browse/EPIC-104
[EPIC-105]: https://acme.atlassian.net/browse/EPIC-105
```

Highlight the current PR row with `<mark>**...**</mark> 📍This PR` and bold text.
