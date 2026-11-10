#!/usr/bin/env bash
# Reads the context percentage of the pane from Herdr metadata.
#
# Usage:
#   ctx-check.sh [<pane>]
# Output: "ctx=<n> limit=<n> above|ok|unknown"
# Exit:   1 only when exceeding the limit. Unknown does not block work.
set -uo pipefail

HERDR_BIN="${HERDR_BIN:-herdr}"
LIMIT="${EPIC_CTX_LIMIT:-60}"

pane="${1:-${HERDR_PANE_ID:-}}"
if [[ -z "$pane" ]]; then
  echo "ctx=? limit=$LIMIT unknown (no pane)"
  exit 0
fi

raw="$("$HERDR_BIN" pane get "$pane" 2>/dev/null)" || raw=""
pct="$(printf '%s' "$raw" | sed -n 's/.*"ctx":"[^ "]* \([0-9][0-9]*\)%".*/\1/p' | head -1)"

if [[ -z "$pct" ]]; then
  echo "ctx=? limit=$LIMIT unknown"
  exit 0
fi

if [[ "$pct" -ge "$LIMIT" ]]; then
  echo "ctx=$pct limit=$LIMIT above"
  exit 1
fi
echo "ctx=$pct limit=$LIMIT ok"
exit 0
