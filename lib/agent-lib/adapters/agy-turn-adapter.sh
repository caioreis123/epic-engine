#!/usr/bin/env bash
# Bridge between Antigravity (agy) / Reasonix global hooks and turn-hook.py.
#
# Only acts when AGENT_TURN_STATE (or SPAWN_TURN_STATE) is stamped on the pane.
# Outside of active agent runs, emits an empty JSON object as expected by agy.
#
# Usage: agy-turn-adapter.sh <prompt|tool|stop>   (harness JSON on stdin)
set -u

STATE_FILE="${AGENT_TURN_STATE:-${SPAWN_TURN_STATE:-}}"
HARNESS_NAME="${AGENT_HARNESS:-${SPAWN_HARNESS:-}}"

if [[ -z "${STATE_FILE}" || ! -f "${STATE_FILE}" ]]; then
  [[ "${HARNESS_NAME}" == "reasonix" ]] || printf '{}\n'
  exit 0
fi

event="${1:-}"
if [[ -z "$event" ]]; then
  [[ "${HARNESS_NAME}" == "reasonix" ]] || printf '{}\n'
  exit 0
fi

hook="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/turn-hook.py"
out="$(python3 "$hook" "$event" --state "$STATE_FILE")"
code=$?
if [[ $code -eq 2 ]]; then
  exit 2
fi
if [[ "${HARNESS_NAME}" != "reasonix" ]]; then
  [[ -n "$out" ]] || out='{}'
  printf '%s\n' "$out"
fi
