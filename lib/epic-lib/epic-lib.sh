# Shared library for epic skills. Use with: source epic-lib.sh
EPIC_LIB_SELF_DIR="${EPIC_LIB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"

epic_root() {
  if [[ -n "${EPIC_ROOT:-}" ]]; then
    printf '%s' "$EPIC_ROOT"
  elif [[ -d "$HOME/epics" ]]; then
    printf '%s' "$HOME/epics"
  else
    printf '%s' "$EPIC_LIB_SELF_DIR/../../examples"
  fi
}

epic_now() { printf '%s' "${EPIC_NOW:-$(date +%Y-%m-%d-%H%M)}"; }

epic_slugify() { python3 "$EPIC_LIB_SELF_DIR/slugify.py" "$@"; }

# epic_card <epic-dir> -> the card key in frontmatter, or empty string.
epic_card() {
  sed -n -E '/^card:[[:space:]]*/{s/^card:[[:space:]]*//;s/[[:space:]]*$//;p;q;}' \
    "$1/00-BRIEFING.md" 2>/dev/null
}

epic_has_marker() { [[ -f "$1/00-BRIEFING.md" || -f "$1/refinement.md" ]]; }

# epic_group_members <top-dir> -> epics within group; exit 1 if not a group dir.
epic_group_members() {
  local group_dir="$1" members
  epic_has_marker "$group_dir" && return 1
  members="$(find "$group_dir" -mindepth 2 -maxdepth 2 \( -name '00-BRIEFING.md' -o -name 'refinement.md' \) \
    -exec dirname {} \; | sort -u)"
  [[ -n "$members" ]] || return 1
  printf '%s\n' "$members"
}

# epic_dirs -> all epics: top-level epics and epics inside groups (<group>/<epic>).
epic_dirs() {
  local root top_dir
  root="$(epic_root)"
  [[ -d "$root" ]] || return 0
  find "$root" -mindepth 1 -maxdepth 1 -type d | sort | while IFS= read -r top_dir; do
    epic_group_members "$top_dir" || printf '%s\n' "$top_dir"
  done
}

# epic_find_by_card <hint> -> epic paths whose frontmatter `card:` matches hint.
epic_find_by_card() {
  local hint="$1" epic_dir card
  epic_dirs | while IFS= read -r epic_dir; do
    card="$(epic_card "$epic_dir")"
    if [[ -n "$card" ]] && printf '%s' "$card" | grep -qiF -- "$hint"; then
      printf '%s\n' "$epic_dir"
    fi
  done
  return 0
}

# epic_find <hint> -> epic path.
# Returns: 0 = found, 2 = empty hint, 3 = ambiguous, 5 = not found.
epic_find() {
  local hint="$1" root matches count epic_dir
  [[ -n "$hint" ]] || return 2
  root="$(epic_root)"
  [[ -d "$root" ]] || return 5

  matches="$(epic_dirs | while IFS= read -r epic_dir; do
      if printf '%s' "${epic_dir#"$root"/}" | grep -qiF -- "$hint"; then
        printf '%s\n' "$epic_dir"
      fi
    done)"
  [[ -n "$matches" ]] || matches="$(epic_find_by_card "$hint")"
  [[ -n "$matches" ]] || return 5

  count="$(printf '%s\n' "$matches" | wc -l | tr -d ' ')"
  printf '%s\n' "$matches"
  [[ "$count" -eq 1 ]] && return 0
  return 3
}

# epic_search <term> -> occurrences of term in epic *.md files, grouped by epic.
epic_search() {
  local term="$1" root out
  [[ -n "$term" ]] || return 2
  root="$(epic_root)"
  [[ -d "$root" ]] || return 5

  out="$(grep -rIFn --include='*.md' -i -- "$term" "$root" 2>/dev/null \
         | LC_ALL=C sort -t: -k1,1 -k2,2n \
         | awk -v plen="${#root}" '
             {
               colon = index($0, ":")
               path  = substr($0, plen + 2, colon - plen - 2)
               rest = substr($0, colon + 1)
               colon = index(rest, ":")
               lineno = substr(rest, 1, colon - 1)
               text = substr(rest, colon + 1)
               slash = index(path, "/")
               epic = slash ? substr(path, 1, slash - 1) : path
               rel  = slash ? substr(path, slash + 1) : path
               if (epic != last) { if (shown) print ""; print epic; last = epic; shown = 1 }
               gsub(/^[ \t]+/, "", text); gsub(/[ \t]+$/, "", text)
               if (length(text) > 160) text = substr(text, 1, 159) "..."
               printf "  %s:%s  %s\n", rel, lineno, text
             }')"
  [[ -n "$out" ]] || return 5
  printf '%s\n' "$out"
  return 0
}

epic_session_dir() { printf '%s' "${EPIC_SESSION_DIR:-$HOME/.epic-engine/lib/epic-lib/session-epic}"; }

# epic_mark_session <epic-path> -> records epic path for active session.
epic_mark_session() {
  local epic_dir="$1" sid="${CLAUDE_CODE_SESSION_ID:-${HERDR_PANE_ID:-}}" dir
  [[ -n "$epic_dir" && -n "$sid" ]] || return 0
  dir="$(epic_session_dir)"
  mkdir -p "$dir" 2>/dev/null || return 0
  printf '%s\n' "$epic_dir" > "$dir/$sid" 2>/dev/null || true
  return 0
}

epic_session_epic() {
  local sid="${CLAUDE_CODE_SESSION_ID:-${HERDR_PANE_ID:-}}" marker epic_dir
  [[ -n "$sid" ]] || return 0
  marker="$(epic_session_dir)/$sid"
  [[ -f "$marker" ]] || return 0
  epic_dir="$(head -1 "$marker" 2>/dev/null)"
  [[ -n "$epic_dir" && -d "$epic_dir" ]] && printf '%s' "$epic_dir"
  return 0
}

epic_cwd_epic() {
  local physical_root here relative top_dir member_dir
  physical_root="$(cd "$(epic_root)" 2>/dev/null && pwd -P)" || return 0
  here="$(pwd -P)"
  [[ "$here" == "$physical_root"/* ]] || return 0
  relative="${here#"$physical_root"/}"
  top_dir="$(epic_root)/${relative%%/*}"
  if ! epic_group_members "$top_dir" >/dev/null; then
    printf '%s' "$top_dir"
    return 0
  fi
  [[ "$relative" == */* ]] || return 0
  relative="${relative#*/}"
  member_dir="$top_dir/${relative%%/*}"
  epic_has_marker "$member_dir" && printf '%s' "$member_dir"
  return 0
}
