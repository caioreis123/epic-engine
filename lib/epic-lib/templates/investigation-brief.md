---
epic: <epic-slug>
question: "<the investigated question, exactly one>"
created_at: <YYYY-MM-DD-HHMM>
status: open
card: <EPIC-nnn or empty>
investigator: <tab name, filled by investigator>
---

# <question>

## The Question

Exactly one. If there are two, these are two investigations — the brief does not accumulate questions.

## Stop Criteria

What constitutes an answer: what needs to be demonstrated for the question to be resolved.

And the limit: if it cannot be answered with what exists, **record as unverified and stop**. Digging indefinitely costs more than an honest partial answer.

## What is already known

Summary of the epic briefing and related findings. Point to files — do not copy their contents, or the brief rots when they change.

## Where to look

Repos, services, files, and commands likely containing the answer. State what was already ruled out, to avoid retracing steps.

## What NOT to reopen

Decisions already made, one per line, each with the recording file (`decisions/<file>.md`). The investigator records contradictory evidence while preserving provenance (`measured` remains `measured`).
Describe the conflict in the new finding. The orchestrator decides whether to reopen the decision.

## Return address

Dispatcher: `<dispatcher pane>`
Epic Lead: `<epic lead pane>`
Inbox: `<epic inbox path>`

The final act of investigation, after writing the finding, is notification. Complete these three steps in order:

1. Write a line to inbox. The line is the durable record: a rejected notification does not erase it.

   ```bash
   echo '{"ts":"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'","type":"finding","slug":"<slug>","file":"findings/<file>.md","from":"'$HERDR_PANE_ID'"}' >> <inbox>
   ```

2. Notify the lead pane if specified.
3. Drain watchdog or exit.
