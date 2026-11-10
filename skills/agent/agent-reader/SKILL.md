---
name: agent-reader
description: >-
  Spawns a short-lived Herdr pane on the cheapest model tier (reader in models.json)
  for bounded read-only codebase questions, preserving orchestrator context tokens
  and returning path:line citations.
---

# Agent Reader

## Goal

Delegate a small, bounded read-only codebase question to a fast, low-cost assistant running in a separate pane.

## Cost-Efficiency Motivation

Frontier reasoning models operating as orchestrators burn excessive tokens reading dozens of files to answer simple questions like "where is X registered?" or "what are the enum variants for Y?".

`agent-reader` routes bounded read-only questions to the cheapest model tier (`reader` in `models.json` — e.g. Haiku or Gemini Flash-Lite with a strict 10-minute / 5M-token budget). This protects orchestrator context windows and reduces token spend by up to 90% during codebase exploration.

## Dispatching the Reader

```bash
skills/agent/agent-reader/agent-reader.sh --scope <directory> '<bounded-question>'
```

Example:
```bash
skills/agent/agent-reader/agent-reader.sh --scope packages/billing "Where is the subscription renewal webhook handled?"
```

## Completion Protocol

When the reader completes, it sends a notification back to the calling pane:
`cheap-reader-ready: report in <REPORT>; pane <PANE>`

1. Read the report from `REPORT`.
2. Confirm citations use `path:line` format.
3. Verify critical findings directly in the caller session.
4. Close the temporary reader pane:
   ```bash
   herdr pane close <PANE>
   ```

## Constraints

- Exactly one bounded question per run.
- Read-only operations only: no file modifications, no code commits.
- No network access or external skill invocations.
