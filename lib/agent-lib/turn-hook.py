#!/usr/bin/env python3
"""Hooks for an agent session: prompt, tool, and turn end.

Supports Claude Code, Antigravity, OpenCode, and Reasonix through a unified
state machine when AGENT_TURN_STATE (or SPAWN_TURN_STATE) is set.

  prompt  a new run starts; a limit that was hit starts over.
  tool    enforces the time and token budget of the run.
  stop    a turn that ended without notifying the return address notifies it,
          unless a live session still returns to this pane, or a background shell
          or monitor of this session is still running.

Usage: turn-hook.py <prompt|tool|stop> --state <state.json>   (hook JSON on stdin)
Harness comes from state["harness"]: claude (default), agy, opencode, or reasonix.
Fails open: a broken hook never blocks the agent.
"""
import fcntl
import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path

AGENT_PROMPT = os.environ.get(
    "AGENT_PROMPT_BIN",
    os.environ.get("SPAWN_PROMPT_BIN", str(Path(__file__).with_name("agent-prompt.sh")))
)
PANE_TOKENS = os.environ.get(
    "PANE_TOKENS_BIN",
    str(Path(__file__).resolve().parent.parent / "epic-lib" / "pane-tokens.sh")
)
HERDR = os.environ.get("HERDR_BIN", "herdr")
STATE_DIR = Path(
    os.environ.get("AGENT_STATE_DIR") or
    os.environ.get("SPAWN_STATE_DIR") or
    Path(os.environ.get("XDG_STATE_HOME") or Path.home() / ".local/state") / "agent-runtime"
)
SETTINGS_SUFFIX = ".settings.json"
BUDGET_OFF_ENV = "AGENT_BUDGET_OFF"
GRACE_TOOLS = 10
EXCERPT_CHARS = 400
SECONDS_PER_MINUTE = 60
NOTIFY_TIMEOUT_SECONDS = 20
EXIT_BLOCK = 2
USAGE_KEYS = ("input_tokens", "output_tokens", "cache_creation_input_tokens", "cache_read_input_tokens")
HARNESS_CLAUDE = "claude"
HARNESS_AGY = "agy"
HARNESS_OPENCODE = "opencode"
HARNESS_REASONIX = "reasonix"
AGY_MODEL_SOURCE = "MODEL"
AGY_RUN_COMMAND = "run_command"
AGY_TEXT_TYPE = "PLANNER_RESPONSE"
NOTIFY_MARKERS = ("agent-prompt.sh", "agent prompt", "agent-watchdog.py drain")
STAGE_RUNNING = "implement"
STAGE_BLOCKED = "blocked"
STAGE_DONE = "done"
INBOX_DONE = "done"
NOTE_SILENT_STOP = "stopped without notifying"
SHELL_TOOL = "Bash"
MONITOR_TOOL = "Monitor"
TASK_RUNNING = "running"
TASK_NOTIFICATION_RECORDS = ("user", "queue-operation")
TASK_STATUS_RE = re.compile(r"<tool-use-id>(\S+?)</tool-use-id>.*?<status>(\w+)</status>", re.S)


def read_records(path, offset):
    try:
        with open(path, "rb") as handle:
            handle.seek(offset)
            data = handle.read()
    except (OSError, TypeError):
        return [], offset
    end = data.rfind(b"\n")
    if end < 0:
        return [], offset
    records = []
    for raw in data[:end].splitlines():
        try:
            records.append(json.loads(raw))
        except ValueError:
            continue
    return records, offset + end + 1


def file_size(path):
    try:
        return os.path.getsize(path)
    except (OSError, TypeError):
        return 0


def harness(state):
    return (state.get("harness") or HARNESS_CLAUDE).lower()


def transcript_path(hook):
    return hook.get("transcript_path") or hook.get("transcriptPath")


def emit_noop(harness_name):
    if harness_name == HARNESS_AGY:
        print("{}")


def emit_block(harness_name, reason):
    if harness_name == HARNESS_AGY:
        print(json.dumps({"decision": "deny", "reason": reason}))
    elif harness_name == HARNESS_OPENCODE:
        print(json.dumps({"block": True, "reason": reason}))
    elif harness_name == HARNESS_REASONIX:
        print(reason, file=sys.stderr)
    else:
        print(json.dumps({"continue": False, "stopReason": reason}))


def absorb_opencode_tokens(state, hook):
    tokens = hook.get("tokens")
    if isinstance(tokens, (int, float)):
        state["tokens_used"] = max(state.get("tokens_used", 0), int(tokens))


def count_tokens(state, transcript):
    harness_name = harness(state)
    if not transcript:
        return
    records, state["transcript_offset"] = read_records(transcript, state.get("transcript_offset", 0))
    if harness_name == HARNESS_OPENCODE:
        return
    if harness_name == HARNESS_AGY:
        for record in records:
            if record.get("source") != AGY_MODEL_SOURCE:
                continue
            state["tokens_used"] = state.get("tokens_used", 0) + \
                (record.get("input_tokens") or 0) + (record.get("output_tokens") or 0)
        return
    for record in records:
        if record.get("type") != "assistant":
            continue
        message = record.get("message") or {}
        if message.get("id") and message.get("id") == state.get("last_message_id"):
            continue
        state["last_message_id"] = message.get("id")
        usage = message.get("usage") or {}
        state["tokens_used"] = state.get("tokens_used", 0) + sum(usage.get(key) or 0 for key in USAGE_KEYS)


def new_user_input(state, transcript):
    records, state["user_scan_offset"] = read_records(transcript, state.get("user_scan_offset", 0))
    return any(record.get("type") == "USER_INPUT" for record in records)


def human_tokens(count):
    return "%.1fM" % (count / 1e6)


def exceeded(state, now):
    budget_tokens = state.get("budget_tokens")
    used = state.get("tokens_used", 0) - state.get("token_base", 0)
    if budget_tokens and used >= budget_tokens:
        return "tokens", "%s of %s tokens" % (human_tokens(used), human_tokens(budget_tokens))
    budget_minutes = state.get("budget_minutes")
    elapsed = now - state.get("run_started", now)
    if budget_minutes and elapsed >= budget_minutes * SECONDS_PER_MINUTE:
        return "time", "%d of %d min" % (elapsed // SECONDS_PER_MINUTE, budget_minutes)
    return None


def notify(state, text):
    target = state.get("return_to")
    if not target:
        return
    try:
        subprocess.run([AGENT_PROMPT, target, text], stdout=subprocess.DEVNULL,
                       stderr=subprocess.DEVNULL, timeout=NOTIFY_TIMEOUT_SECONDS)
    except (OSError, subprocess.SubprocessError):
        pass


def live_panes():
    try:
        result = subprocess.run([HERDR, "agent", "list"], capture_output=True, text=True,
                                timeout=NOTIFY_TIMEOUT_SECONDS)
        agents = json.loads(result.stdout)["result"]["agents"]
    except (OSError, subprocess.SubprocessError, ValueError, KeyError, TypeError):
        return None
    return {agent.get("pane_id"): agent.get("name") for agent in agents if isinstance(agent, dict)}


def has_live_child(state):
    pane = os.environ.get("HERDR_PANE_ID") or state.get("pane")
    if not pane:
        return False
    panes = live_panes()
    if not panes:
        return False
    for path in STATE_DIR.glob("*.json"):
        if path.name.endswith(SETTINGS_SUFFIX):
            continue
        try:
            child = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            continue
        if not isinstance(child, dict) or child.get("return_to") != pane:
            continue
        if child.get("name") and panes.get(child.get("pane")) == child["name"]:
            return True
    return False


def stamp(state, stage, note=None):
    pane = os.environ.get("HERDR_PANE_ID") or state.get("pane")
    if not (pane and state.get("epic") and state.get("task")):
        return
    command = [PANE_TOKENS, "stamp", pane, "--epic", state["epic"], "--task", state["task"], "--stage", stage]
    if note:
        command += ["--note", note]
    try:
        subprocess.run(command, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                       timeout=NOTIFY_TIMEOUT_SECONDS)
    except (OSError, subprocess.SubprocessError):
        return
    state["hook_stage"] = stage


def terminate_if_over(state):
    if os.environ.get(BUDGET_OFF_ENV):
        return False
    over = exceeded(state, time.time())
    if not over:
        return False
    kind, detail = over
    reason = "%s stopped at %s budget limit (%s)." % (state.get("name", "the session"), kind, detail)
    if not state.get("limit_notified"):
        state["limit_notified"] = True
        notify(state, "%s Work remains in the worktree. Send a prompt to resume with a fresh budget window." % reason)
        stamp(state, STAGE_BLOCKED, "%s limit" % kind)
    print(json.dumps({"terminationBehavior": "terminate",
                      "injectSteps": [{"errorMessage": {"userMessage": reason}}]}))
    return True


def on_prompt(state, hook):
    transcript = transcript_path(hook)
    harness_name = harness(state)
    if harness_name == HARNESS_AGY and not new_user_input(state, transcript):
        count_tokens(state, transcript)
        state["session_id"] = hook.get("conversationId") or hook.get("session_id") or state.get("session_id")
        if terminate_if_over(state):
            return 0
        emit_noop(harness_name)
        return 0
    if harness_name == HARNESS_OPENCODE:
        absorb_opencode_tokens(state, hook)
    count_tokens(state, transcript)
    state["session_id"] = (hook.get("session_id") or hook.get("conversationId")
                           or hook.get("sessionId") or state.get("session_id"))
    state["run_started"] = time.time()
    state["turn_offset"] = file_size(transcript)
    state["inbox_offset"] = file_size(state.get("inbox"))
    state["notified_in_turn"] = False
    if state.get("warned_tools") is not None:
        state["token_base"] = state.get("tokens_used", 0)
        state["warned_tools"] = None
        state["limit_notified"] = False
    if state.get("hook_stage") == STAGE_BLOCKED:
        stamp(state, STAGE_RUNNING)
    emit_noop(harness_name)
    return 0


def on_tool(state, hook):
    harness_name = harness(state)
    if harness_name == HARNESS_REASONIX:
        tool_args = hook.get("toolArgs")
        tool_command = (tool_args.get("command") or "") if isinstance(tool_args, dict) else ""
        target = state.get("return_to") or ""
        if target and target in tool_command and any(marker in tool_command for marker in NOTIFY_MARKERS):
            state["notified_in_turn"] = True
    if os.environ.get(BUDGET_OFF_ENV):
        emit_noop(harness_name)
        return 0
    if harness_name == HARNESS_OPENCODE:
        absorb_opencode_tokens(state, hook)
    else:
        count_tokens(state, transcript_path(hook))
    over = exceeded(state, time.time())
    if not over:
        emit_noop(harness_name)
        return 0
    kind, detail = over
    if state.get("warned_tools") is None:
        state["warned_tools"] = 0
        warning = ("Budget limit for %s reached (%s). Do not start new work: commit changes, "
                   "reply Partial:true via brief channel, and end turn. %d tool calls remaining. "
                   "Bypass: %s=1." % (kind, detail, GRACE_TOOLS, BUDGET_OFF_ENV))
        print(warning, file=sys.stderr)
        if harness_name in (HARNESS_CLAUDE, HARNESS_REASONIX):
            return EXIT_BLOCK
        emit_block(harness_name, warning)
        return 0
    state["warned_tools"] += 1
    if state["warned_tools"] <= GRACE_TOOLS:
        emit_noop(harness_name)
        return 0
    reason = "%s stopped at %s budget limit (%s)." % (state.get("name", "the session"), kind, detail)
    if not state.get("limit_notified"):
        state["limit_notified"] = True
        notify(state, "%s Work remains in the worktree. Send a prompt to resume with a fresh budget window." % reason)
        stamp(state, STAGE_BLOCKED, "%s limit" % kind)
    emit_block(harness_name, reason)
    if harness_name == HARNESS_REASONIX:
        return EXIT_BLOCK
    return 0


def last_turn(transcript, offset):
    records, _ = read_records(transcript, offset)
    commands, text = [], ""
    for record in records:
        if record.get("type") != "assistant":
            continue
        for block in (record.get("message") or {}).get("content") or []:
            if not isinstance(block, dict):
                continue
            if block.get("type") == "tool_use" and block.get("name") == "Bash":
                commands.append((block.get("input") or {}).get("command") or "")
            elif block.get("type") == "text" and block.get("text"):
                text = block["text"]
    return commands, text


def last_turn_agy(transcript, offset):
    records, _ = read_records(transcript, offset)
    commands, text = [], ""
    for record in records:
        if record.get("source") != AGY_MODEL_SOURCE:
            continue
        for call in record.get("tool_calls") or []:
            if isinstance(call, dict) and call.get("name") == AGY_RUN_COMMAND:
                commands.append((call.get("args") or {}).get("CommandLine") or "")
        if record.get("type") == AGY_TEXT_TYPE and record.get("content"):
            text = record["content"]
    return commands, text


def launches_background(block):
    if block.get("type") != "tool_use":
        return False
    if block.get("name") == MONITOR_TOOL:
        return True
    return block.get("name") == SHELL_TOOL and bool((block.get("input") or {}).get("run_in_background"))


def notification_bodies(record):
    if record.get("type") not in TASK_NOTIFICATION_RECORDS:
        return []
    if record.get("type") == "queue-operation":
        return [record.get("content") or ""]
    content = (record.get("message") or {}).get("content")
    if isinstance(content, str):
        return [content]
    return [block.get("text") or "" for block in content or []
            if isinstance(block, dict) and block.get("type") == "text"]


def running_in_background(transcript):
    records, _ = read_records(transcript, 0)
    launched, finished = set(), set()
    for record in records:
        content = (record.get("message") or {}).get("content")
        for block in content if isinstance(content, list) else []:
            if not isinstance(block, dict):
                continue
            if launches_background(block):
                launched.add(block.get("id"))
            elif block.get("type") == "tool_result" and block.get("is_error"):
                finished.add(block.get("tool_use_id"))
        for body in notification_bodies(record):
            finished.update(tool_id for tool_id, status in TASK_STATUS_RE.findall(body) if status != TASK_RUNNING)
    return bool(launched - finished)


def inbox_entry(state):
    records, _ = read_records(state.get("inbox"), state.get("inbox_offset", 0))
    mine = [record for record in records
            if (state.get("task") and record.get("task") == state["task"])
            or record.get("worker") == state.get("name")]
    return mine[-1] if mine else None


def on_stop(state, hook):
    harness_name = harness(state)
    if state.get("stage") == STAGE_DONE:
        emit_noop(harness_name)
        return 0
    transcript = transcript_path(hook)
    if harness_name == HARNESS_AGY:
        commands, text = last_turn_agy(transcript, state.get("turn_offset", 0))
    elif harness_name == HARNESS_OPENCODE:
        commands, text = [], hook.get("text") or ""
    else:
        commands, text = last_turn(transcript, state.get("turn_offset", 0))
    text = hook.get("last_assistant_message") or text
    target = state.get("return_to") or ""
    if hook.get("notified") is None:
        notified = bool(state.get("notified_in_turn")) or any(
            target and target in command and any(marker in command for marker in NOTIFY_MARKERS)
            for command in commands)
    else:
        notified = bool(hook.get("notified"))
    if notified:
        entry = inbox_entry(state)
        if entry and entry.get("status") == INBOX_DONE:
            stamp(state, STAGE_DONE)
        elif entry:
            stamp(state, STAGE_BLOCKED, entry.get("ask") or entry.get("status"))
        emit_noop(harness_name)
        return 0
    if state.get("limit_notified") or has_live_child(state):
        emit_noop(harness_name)
        return 0
    if harness_name == HARNESS_AGY:
        if hook.get("fullyIdle") is False:
            emit_noop(harness_name)
            return 0
    elif harness_name == HARNESS_OPENCODE:
        if hook.get("background"):
            emit_noop(harness_name)
            return 0
    elif running_in_background(transcript):
        emit_noop(harness_name)
        return 0
    excerpt = " ".join(text.split())[:EXCERPT_CHARS] or "(no text)"
    notify(state, "%s ended turn without notifying return address. Stop counts as completion: verify delivery. Last message: «%s»" % (state.get("name", "the session"), excerpt))
    stamp(state, STAGE_BLOCKED, NOTE_SILENT_STOP)
    emit_noop(harness_name)
    return 0


HANDLERS = {"prompt": on_prompt, "tool": on_tool, "stop": on_stop}


def main(argv):
    if len(argv) != 3 or argv[0] not in HANDLERS or argv[1] != "--state":
        print(__doc__, file=sys.stderr)
        return 0
    try:
        hook = json.load(sys.stdin)
    except ValueError:
        hook = {}
    try:
        with open(argv[2], "r+", encoding="utf-8") as handle:
            fcntl.flock(handle, fcntl.LOCK_EX)
            state = json.load(handle)
            code = HANDLERS[argv[0]](state, hook)
            handle.seek(0)
            handle.truncate()
            json.dump(state, handle, ensure_ascii=False, indent=1)
            return code
    except (OSError, ValueError):
        return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
