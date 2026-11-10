#!/usr/bin/env python3
"""Status panel for active panes per epic, fetched from Herdr in a single call.

Shows what is happening right now across active panes without network calls,
git fetches, or ticket trackers. State is derived from agent_status reported by
Herdr, and grouping comes from metadata tokens stamped by agent-* skills.

Usage: epic-panes.py [<slug>] [--all]
"""
import json
import os
import re
import subprocess
import sys

HERDR_BIN = os.environ.get("HERDR_BIN", "herdr")
ATTENTION_ORDER = ["blocked", "done", "idle", "working", "unknown"]
NO_EPIC = "(no epic)"
CTX_LIMIT = int(os.environ.get("EPIC_CTX_LIMIT", "60"))


def _agents():
    result = subprocess.run(
        [HERDR_BIN, "agent", "list"], capture_output=True, text=True, timeout=20
    )
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or "herdr agent list failed")
    return json.loads(result.stdout)["result"]["agents"]


def _rows(agents, wanted, show_all):
    rows = []
    for agent in agents:
        tokens = agent.get("tokens") or {}
        epic = tokens.get("epic") or NO_EPIC
        if epic == NO_EPIC and not show_all:
            continue
        if wanted and wanted not in epic:
            continue
        rows.append(
            {
                "epic": epic,
                "task": tokens.get("task", "-"),
                "stage": tokens.get("stage", "-"),
                "status": agent.get("agent_status", "unknown"),
                "ctx": tokens.get("ctx", "-"),
                "agent": agent.get("agent", "-"),
                "pane": agent.get("pane_id", "-"),
                "name": agent.get("name", ""),
            }
        )
    return rows


def _ctx_pct(ctx):
    found = re.search(r"(\d+)%", ctx or "")
    return int(found.group(1)) if found else None


def _rank(row):
    status = row["status"]
    position = ATTENTION_ORDER.index(status) if status in ATTENTION_ORDER else len(ATTENTION_ORDER)
    return (position, row["task"], row["pane"])


def render(rows):
    if not rows:
        return "no stamped panes found (agent skills stamp metadata on dispatch)"
    lines = []
    for epic in sorted({row["epic"] for row in rows}):
        members = sorted([row for row in rows if row["epic"] == epic], key=_rank)
        blocked = sum(1 for row in members if row["status"] == "blocked")
        heavy = [row for row in members if (_ctx_pct(row["ctx"]) or 0) >= CTX_LIMIT]
        header = "%s  %d pane(s)" % (epic, len(members))
        if blocked:
            header += "  %d NEEDS ATTENTION" % blocked
        if heavy:
            header += "  %d HIGH CONTEXT" % len(heavy)
        lines.append(header)
        for row in members:
            pct = _ctx_pct(row["ctx"])
            lines.append(
                "  %-9s %-10s %-8s %-9s %-6s %-8s %-7s %s"
                % (
                    row["task"],
                    row["stage"],
                    row["status"],
                    row["name"][:9] or row["agent"],
                    row["ctx"].replace("opus ", "").replace("fable ", ""),
                    row["agent"],
                    "rotate" if pct is not None and pct >= CTX_LIMIT else "",
                    row["pane"],
                )
            )
        lines.append("")
    return "\n".join(lines).rstrip()


def main(argv):
    show_all = "--all" in argv
    positional = [arg for arg in argv if not arg.startswith("-")]
    wanted = positional[0] if positional else ""
    try:
        agents = _agents()
    except Exception as error:
        print("epic-panes: %s" % error, file=sys.stderr)
        return 5
    print(render(_rows(agents, wanted, show_all)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
