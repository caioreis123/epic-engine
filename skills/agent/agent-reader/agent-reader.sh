#!/usr/bin/env bash
# Dispatches a low-cost, read-only reader agent in a split Herdr pane.
#
# Usage:
#   agent-reader.sh [--dry-run] --scope <directory> <bounded-question>
# Exit: 0 ok · 2 invalid usage · 7 herdr error.
set -uo pipefail

HERDR_BIN="${HERDR_BIN:-herdr}"
AGENT_LIB_DIR="${AGENT_LIB_DIR:-$(cd "$(dirname "$0")/../../../lib/agent-lib" 2>/dev/null && pwd || echo "$HOME/.epic-engine/lib/agent-lib")}"
AGENT_PROMPT_BIN="${AGENT_PROMPT_BIN:-$AGENT_LIB_DIR/agent-prompt.sh}"
AGENT_MAP_BIN="${AGENT_MAP_BIN:-$AGENT_LIB_DIR/agent-map.sh}"
RUNDIR_BASE="${AGENT_READER_RUNDIR_BASE:-${TMPDIR:-/tmp}/agent-reader}"

EXIT_USAGE=2
EXIT_HERDR=7
READER_ROLE="reader"
DRY_RUN=false
SCOPE=""
QUESTION=""

die() { echo "agent-reader: $2" >&2; exit "$1"; }

usage() {
  cat >&2 <<'EOF'
usage: agent-reader.sh [--dry-run] --scope <directory> <question>
EOF
  exit "$EXIT_USAGE"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    --scope) [[ $# -ge 2 ]] || usage; SCOPE="$2"; shift 2 ;;
    -h|--help) usage ;;
    --) shift; QUESTION="${1:-}"; shift || true ;;
    -*) usage ;;
    *) [[ -z "$QUESTION" ]] || usage; QUESTION="$1"; shift ;;
  esac
done

[[ -n "$SCOPE" && -n "$QUESTION" ]] || usage
[[ -d "$SCOPE" ]] || die "$EXIT_USAGE" "scope is not an existing directory: $SCOPE"
SCOPE="$(cd "$SCOPE" && pwd -P)"
command -v "$HERDR_BIN" >/dev/null 2>&1 || die "$EXIT_HERDR" "herdr unavailable ($HERDR_BIN)"
command -v jq >/dev/null 2>&1 || die "$EXIT_USAGE" "jq is required"

PARENT="${AGENT_READER_PARENT_PANE:-${HERDR_PANE_ID:-}}"
[[ -n "$PARENT" ]] || die "$EXIT_HERDR" "HERDR_PANE_ID is unset; no return address available"

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
RUNDIR="$RUNDIR_BASE/$TIMESTAMP-$$"
REPORT="$RUNDIR/report.md"
PROMPT_FILE="$RUNDIR/prompt.md"
LABEL="rea-lookup-$TIMESTAMP"

reader_prompt() {
  cat <<EOF
Answer strictly this question:

$QUESTION

Initial scope: $SCOPE

Investigate scope with read-only tools. Do not modify files.
Do not use external network. Do not invoke external skills.
Write strictly the report to $REPORT.

The report must contain:
1. Direct answer.
2. Evidence in path:line format.
3. Remaining uncertainties.

After writing the report, notify the return address pane:

$AGENT_PROMPT_BIN $PARENT "cheap-reader-ready: report in $REPORT; pane $PANE_PLACEHOLDER"

Do not close this pane. Await caller verification.
EOF
}

ABOVE=false
if $DRY_RUN; then
  PANE_PLACEHOLDER="<pane>"
  echo "--- prompt ($PROMPT_FILE) ---"
  reader_prompt
  echo "--- dry-run completed ---"
else
  mkdir -p "$RUNDIR"
  split_json="$("$HERDR_BIN" pane split "$PARENT" --direction down --cwd "$SCOPE" --no-focus 2>&1)"
  PANE="$(printf '%s' "$split_json" | jq -r '.result.pane.pane_id // .result.pane_id // empty' 2>/dev/null)"
  [[ -n "$PANE" ]] || die "$EXIT_HERDR" "herdr pane split did not return pane_id: $split_json"

  if "$HERDR_BIN" pane swap "$PANE" "$PARENT" >/dev/null 2>&1; then
    ABOVE=true
  fi

  PANE_PLACEHOLDER="$PANE"
  reader_prompt > "$PROMPT_FILE"

  "$AGENT_PROMPT_BIN" "$PANE" "Read $PROMPT_FILE and execute instructions." >/dev/null || die "$EXIT_HERDR" "failed to prompt reader agent"
fi

echo "PANE=${PANE:-<dry>}"
echo "PARENT=$PARENT"
echo "ABOVE=$ABOVE"
echo "REPORT=$REPORT"
echo "PROMPT=$PROMPT_FILE"
echo "SCOPE=$SCOPE"
echo "LABEL=$LABEL"
