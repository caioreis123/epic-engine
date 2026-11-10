#!/usr/bin/env bash
# Delivers a prompt to a Herdr agent and guarantees submission.
#
# Usage: agent-prompt.sh <target> <text>     (target = agent name or pane_id)
# Env:   AGENT_PROMPT_BLOCKED_WAIT_MS — wait cap for blocked agent (default 10 min)
# Exit:  2 invalid usage · 7 herdr/agent prompt failed · 8 empty text
set -uo pipefail

HERDR_BIN="${HERDR_BIN:-herdr}"
DEFAULT_BLOCKED_WAIT_MS=600000
BLOCKED_WAIT_MS="${AGENT_PROMPT_BLOCKED_WAIT_MS:-$DEFAULT_BLOCKED_WAIT_MS}"
die() { echo "agent-prompt: $2" >&2; exit "$1"; }

target="${1:-}"; text="${2:-}"
[[ -n "$target" ]] || die 2 "usage: agent-prompt.sh <target> <text>"
[[ -n "$text" ]] || die 8 "empty text"

out="$("$HERDR_BIN" agent prompt "$target" "$text" 2>&1)"
status=$?
if [[ $status -ne 0 && "$out" == *agent_blocked* ]]; then
  echo "agent-prompt: $target is currently blocked in a dialog; waiting up to ${BLOCKED_WAIT_MS} ms" >&2
  if "$HERDR_BIN" agent wait "$target" --until idle --until working --until done \
      --timeout "$BLOCKED_WAIT_MS" >/dev/null 2>&1; then
    out="$("$HERDR_BIN" agent prompt "$target" "$text" 2>&1)"
    status=$?
  fi
fi

if [[ $status -ne 0 ]]; then
  printf '%s\n' "$out" >&2
  case "$out" in
    *agent_blocked*) die 7 "agent $target is blocked in a dialog; resolve before prompting" ;;
    *agent_prompt_stalled*) die 7 "prompt did not settle in $target; re-read pane and retry" ;;
    *) die 7 "agent prompt failed in $target" ;;
  esac
fi

info="$("$HERDR_BIN" agent list 2>/dev/null \
  | jq -r --arg t "$target" '.result.agents[]? | select(.name == $t or .pane_id == $t) | "\(.pane_id)\t\(.agent)"' \
  | head -1)"
pane="${info%%$'\t'*}"; kind="${info##*$'\t'}"
[[ "$info" == *$'\t'* ]] || { pane="$target"; kind=""; }

if [[ "$kind" == "agy" && -n "$pane" ]]; then
  sleep 1
  "$HERDR_BIN" pane send-keys "$pane" enter >/dev/null 2>&1 || true
fi

printf 'prompt delivered: target=%s kind=%s pane=%s\n' "$target" "${kind:-?}" "${pane:-?}"
