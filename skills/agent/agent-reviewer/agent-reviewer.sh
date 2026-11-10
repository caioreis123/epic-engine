#!/usr/bin/env bash
# Opens a pane ABOVE the caller in the same Herdr tab, runs an author-blind code review
# on the pull request, and notifies the caller pane upon completion.
#
# Usage:
#   agent-reviewer.sh [--dry-run] <pr-url-or-number>
# Output: PANE=, PARENT=, ABOVE=true|false, REPORT=, URL=
# Exit: 0 ok · 2 invalid usage · 5 repository error · 7 herdr error.
set -uo pipefail

HERDR_BIN="${HERDR_BIN:-herdr}"
AGENT_LIB_DIR="${AGENT_LIB_DIR:-$(cd "$(dirname "$0")/../../../lib/agent-lib" 2>/dev/null && pwd || echo "$HOME/.epic-engine/lib/agent-lib")}"
AGENT_PROMPT_BIN="${AGENT_PROMPT_BIN:-$AGENT_LIB_DIR/agent-prompt.sh}"
AGENT_MAP_BIN="${AGENT_MAP_BIN:-$AGENT_LIB_DIR/agent-map.sh}"
RUNDIR_BASE="${AGENT_REVIEW_RUNDIR_BASE:-${TMPDIR:-/tmp}/agent-review}"
GH_BIN="${GH_BIN:-gh}"

die() { echo "agent-reviewer: $2" >&2; exit "$1"; }

DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && { DRY_RUN=true; shift; }

PR_ARG="${1:-}"
[[ -n "$PR_ARG" ]] || die 2 "usage: agent-reviewer.sh [--dry-run] <pr-url-or-number>"

# Resolve PR metadata
if [[ "$PR_ARG" =~ github\.com/([^/]+)/([^/]+)/pull/([0-9]+) ]]; then
  PR_URL="$PR_ARG"
  PR_NUM="${BASH_REMATCH[3]}"
  REPO_OWNER="${BASH_REMATCH[1]}"
  REPO_NAME="${BASH_REMATCH[2]}"
else
  PR_NUM="${PR_ARG#"#"}"
  PR_URL="$("$GH_BIN" pr view "$PR_NUM" --json url --jq .url 2>/dev/null)" || die 5 "unable to resolve PR $PR_ARG"
fi

CALLER_PANE="${HERDR_PANE_ID:-}"
[[ -n "$CALLER_PANE" ]] || die 7 "not running inside a Herdr pane (HERDR_PANE_ID is unset)"

RUN_ID="$(date +%Y%m%d-%H%M%S)-pr$PR_NUM"
RUN_DIR="$RUNDIR_BASE/$RUN_ID"
mkdir -p "$RUN_DIR"
REPORT_FILE="$RUN_DIR/report.md"

if $DRY_RUN; then
  echo "dry-run: reviewer for PR $PR_URL would be created above pane $CALLER_PANE"
  echo "report: $REPORT_FILE"
  exit 0
fi

# 1. Split pane downwards, then swap upwards to place reviewer above caller
SPLIT_OUT="$("$HERDR_BIN" pane split down 2>&1)" || die 7 "herdr pane split failed: $SPLIT_OUT"
REVIEWER_PANE="$(echo "$SPLIT_OUT" | jq -r '.result.pane_id // .result.pane.pane_id // empty' 2>/dev/null || true)"
[[ -n "$REVIEWER_PANE" ]] || die 7 "unable to parse new pane ID from split output"

SWAP_OK=true
"$HERDR_BIN" pane swap "$REVIEWER_PANE" "$CALLER_PANE" >/dev/null 2>&1 || SWAP_OK=false

# 2. Select reviewer model tier
REVIEWER_FLAGS=""
if [[ -x "$AGENT_MAP_BIN" ]]; then
  REVIEWER_FLAGS="$("$AGENT_MAP_BIN" flags claude reviewer 2>/dev/null || echo "")"
fi

# 3. Deliver review prompt
REVIEW_PROMPT="Review pull request $PR_URL. Fetch diff, run awk annotator, audit correctness and quality, write findings to $REPORT_FILE, and notify pane $CALLER_PANE via agent-prompt.sh."
"$AGENT_PROMPT_BIN" "$REVIEWER_PANE" "$REVIEW_PROMPT" >/dev/null 2>&1 || true

echo "PANE=$REVIEWER_PANE"
echo "PARENT=$CALLER_PANE"
echo "ABOVE=$SWAP_OK"
echo "REPORT=$REPORT_FILE"
echo "URL=$PR_URL"
