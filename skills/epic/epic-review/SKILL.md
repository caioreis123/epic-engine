---
name: epic-review
description: "Reviews integration pull requests for an epic and records structured reports in the epic dossier pinned to evaluated commit SHAs."
---

# Epic Review

Read `docs/workflow-contract.md` and `docs/integration-pr-model.md` for authorization, ownership, tracking, and repository boundaries.

Runs an independent, author-blind batch review across all active integration PRs of an epic before advancing to `/epic-split`. Reports are versioned inside `<epic>/reviews/<runid>/` rather than ephemeral temp directories.

## Usage

```bash
/epic-review <epic-hint> <pr-url-or-number>...
```

`<epic-hint>` represents the epic slug or issue card key.

## Review Report Contract

The consolidated review report is saved to `<epic>/reviews/<runid>/BATCH-REPORT.md` with commit-pinned frontmatter:

```yaml
---
status: completed
heads:
  - "graphql-bff | 4a3b2c1d0e9f8a7b6c5d4e3f2a1b0c9d8e7f6a5b"
  - "web-app | 1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b"
---
```

## Review Protocol

1. **Diff Annotation:** Diff content is pre-processed with the AWK line annotator (`skills/agent/agent-reviewer/references/awk-diff-annotator.md`).
2. **Correctness Pass:** Audits comparison boundaries, boolean logic, race conditions, and error handling (`skills/agent/agent-reviewer/references/correctness.md`).
3. **Quality Pass:** Audits test coverage gaps and verifies integration coverage for updated contracts (`skills/agent/agent-reviewer/references/quality.md`).
4. **Resolution:** Critical and Important findings are addressed on the integration branch before proceeding to PR splitting.
