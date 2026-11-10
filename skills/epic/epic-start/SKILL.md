---
name: epic-start
description: "Assembles an epic dossier from Jira, Notion, refinement.md, or current conversation context, including sources, attachments, and design references. Use to initialize or document an epic."
---

# Epic Start

Read `docs/workflow-contract.md` for authorization, ownership, tracking, and repository boundaries.

Initializes an epic dossier in `${EPIC_ROOT:-$HOME/epics}/[<group>/]<short-name>/` and stops. Does not write specifications or plans prematurely, as these require verified findings.

## Usage

```
/epic-start [[<group>/]<short-name>] [<card | specification URL>]
```

Input sources in priority order:
1. Issue key (e.g. `EPIC-101`) or specification URL.
2. `${EPIC_ROOT:-$HOME/epics}/[<group>/]<short-name>/refinement.md`.
3. Active discussion context when requirements are established.

## Workflow

### 1. Ingest Input

Extract:
- Issue key and title.
- Verbatim requirements (never paraphrase: requirements constitute the delivery contract).
- Design links (Figma), discussion threads, and architecture notes.

### 2. Scaffold Dossier Structure

Create the epic directory structure:
```text
<epic-root>/<slug>/
├── 00-BRIEFING.md          # Card goal, verbatim requirements, source index
├── links.md                # Issue tracker, specs, Figma, monitoring links
├── inbox.jsonl             # Empty event log for asynchronous worker callbacks
├── findings/               # Verified discovery findings
├── decisions/              # Architectural decision records
├── specs/                  # Technical specifications
├── plans/                  # Implementation plans and tracking tables
├── reviews/                # Batch review reports
└── validations/            # Pre-merge and post-merge verification plans
```

### 3. Generate Briefing and Links

Populate `00-BRIEFING.md` with frontmatter:
```yaml
---
card: EPIC-101
title: "<Epic Title>"
slug: <slug>
created_at: <YYYY-MM-DD-HHMM>
status: draft
---
```

Populate `links.md` with categorized references.
Run `epic-context <slug>` to verify identity and dossier accessibility.
