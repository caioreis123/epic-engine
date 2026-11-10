---
name: agent-executor
description: >-
  Dispatches a worker agent in a dedicated Herdr tab inside an isolated git worktree
  to implement a task, load domain specializations (implement-*), open a draft PR,
  run code review above itself via agent-reviewer, and notify the orchestrator pane.
---

# Agent Executor

## Overview

Dispatches **one worker agent** to execute an authorized task in an isolated workspace.

Supported delivery modes:
- **`pr` (default):** Spawns a worker inside an isolated git worktree (`epic/<slug>`), loads domain specializations (`implement-ui`, `implement-events`, `implement-target-repo`), implements changes, opens a draft PR, runs code review, and writes a completion event to `<epic>/inbox.jsonl`.
- **`finding`:** Spawns an investigator inside the repository to answer exactly one question, recording evidence in `findings/<date>-<topic>.md` without creating git branches or PRs. (See [references/investigation.md](references/investigation.md)).
- **`lead`:** Spawns a lead coordinator inside the epic dossier to manage parallel worker executors across multiple repositories. (See [references/lead.md](references/lead.md)).

```
brief → implement → verify → draft PR → review in upper pane → fix findings → notify lead pane
```

## Quick Dispatch via CLI

Dispatch in a single command (prepares worktree, opens Herdr tab, stamps metadata, and delivers brief):

```bash
lib/agent-lib/agent-executor.sh <repo> <slug> <tab-name> <brief-path> [--delivery pr|finding|lead] [--task task-<N>]
```

Example:
```bash
lib/agent-lib/agent-executor.sh web-app annual-upgrade exe-101-upgrade-modal /path/to/brief.md --task task-1
```

## Execution Protocol

1. **Harness Detection:** `provider-routing.sh` automatically detects the calling session harness (`claude`, `opencode`, `codex`, `agy`, or `reasonix`) and preserves the same CLI environment in the spawned tab.
2. **Worktree Isolation:** The agent works in a separate directory (`<repo>-epic-<slug>`) on branch `epic/<slug>`, leaving parent checkouts untouched.
3. **Pane Metadata Stamping:** The session is stamped with `--epic <slug> --task task-<N> --stage implement` using `pane-tokens.sh`, grouping the pane cleanly in `epic-panes.py` and Herdr dashboards.
4. **Dynamic Specialization:**
   - Tasks touching UI layout load `implement-ui` for Pillow bounding-box and color assertions against Figma exports.
   - Tasks emitting analytics load `implement-events` for end-to-end telemetry verification.
   - Tasks in repositories with strict local invariants load `implement-target-repo`.
5. **Draft Pull Request:** Once verified locally, the agent pushes the branch and opens a draft PR following [references/pr-template.md](references/pr-template.md):
   ```bash
   gh pr create --draft --title "feat(modal): implement annual upgrade modal (task-1, EPIC-101)" --body-file /tmp/pr-body.md
   ```
6. **Self-Review Dispatch:** The executor triggers `agent-reviewer` to split the pane directly above itself, running an independent high-reasoning review pass against the PR diff.
7. **Durable Completion Notification:** The executor appends a completion record to the epic's `inbox.jsonl` and drains the event:
   ```bash
   echo '{"ts":"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'","type":"done","task":"task-1","pr":"https://github.com/acme/web-app/pull/42","worker":"'$HERDR_PANE_ID'"}' >> inbox.jsonl
   python3 lib/agent-lib/agent-watchdog.py drain inbox.jsonl --lead $LEAD_PANE_ID
   ```
