#!/usr/bin/env bash
# Resolves an epic hint and displays the dossier: identity and documents to read.
# Usage: epic-context.sh [--path] <hint>       hint = slug, card key, or name substring
#        epic-context.sh [--path]              no hint = session epic or cwd dossier
#        epic-context.sh --search <term>       searches term in *.md files across epics
#        epic-context.sh --check <hint>        validates file:line citations
# Output: EPIC=, CARD=, SLUG=, TITLE= and recommended reading lists. With --path, prints path only.
# Exit: 0 ok, 2 invalid usage, 3 ambiguous hint, 5 not found.
set -uo pipefail

EPIC_LIB_DIR="${EPIC_LIB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
# shellcheck source=/dev/null
source "$EPIC_LIB_DIR/epic-lib.sh"

STATUS_BIN="${EPIC_STATUS_BIN:-$EPIC_LIB_DIR/../../skills/epic/epic-status/epic-status.py}"

die() { echo "epic-context: $2" >&2; exit "$1"; }

if [[ "${1:-}" == "--search" ]]; then
  shift
  term="${1:-}"
  [[ -n "$term" ]] || die 2 "usage: epic-context.sh --search <term>"
  search_out="$(epic_search "$term")"
  case $? in
    0) printf '%s\n' "$search_out"; exit 0 ;;
    5) die 5 "no occurrences of '$term' in epic *.md files" ;;
    *) die 2 "usage: epic-context.sh --search <term>" ;;
  esac
fi

path_only=false
check_only=false
case "${1:-}" in
  --path)  path_only=true; shift ;;
  --check) check_only=true; shift ;;
esac

hint="${1:-}"
if [[ -z "$hint" ]]; then
  epic_dir="$(epic_session_epic)"
  [[ -n "$epic_dir" ]] || epic_dir="$(epic_cwd_epic)"
  [[ -n "$epic_dir" ]] || die 2 "usage: epic-context.sh [--path] <hint> (or run inside an epic dossier)"
else
  epic_out="$(epic_find "$hint")"
  case $? in
    0) epic_dir="$epic_out" ;;
    3)
      printf '%s\n' "$epic_out" >&2
      die 3 "ambiguous hint: multiple epics match '$hint'"
      ;;
    *)
      echo "available epics:" >&2
      epics_root="$(epic_root)"
      epic_dirs | while IFS= read -r listed_dir; do printf '%s\n' "${listed_dir#"$epics_root"/}"; done >&2
      die 5 "no epic matches '$hint'"
      ;;
  esac
fi

epic_mark_session "$epic_dir"

if $path_only; then
  printf '%s\n' "$epic_dir"
  exit 0
fi

if $check_only; then
  exec python3 "$EPIC_LIB_DIR/citations.py" "$epic_dir" "${EPIC_REPOS_ROOT:-$HOME/workspace}"
fi

dir_name="$(basename "$epic_dir")"
briefing="$epic_dir/00-BRIEFING.md"
key=""
title=""

if [[ -f "$briefing" ]]; then
  identity="$(EPIC_LIB_DIR="$EPIC_LIB_DIR" python3 - "$briefing" <<'PY'
import os
import pathlib
import sys

sys.path.insert(0, os.environ.get("EPIC_LIB_DIR", str(pathlib.Path.home() / ".epic-engine/lib/epic-lib")))
import frontmatter

fields = frontmatter.read(sys.argv[1])
print(fields.get("card", "") or "")
print(fields.get("title", "") or fields.get("titulo", "") or "")
PY
  )"
  key="$(printf '%s\n' "$identity" | sed -n 1p)"
  title="$(printf '%s\n' "$identity" | sed -n 2p)"
fi

short_name="$dir_name"

count_entries() {
  local target="$1"
  if [[ -d "$target" ]]; then
    find "$target" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' '
  else
    printf '0'
  fi
}

list_docs() {
  local sub="$1" doc
  [[ -d "$epic_dir/$sub" ]] || return 0
  find "$epic_dir/$sub" -maxdepth 1 -name '*.md' | sort | while read -r doc; do
    printf '  %s\n' "$sub/$(basename "$doc")"
  done
}

findings_count="$(count_entries "$epic_dir/findings")"
decisions_count="$(count_entries "$epic_dir/decisions")"

printf 'EPIC=%s\n' "$epic_dir"
printf 'CARD=%s\n' "$key"
printf 'SLUG=%s\n' "$short_name"
printf 'TITLE=%s\n' "$title"

printf '\nOPEN\n'
[[ -f "$briefing" ]] && printf '  %-22s %s\n' "00-BRIEFING.md" "the card: goals, verbatim requirements, source references"
[[ -f "$epic_dir/links.md" ]] && printf '  %-22s %s\n' "links.md" "Jira, PRs, specs, and monitoring dashboards"
[[ -f "$epic_dir/inbox.jsonl" ]] && printf '  %-22s %s\n' "inbox.jsonl" "worker callback event log"
list_docs decisions
list_docs specs
list_docs plans
list_docs validations

printf '\nSTATUS PANEL (frontmatters only — %s findings · %s decisions)\n' "$findings_count" "$decisions_count"
printf '  python3 %s "%s"\n' "$STATUS_BIN" "$epic_dir"

printf '\nON DEMAND\n'
printf '  %-22s %s\n' "briefs/ $(count_entries "$epic_dir/briefs")" "delegated investigation briefs"
printf '  %-22s %s\n' "sources/ $(count_entries "$epic_dir/sources")" "materialized attachments and assets"
printf '  %-22s %s\n' "exported-design/ $(count_entries "$epic_dir/exported-design")" "Figma specs and tokens"
printf '  %-22s %s\n' "reviews/ $(count_entries "$epic_dir/reviews")" "batch code review reports"
