# Epic Engine Architecture & System Design

Epic Engine is a multi-agent software development lifecycle (SDLC) operating system. It organizes autonomous coding agents into a deterministic, disk-backed control plane with a harness-agnostic execution runtime.

---

## 1. System Overview: The Three Namespaces

Epic Engine structures multi-agent development into three intuitive namespaces:

```
┌────────────────────────────────────────────────────────────────────────┐
│                   1. THE CONTROL PLANE: epic-*                         │
│  Dossier State Machine · Divergence Table · Integration PR Model        │
│  3-Stage Validation Pipeline: pre-merge -> post-merge -> post-exp      │
└────────────────────────────────────┬───────────────────────────────────┘
                                     │ dispatches
                                     ▼
┌────────────────────────────────────────────────────────────────────────┐
│                   2. THE MULTI-AGENT RUNTIME: agent-*                  │
│  Herdr Multiplexer · Event Callbacks (inbox.jsonl & watchdog)          │
│  Harness Adapters (claude · opencode · codex · agy · reasonix)         │
│  Topology: agent-reader · agent-executor · agent-reviewer              │
└────────────────────────────────────┬───────────────────────────────────┘
                                     │ dynamically loads
                                     ▼
┌────────────────────────────────────────────────────────────────────────┐
│               3. DOMAIN SPECIALIZATION & EVOLUTION: implement-*        │
│  implement-ui (Pillow <= 3pp) · implement-events (Telemetry Funnel)    │
│  implement-target-repo (Invariants) · implement-skill-improvements     │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Namespace 1: `epic-*` — The SDLC Control Plane

The Control Plane manages disk-backed state without ephemeral memory drift. Every state transition is observable through committed markdown frontmatters in the epic dossier (`00-BRIEFING.md`, `specs/`, `plans/`, `reviews/`, `validations/`, `findings/`, and `decisions/`).

### The Integration-First, Split-Last PR Model

Traditional stacked PR workflows suffer from cascading rebases whenever requirements change mid-flight. Epic Engine eliminates this friction:
1. **Iterate on Integration Branches:** Workers build on a single integration branch per repository (`epic/<slug>`), adding stamped commits (`task-<N>, EPIC-nnn`).
2. **Batch Code Review:** `/epic-review` audits the integration branch in place with frontier reasoning models.
3. **Commit-Grouped Splitting:** Once the diff stabilizes, `/epic-split` slices the commits into atomic child PRs without patch drift, inserting the synchronized review-wave table.

```
Iterative Phase:
[main] ────────────────────────────────────────────────────────►
   │
   └─► [epic/<slug>] ──(task-1)──►──(task-2)──►──(task-3)──► [Integration Review]

Split Phase (/epic-split):
   ┌─► [slice-1: task-1] (PR #1) ───────┐
   ├─► [slice-2: task-2] (PR #2) ───────┼──► [Review-Wave Table Spliced]
   └─► [slice-3: task-3] (PR #3) ───────┘
```

### The Three-Stage Validation Pipeline

```
┌───────────────────────────┐
│ /epic-validate-pre-merge  │  Minimum Injection Point probe before merge (GO verdict)
└─────────────┬─────────────┘
              ▼
┌───────────────────────────┐
│ /epic-merge               │  Sequenced squash-merges following review-wave dependencies
└─────────────┬─────────────┘
              ▼
┌───────────────────────────┐
│ /epic-validate-post-merge │  State x Surface production journey split-screen recording
└─────────────┬─────────────┘
              ▼
┌───────────────────────────┐
│ /epic-validate-post-exp   │  Post-activation hash bucketing, warehouse exposure, SRM check
└─────────────┬─────────────┘
              ▼
┌───────────────────────────┐
│ /epic-release-experiment  │  Feature flag activation announcement to engineering channels
└───────────────────────────┘
```

---

## 3. Namespace 2: `agent-*` — The Herdr Multi-Agent Runtime

The multi-agent execution runtime is built on **Herdr** (the terminal multiplexer) and a **Harness-Agnostic Adapter Layer**.

### Roles & Topology

- **`agent-reader`:** Lightweight, low-latency agent running on low-cost tiers (`reader` in `models.json`, e.g. Haiku / Flash-Lite). Resolves bounded codebase lookup questions (`path:line`), preserving the orchestrator's context window.
- **`agent-executor`:** High-throughput worker running in an isolated git worktree (`epic/<slug>`). Implements atomic tasks, creates draft PRs, and triggers reviews.
- **`agent-reviewer`:** Frontier reasoning agent (`reviewer` in `models.json`) spawned via `herdr pane split down` + `herdr pane swap` directly above the executor. Evaluates code blindly using AWK line-annotated diffs.

```
Herdr Tab:
┌────────────────────────────────────────────────────────┐
│ agent-reviewer (Split Upper Pane)                      │
│ - Author-blind frontier reasoning model                │
│ - Evaluates AWK-annotated diffs against checklists     │
├────────────────────────────────────────────────────────┤
│ agent-executor (Main Lower Pane)                       │
│ - Isolated worktree (<repo>-epic-<slug>)               │
│ - Dispatches tasks, opens draft PRs, fixes findings    │
└────────────────────────────────────────────────────────┘
```

### Harness-Agnostic Architecture

Epic Engine operates seamlessly across all major AI coding CLIs without code modification:

```
┌────────────────────────────────────────────────────────────────────────┐
│                        Harness-Agnostic Adapters                       │
│  claude (--settings) · opencode (plugin) · agy (hooks) · reasonix/codex │
└────────────────────────────────────┬───────────────────────────────────┘
                                     │
                                     ▼
┌────────────────────────────────────────────────────────────────────────┐
│                           turn-hook.py                                 │
│  State Machine: prompt -> tool -> stop                                  │
│  Enforces time budgets, token limits, and guaranteed notifications     │
└────────────────────────────────────┬───────────────────────────────────┘
                                     │
                                     ▼
┌────────────────────────────────────────────────────────────────────────┐
│                           agent-prompt.sh                              │
│  Herdr prompt delivery, blocked state handling, Enter key fallbacks    │
└────────────────────────────────────────────────────────────────────────┘
```

- **Claude Code (`claude`):** Settings injection via `--settings <file>` intercepts lifecycle hooks.
- **OpenCode (`opencode`):** Event interception via `opencode-turn-hook.js`.
- **Antigravity (`agy`):** Global hooks configuration routed through `agy-turn-adapter.sh`.
- **Codex (`codex`):** Output stream tracking and budget enforcement.
- **Reasonix (`reasonix`):** Direct CLI hook integration via configuration bridge.

---

## 4. Namespace 3: `implement-*` — Specialization & Meta-Evolution

Task executors dynamically load specialized implementation playbooks based on task requirements:
- **`implement-ui`:** Quantitatively verifies element layout using Python Pillow relative bounding boxes (`<= 3pp`) and icon RGB distance (`< 40`) against Figma exports.
- **`implement-events`:** Audits the complete analytics telemetry pipeline from UI dispatchers to data warehouse tables.
- **`implement-target-repo`:** Specialization pattern for repositories with strict local invariants and minimal-mock test hierarchies.
- **`implement-skill-improvements`:** The automated self-improvement engine. Analyzes transcripts after user corrections and proposes surgical improvements across all skills.
