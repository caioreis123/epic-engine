# Multi-Agent Runtime Contract

This contract governs the multi-agent execution runtime powered by **Herdr** and the **Harness-Agnostic Adapter Layer**. Calling skills define task deliverables and execution policies.

## Pre-Dispatch Requirements

The brief declares the authorized deliverable, the expected artifact, the issue tracker owner, and the return address pane.
Run within the active workspace of the calling session unless explicitly specified otherwise.
Creating a session does not authorize creating tickets, opening pull requests, merging code, or broadcasting messages.
If no task is assigned, hand the session directly to the operator without arming autonomous monitors.

Use `agent-executor.sh` or Herdr primitives to prepare the worktree and spawn the session.
Preflight checks ensure necessary environment variables are set and prevent unwanted `.env` loading.

## Asynchronous Coordination and Notification

Agents notify you upon completion; you do not poll or monitor agents in busy loops.
The task brief records the return address: the caller's Herdr pane ID (`$HERDR_PANE_ID`).
Dispatch the task and end your turn.
The spawned agent wakes the caller via `agent-prompt.sh` or by draining the epic's `inbox.jsonl` using `agent-watchdog.py drain`.

Never arm polling loops, `herdr agent wait`, or repeated pane reads.
Each agent turn completion would wake the orchestrator prematurely, consuming tokens unnecessarily.
The turn hook (`turn-hook.py`) guarantees safety: if an agent session (running Claude Code, Antigravity, OpenCode, Codex, or Reasonix) finishes a turn without notifying its caller, the hook automatically wakes the return address with an excerpt of the agent's last response.

## Harness-Agnostic Execution Layer

The execution engine runs seamlessly across multiple AI coding harnesses:

| Harness | Family | Hook & Token Mechanism |
|---|---|---|
| `claude` | Anthropic | Injected via `--settings` into Claude Code lifecycle |
| `opencode` | Google / Multi | Injected via `opencode-turn-hook.js` plugin adapter |
| `agy` | Google / Antigravity | Injected via `agy-turn-adapter.sh` from global hooks config |
| `codex` | OpenAI | Native CLI wrapper tracking output deltas |
| `reasonix` | DeepSeek | Configured via `~/.reasonix/settings.json` hook command |

Each harness translates its native lifecycle into the unified turn hook state machine:
- `prompt`: resets turn budgets when user inputs arrive.
- `tool`: tracks token and time budgets against `models.json` defaults.
- `stop`: enforces durable notifications back to the caller.

## Delivery Verification

To verify asynchronous delivery, inspect the epic's `inbox.jsonl` or run a read-only check script:

```bash
python3 lib/agent-lib/agent-watchdog.py drain <epic>/inbox.jsonl --lead $HERDR_PANE_ID
```

| State | Orchestrator Action |
|---|---|
| `completed` | Inspect the artifact or PR diff and mark task complete |
| `blocked` | Address blocker, provide guidance, or re-route |
| `stall` | Nudge agent via watchdog or rotate context session |
