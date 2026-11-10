#!/usr/bin/env bash
# CLI for the model and role map used by agent skills.
# Query:    get, model, effort, flags, show, table, budget, escalate, validate, review-model.
# Mutation: set, push, edit.
# Usage: agent-map.sh <command> [args]
set -uo pipefail

AGENT_LIB_SELF_DIR="${AGENT_LIB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
# shellcheck source=/dev/null
source "$AGENT_LIB_SELF_DIR/agent-lib.sh"

die() { echo "agent-map: $2" >&2; exit "$1"; }
MAP="$(agent_map_file)"

detect_harness() {
  local harness="${1:-${AGENT_PARENT_HARNESS:-}}"
  if [[ -z "$harness" ]]; then
    harness="$("${HERDR_BIN:-herdr}" pane current 2>/dev/null \
      | jq -r '.result.pane.agent // empty' 2>/dev/null || true)"
  fi
  if [[ -z "$harness" ]]; then
    if [[ -n "${CLAUDE_CODE_SESSION_ID:-}" ]]; then harness=claude
    elif [[ -n "${CODEX_THREAD_ID:-${CODEX_SESSION_ID:-}}" ]]; then harness=codex
    elif [[ -n "${OPENCODE:-}" ]]; then harness=opencode
    elif [[ -n "${AGY_SESSION_ID:-${AGY:-}}" ]]; then harness=agy
    elif [[ -n "${REASONIX_SESSION_ID:-${REASONIX:-}}" ]]; then harness=reasonix
    fi
  fi
  printf '%s' "$harness"
}

usage() {
  cat >&2 <<'EOF'
usage:
  agent-map.sh get <harness> <role> [index]     -> "family model effort"
  agent-map.sh model <harness> <role> [index]
  agent-map.sh effort <harness> <role> [index]
  agent-map.sh flags <harness> <role> [index]   -> harness argv
  agent-map.sh show [harness]                   -> assignments table
  agent-map.sh table [harness]                  -> markdown metrics table
  agent-map.sh escalate <harness> <role>        -> next tier (model+effort)
  agent-map.sh review-model [harness]           -> deterministic reviewer model
  agent-map.sh route <parent-harness> <role>    -> "harness model effort"
  agent-map.sh budget <role>                    -> target minutes
  agent-map.sh validate
  agent-map.sh set <harness> <role> <model> <effort>   (replaces default tier)
  agent-map.sh push <harness> <role> <model> <effort>  (appends escalation tier)
  agent-map.sh edit                             (opens models.json in $EDITOR)
roles: manager, architect, lead, worker, reviewer, investigator, reader
EOF
  exit 2
}

[[ $# -ge 1 ]] || usage
cmd="$1"; shift

case "$cmd" in
  get)
    [[ $# -ge 2 ]] || usage
    fam="$(agent_family "$1")" || die 5 "harness without family in map: $1"
    line="$(agent_tier "$1" "$2" "${3:-0}")" || die 4 "no assignment for $1/$2${3:+/$3}"
    printf '%s %s\n' "$fam" "$line" | tr '\t' ' '
    ;;
  model)  [[ $# -ge 2 ]] || usage; agent_model  "$1" "$2" "${3:-0}"; ;;
  effort) [[ $# -ge 2 ]] || usage; agent_effort "$1" "$2" "${3:-0}"; ;;
  flags)  [[ $# -ge 2 ]] || usage; agent_flags  "$1" "$2" "${3:-0}"; ;;
  budget) [[ $# -ge 1 ]] || usage; agent_budget "$1"; ;;
  route)
    [[ $# -ge 2 ]] || usage
    line="$(agent_route "$1" "$2")" || exit 4
    printf '%s\n' "$line" | tr '\t' ' '
    ;;
  escalate)
    [[ $# -ge 2 ]] || usage
    idx="$(agent_escalate_index "$1" "$2")" || die 5 "harness without family: $1"
    line="$(agent_tier "$1" "$2" "$idx")" || die 4 "no assignment for $1/$2"
    printf '%s\n' "$line" | tr '\t' ' '
    ;;
  review-model)
    harness="$(detect_harness "${1:-}")"
    [[ -n "$harness" ]] || die 5 "could not detect harness (pass <harness> or AGENT_PARENT_HARNESS)"
    fam="$(agent_family "$harness")" || die 5 "harness without family in map: $harness"
    model="$(agent_model "$harness" manager 2>/dev/null)" || true
    effort="$(agent_effort "$harness" manager 2>/dev/null)" || true
    [[ -n "$model" ]] || die 4 "no manager assignment for harness $harness"
    printf 'harness=%s family=%s model=%s effort=%s\n' "$harness" "$fam" "$model" "$effort"
    ;;
  show)
    filter='.'
    [[ $# -ge 1 ]] && filter=".assignments[\"$(agent_family "$1")\"] // {}"
    agent_jq -r "$filter"'
      | to_entries[]
      | .key as $role
      | .value | to_entries[]
      | "\($role)\t\(.value.model)\t\(.value.effort)\t\(.key)"' 2>/dev/null \
      | sort -u | awk -F'\t' 'BEGIN{printf "%-14s %-22s %-8s %s\n","ROLE","MODEL","EFFORT","TIER"} {printf "%-14s %-22s %-8s %s\n",$1,$2,$3,($4==0?"default":"escalated")}'
    ;;
  table)
    python3 - "$MAP" <<'PY'
import json, sys
data = json.load(open(sys.argv[1]))
cat = data.get("catalog", {})
print("| family | role | model | effort | II | $/task | $/II | TTFT | tier |")
print("|---|---|---|---|---|---|---|---|---|")
for fam, roles in data.get("assignments", {}).items():
    for role, tiers in roles.items():
        for i, t in enumerate(tiers):
            m, e = t.get("model"), t.get("effort")
            c = cat.get(f"{m}@{e}", {})
            tier = "default" if i == 0 else "escalated"
            print(f"| {fam} | {role} | {m} | {e} | {c.get('ii','—')} | {c.get('cost_task','—')} | {c.get('cost_efficiency','—')} | {c.get('ttft','—')} | {tier} |")
PY
    ;;
  validate)
    agent_has_map || die 5 "models.json missing or invalid: $MAP"
    problem=0
    for h in $(agent_jq -r '.harnesses | keys[]'); do
      raw="$(agent_jq -r --arg h "$h" '.harnesses[$h]')"
      [[ "$raw" == "parent" ]] && continue
      fam="$(agent_family "$h" 2>/dev/null)" || { echo "WARNING: harness $h does not resolve family" >&2; continue; }
      agent_jq -e --arg f "$fam" '.assignments[$f]' >/dev/null 2>&1 || { echo "ERROR: family $fam (harness $h) missing assignments" >&2; problem=1; }
    done
    for target in $(agent_jq -r '[.routes[]?[].harness] | unique | .[]'); do
      agent_family "$target" >/dev/null 2>&1 || { echo "ERROR: route to harness $target missing family" >&2; problem=1; }
    done
    for key in $(agent_jq -r '[.assignments[][].[] | "\(.model)@\(.effort)"] | .[]' | sort -u); do
      agent_jq -e --arg k "$key" '.catalog[$k]' >/dev/null 2>&1 || echo "WARNING: $key missing catalog metrics" >&2
    done
    [[ "$problem" -eq 0 ]] || die 5 "invalid map"
    echo "ok: $(agent_jq -r '[.assignments[][]] | length' 2>/dev/null) assignments"
    ;;
  set|push)
    [[ $# -ge 4 ]] || usage
    fam="$(agent_family "$1")" || die 5 "harness without family: $1"
    model="$3"; effort="$4"; role="$2"
    tmp="$(mktemp -t agent-map)" || die 5 "mktemp failed"
    python3 - "$MAP" "$cmd" "$fam" "$role" "$model" "$effort" > "$tmp" <<'PY' || die 5 "mutation failed"
import json, re, sys

map_path, command, family, role, model, effort = sys.argv[1:]
lines = open(map_path).read().split("\n")
TIER_PATTERN = re.compile(r'\{ "model": ("[^"]*",)(\s+)"effort": ("[^"]*")(\s*)\}')
ROLE_PATTERN = re.compile(r'^(\s*)"([^"]+)":(\s*)\[')

def fail(message):
    sys.exit(f"agent-map: {message}")

def field_widths(line):
    tier = TIER_PATTERN.search(line)
    if not tier:
        fail(f"line outside expected format: {line.strip()}")
    return len(tier.group(1) + tier.group(2)), len(tier.group(3) + tier.group(4))

def render_tier(widths):
    model_width, effort_width = widths
    model_field = json.dumps(model) + ","
    effort_field = json.dumps(effort)
    model_pad = " " * max(1, model_width - len(model_field))
    effort_pad = " " * max(1, effort_width - len(effort_field))
    return f'{{ "model": {model_field}{model_pad}"effort": {effort_field}{effort_pad}}}'

assignments_start = next((index for index, line in enumerate(lines) if line.strip() == '"assignments": {'), None)
if assignments_start is None:
    fail("assignments block missing")
family_start = next((index for index in range(assignments_start + 1, len(lines))
                     if lines[index].strip() == f'"{family}": {{'), None)
if family_start is None:
    fail(f"family missing in assignments: {family}")
family_indent = lines[family_start][:len(lines[family_start]) - len(lines[family_start].lstrip())]
family_end = next(index for index in range(family_start + 1, len(lines))
                  if lines[index].rstrip(",") == family_indent + "}")

role_starts = [index for index in range(family_start + 1, family_end) if ROLE_PATTERN.match(lines[index])]
if not role_starts:
    fail(f"family without roles: {family}")

def role_end(start):
    return next(index for index in range(start, family_end) if lines[index].rstrip(",").endswith("]"))

target = next((index for index in role_starts if ROLE_PATTERN.match(lines[index]).group(2) == role), None)

if target is None:
    reference = lines[role_starts[0]]
    indent = ROLE_PATTERN.match(reference).group(1)
    bracket_column = reference.index("[")
    key = f'{indent}"{role}":'
    new_line = key + " " * max(1, bracket_column - len(key)) + "[" + render_tier(field_widths(reference)) + "]"
    last_end = role_end(role_starts[-1])
    lines[last_end] += ","
    lines.insert(last_end + 1, new_line)
else:
    end = role_end(target)
    first_line = lines[target]
    trailing_comma = "," if lines[end].endswith(",") else ""
    widths = field_widths(first_line)
    if command == "set":
        prefix = first_line[:first_line.index("[") + 1]
        lines[target:end + 1] = [prefix + render_tier(widths) + "]" + trailing_comma]
    else:
        continuation_indent = " " * (first_line.index("[") + 1)
        lines[end] = lines[end].rstrip(",")[:-1] + ","
        lines.insert(end + 1, continuation_indent + render_tier(widths) + "]" + trailing_comma)

result = "\n".join(lines)
json.loads(result)
sys.stdout.write(result)
PY
    mv "$tmp" "$MAP" || die 5 "mv failed"
    echo "$cmd: $fam/$role = $model ($effort)"
    ;;
  edit)
    "${EDITOR:-vi}" "$MAP"
    ;;
  *) usage ;;
esac
