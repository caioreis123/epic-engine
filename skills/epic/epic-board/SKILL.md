---
name: epic-board
description: Opens or focuses the kanban task board tab in Herdr pinned to the active epic.
---

# Epic Board

Opens a `board` tab in the active Herdr workspace, pinned to the epic from the calling session's context. Displays task cards grouped by stage (`implement`, `review`, `split`, `validation`, `done`) reflecting the plan tracking table.

## Usage

```bash
/epic-board [<epic-hint>]
```

## Workflow

### 1. Resolve Epic Context

```bash
EPIC="$(lib/epic-lib/epic-context.sh --path <epic-hint>)"
SLUG="$(basename "$EPIC")"
```

### 2. Identify Active Herdr Workspace

Locates the active workspace ID using Herdr environment variables or session metadata (`$HERDR_WORKSPACE_ID`).

### 3. Focus or Open Board Tab

Checks whether a board tab is already open in the workspace:
- If open: focuses the existing board tab and updates the epic filter.
- If absent: opens a new tab running `herdr plugin open epic-board --epic "$SLUG"`.
