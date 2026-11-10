#!/usr/bin/env python3
"""Watchdog and inbox drain for agent sessions.

Two functions, both local (0 model tokens):

1. check <pane>  — classifies agent state: OK | STALL | BLOCKED | DARK | FAIL.
   Only checks elapsed clock time to trigger inspection; classification inspects
   pane text, status, and digest progress. With --nudge, sends the agent a prompt
   requesting Partial:true.

2. drain <inbox> — called by workers immediately after recording an event line.
   Wakes the lead (via agent-prompt.sh) with the range of new lines and advances
   the cursor file upon delivery.

Usage:
  agent-watchdog.py check <pane> [--role worker] [--elapsed-min N] [--state-file P]
                                 [--lead P] [--nudge] [--json]
  agent-watchdog.py drain <inbox> --lead <target> [--json]
"""
import json
import os
import re
import subprocess
import sys

HERDR = os.environ.get("HERDR_BIN", "herdr")
AGENT_PROMPT = os.environ.get(
    "AGENT_PROMPT_BIN", os.path.join(os.path.dirname(os.path.abspath(__file__)), "agent-prompt.sh")
)
PROMPT_TIMEOUT_SECONDS = 660
AGENT_LIB_DIR = os.environ.get("AGENT_LIB_DIR", os.path.expanduser("~/.epic-engine/lib/agent-lib"))
DARK_PATTERNS = [
    r"usage limit",
    r"rate limit",
    r"\b429\b",
    r"quota",
    r"model (is )?unavailable",
    r"too many requests",
    r"credit",
]
STALL_NUDGE = (
    "You have exceeded your time budget. STOP now and report exact status: "
    "what is done (commit/file), what remains, and where blocked. "
    "Reply on a single line starting with Partial:true."
)


def run(args):
    try:
        proc = subprocess.run(args, capture_output=True, text=True, timeout=30)
    except (OSError, subprocess.TimeoutExpired):
        return ""
    return proc.stdout


def herdr_agents():
    raw = run([HERDR, "agent", "list"])
    try:
        agents = json.loads(raw)["result"]["agents"]
    except (ValueError, KeyError, TypeError):
        return {}
    out = {}
    for agent in agents:
        info = {
            "status": agent.get("agent_status"),
            "name": agent.get("name"),
            "ctx": (agent.get("tokens") or {}).get("ctx"),
            "cwd": agent.get("cwd"),
        }
        if agent.get("pane_id"):
            out[agent["pane_id"]] = info
        if agent.get("name"):
            out[agent["name"]] = info
    return out


def pane_text(pane):
    return run([HERDR, "pane", "read", pane, "--source", "visible", "--lines", "40"])


def classify(pane, elapsed_min, role, state_file):
    agents = herdr_agents()
    info = agents.get(pane, {})
    status = info.get("status")
    tail = pane_text(pane)
    import hashlib
    digest = hashlib.sha1(re.sub(r"\s+", " ", tail).encode("utf-8", "replace")).hexdigest()
    reason = ""
    verdict = "OK"

    if any(re.search(pattern, tail, re.I) for pattern in DARK_PATTERNS):
        verdict, reason = "DARK", "pane shows usage limit or quota cap"
    elif status == "blocked":
        verdict, reason = "BLOCKED", "agent blocked in interactive prompt"
    elif elapsed_min is not None and elapsed_min >= 0:
        prev = ""
        if state_file and os.path.exists(state_file):
            prev = open(state_file).read().strip()
        if state_file:
            try:
                open(state_file, "w").write(digest)
            except OSError:
                pass
        if status == "working":
            if prev == digest:
                verdict, reason = "STALL", f"no progress in pane (>= {elapsed_min} min)"
            else:
                verdict, reason = "OK", "pane output changed; still progressing"
        elif status in ("idle", "done", None):
            verdict, reason = "OK", f"agent is {status or 'no-state'}; verify artifact"
    return {"pane": pane, "role": role, "status": status, "verdict": verdict, "reason": reason}


def cmd_check(argv):
    pane = argv[0] if argv else None
    if not pane:
        return usage()
    role = "worker"
    elapsed = None
    state_file = None
    lead = None
    nudge = False
    as_json = False
    it = iter(argv[1:])
    for arg in it:
        if arg == "--role":
            role = next(it, "worker")
        elif arg == "--elapsed-min":
            elapsed = int(next(it, "0"))
        elif arg == "--state-file":
            state_file = next(it, None)
        elif arg == "--lead":
            lead = next(it, None)
        elif arg == "--nudge":
            nudge = True
        elif arg == "--json":
            as_json = True
    result = classify(pane, elapsed, role, state_file)
    if nudge and result["verdict"] == "STALL":
        target = lead or pane
        run([HERDR, "agent", "prompt", target, STALL_NUDGE])
        result["nudged"] = True
    if as_json:
        print(json.dumps(result, ensure_ascii=False))
    else:
        print(f"{result['verdict']} pane={pane} role={role} status={result['status']} {result['reason']}")
    return 0


def cmd_drain(argv):
    inbox = argv[0] if argv else None
    if not inbox:
        return usage()
    lead = None
    as_json = False
    it = iter(argv[1:])
    for arg in it:
        if arg == "--lead":
            lead = next(it, None)
        elif arg == "--json":
            as_json = True
        else:
            return usage()
    if not lead:
        return usage()
    decision = drain_once(inbox, lead)
    if as_json:
        print(json.dumps(decision, ensure_ascii=False))
    else:
        print(f"{decision['action']} lead={lead} pending={decision['pending']} {decision.get('reason','')}")
    return 1 if decision["action"] == "FAIL" else 0


def deliver(target, text):
    try:
        proc = subprocess.run([AGENT_PROMPT, target, text], capture_output=True, text=True,
                              timeout=PROMPT_TIMEOUT_SECONDS)
    except (OSError, subprocess.TimeoutExpired) as error:
        return False, str(error)
    error_lines = proc.stderr.strip().splitlines()
    return proc.returncode == 0, error_lines[-1] if error_lines else ""


def drain_once(inbox, lead):
    lines = []
    if os.path.exists(inbox):
        with open(inbox, "r", errors="replace") as handle:
            lines = [l for l in (line.strip() for line in handle) if l]
    cursor_file = inbox + ".cursor"
    cursor = 0
    if os.path.exists(cursor_file):
        try:
            cursor = int(open(cursor_file).read().strip() or "0")
        except (ValueError, OSError):
            cursor = 0
    pending = len(lines) - cursor
    decision = {"lead": lead, "inbox": inbox, "pending": max(pending, 0), "action": "WAIT"}
    if pending <= 0:
        decision["reason"] = "inbox has no new lines"
        return decision

    first, last = cursor + 1, len(lines)
    delivered, error = deliver(lead, f"drain inbox {inbox}: lines {first}-{last}")
    if not delivered:
        decision["action"] = "FAIL"
        decision["reason"] = f"lines {first}-{last} notification failed: {error}"
        return decision
    decision["action"] = "DRAIN"
    decision["reason"] = f"lines {first}-{last}"
    try:
        open(cursor_file, "w").write(str(last) + "\n")
    except OSError:
        pass
    return decision


def cmd_context(argv):
    alert = None
    as_json = False
    it = iter(argv)
    for arg in it:
        if arg == "--alert-pct":
            alert = int(next(it, "60"))
        elif arg == "--json":
            as_json = True
    try:
        alert = alert if alert is not None else int(
            json.load(open(os.path.join(AGENT_LIB_DIR, "models.json")))["defaults"]["context_alert_pct"]
        )
    except (OSError, ValueError, KeyError, TypeError):
        alert = alert if alert is not None else 60
    raw = run([HERDR, "agent", "list"])
    try:
        agents = json.loads(raw)["result"]["agents"]
    except (ValueError, KeyError, TypeError):
        return 0
    rows = []
    for agent in agents:
        ctx = (agent.get("tokens") or {}).get("ctx")
        pct = None
        if ctx:
            found = re.search(r"(\d+)\s*%", ctx)
            pct = int(found.group(1)) if found else None
        rows.append({
            "pane": agent.get("pane_id"),
            "name": agent.get("name"),
            "agent": agent.get("agent"),
            "ctx": ctx,
            "pct": pct,
            "alert": bool(pct is not None and pct >= alert),
        })
    if as_json:
        print(json.dumps({"alert_pct": alert, "agents": rows}, ensure_ascii=False))
    else:
        for r in rows:
            mark = "ALERT" if r["alert"] else "ok"
            label = r["name"] or r["agent"] or "?"
            print(f"{mark} pane={r['pane']} {label} ctx={r['ctx'] or '?'}")
        if any(r["alert"] for r in rows):
            print(f"(context >= {alert}% — compact or drain inbox before continuing)")
    return 0


def usage():
    print(__doc__)
    return 2


def main(argv):
    if not argv:
        return usage()
    command, rest = argv[0], argv[1:]
    if command == "check":
        return cmd_check(rest)
    if command == "drain":
        return cmd_drain(rest)
    if command == "context":
        return cmd_context(rest)
    return usage()


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
