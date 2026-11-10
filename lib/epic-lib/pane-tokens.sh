#!/usr/bin/env bash
# Stamps Herdr pane metadata indicating which epic, task, and stage the session belongs to.
#
# Usage:
#   pane-tokens.sh stamp [<pane>] --epic <slug> [--task task-<N>] [--stage <stage>] [--note <text>]
#   pane-tokens.sh clear [<pane>]
#     <pane>   default: $HERDR_PANE_ID
#     stages   implement | review | fix | blocked | done
# Exit: 0 always — a metadata stamp failure must not abort execution.
set -uo pipefail

HERDR_BIN="${HERDR_BIN:-herdr}"
TOKEN_SOURCE="epic"
TOKEN_NAMES=(epic task stage)
BOARD_SIGNAL="${EPIC_BOARD_SIGNAL:-}"

board_state() {
  case "$1" in
    implement|review|fix) echo running ;;
    blocked|done) echo "$1" ;;
  esac
}

signal_board() {
  local pane="$1" epic="$2" task="$3" stage="$4" note="$5" state
  [[ -n "$epic" && "$task" == task-* && -n "$BOARD_SIGNAL" && -f "$BOARD_SIGNAL" ]] || return 0
  state="$(board_state "$stage")"
  [[ -n "$state" ]] || return 0
  python3 "$BOARD_SIGNAL" "$epic" task "${task#task-}" "$state" --pane "$pane" --note "$note" >/dev/null 2>&1 || true
}

main() {
  local sub="${1:-}"; shift || true
  local pane="" epic="" task="" stage="" note=""

  [[ "${1:-}" == -* || $# -eq 0 ]] || { pane="$1"; shift; }
  while [[ $# -gt 0 ]]; do case "$1" in
    --epic)  epic="$2";  shift 2 ;;
    --task)  task="$2";  shift 2 ;;
    --stage) stage="$2"; shift 2 ;;
    --note)  note="$2";  shift 2 ;;
    --pane)  pane="$2";  shift 2 ;;
    *) shift ;;
  esac; done

  pane="${pane:-${HERDR_PANE_ID:-}}"
  [[ -n "$pane" ]] || { echo "pane-tokens: no pane (pass <pane> or run inside herdr)" >&2; exit 0; }

  case "$sub" in
    stamp)
      local args=("$pane" --source "$TOKEN_SOURCE")
      [[ -n "$epic"  ]] && args+=(--token "epic=$epic")
      [[ -n "$task"  ]] && args+=(--token "task=$task")
      [[ -n "$stage" ]] && args+=(--token "stage=$stage")
      [[ ${#args[@]} -gt 3 ]] || { echo "pane-tokens: nothing to stamp" >&2; exit 0; }
      "$HERDR_BIN" pane report-metadata "${args[@]}" >/dev/null 2>&1 || true
      signal_board "$pane" "$epic" "$task" "$stage" "$note"
      ;;
    clear)
      local args=("$pane" --source "$TOKEN_SOURCE") name
      for name in "${TOKEN_NAMES[@]}"; do args+=(--clear-token "$name"); done
      "$HERDR_BIN" pane report-metadata "${args[@]}" >/dev/null 2>&1 || true
      ;;
    *)
      echo "usage: pane-tokens.sh stamp|clear [<pane>] [--epic <slug>] [--task task-<N>] [--stage <stage>]" >&2
      ;;
  esac
  exit 0
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && main "$@"
