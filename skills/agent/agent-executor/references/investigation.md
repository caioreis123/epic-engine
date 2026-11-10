# Delivery Mode: Delegated Investigation (`finding`)

Read this guide when dispatching an investigation.

The workflow:
```
brief in briefs/ → repo tab → investigate → finding in findings/ + card comment → notify return pane → close tab
```

Unlike PR implementation, an investigator delivers documentation:
a finding in `findings/` and an evidence comment on the issue card. The investigator may execute commands, query services, and run tests. However, the investigator **does not open PRs and does not commit code**.

Always use a fresh session: investigators should not inherit conversational noise from other topics. Everything the investigator needs must be in the brief. The brief is versioned in the epic dossier, allowing full provenance auditing.

## 1. Load the Epic Dossier

```bash
lib/epic-lib/epic-context.sh <slug>
```

Prints `EPIC=`, `CARD=`, `SLUG=`, `TITLE=`, and active findings. The "What is already known" section of the brief derives from here.

## 2. Exactly One Question

If a question has two parts, dispatch two investigations. A finding that partially answers two questions answers neither conclusively.

If the question lacks an observable stop criterion, narrow the question with the user before spawning. An investigator without stop criteria spends tokens aimlessly.

## 3. Structure the Brief

Record the return address:
- Dispatcher: `$HERDR_PANE_ID`
- Lead: `$LEAD_PANE_ID`
- Inbox: `<epic>/inbox.jsonl`

## 4. Fill Required Brief Sections

- **The Question:** Exactly one question ending with `?`.
- **Stop Criteria:** Observable evidence required to prove the answer.
- **What is Already Known:** Citations to relevant findings and decisions in the dossier.
- **Where to Look:** Repositories, files, and commands to inspect.
- **What NOT to Reopen:** Fixed decisions that must not be questioned without hard counter-evidence.

## 5. Dispatch via CLI

```bash
skills/agent/agent-executor/agent-executor.sh <repo> <slug> <tab-name> <brief-path> --delivery finding
```

The script spawns an investigator tab on the `investigator` role tier without creating a worktree or PR branch.

## 6. Completion and Callback

When complete, the investigator writes `findings/<date>-<topic>.md`, writes a callback event to `<epic>/inbox.jsonl`, wakes the dispatcher with `agent-prompt.sh`, and drains watchdog state.
