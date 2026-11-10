#!/usr/bin/env bash
# Dispatches an executor agent in ONE call: worktree + tab (--role worker) + brief delivery.
# With --delivery finding: dispatches an investigation tab (--role investigator) in the repo.
# With --delivery lead: dispatches a lead coordinator tab (--role lead) in the epic dossier.
# With handoff: transfers ownership of the lead task directly to the human user.
#
# Usage:
#   agent-executor.sh <repo> <slug> <name> <brief> [--delivery pr|finding|lead] [--role worker] [--base <ref>] [--workspace <id>] [--task task-<N>]
#   agent-executor.sh handoff <name>
# Exit: 2 invalid usage · 5 repo/branch/worktree/dossier/state error · 7 spawn/session error.
set -uo pipefail

HERDR_BIN="${HERDR_BIN:-herdr}"
REPO_ROOTS="${AGENT_EXECUTOR_REPO_ROOTS:-${REPOS_ROOT:-$HOME/workspace}}"
AGENT_LIB_DIR="${AGENT_LIB_DIR:-$(cd "$(dirname "$0")/../../../lib/agent-lib" 2>/dev/null && pwd || echo "$HOME/.epic-engine/lib/agent-lib")}"
AGENT_PROMPT_BIN="${AGENT_PROMPT_BIN:-$AGENT_LIB_DIR/agent-prompt.sh}"
REPO_REF="${REPO_REF_BIN:-$AGENT_LIB_DIR/../epic-lib/repo_ref.py}"
EPIC_CONTEXT="${EPIC_CONTEXT_BIN:-$AGENT_LIB_DIR/../epic-lib/epic-context.sh}"
PANE_TOKENS="${PANE_TOKENS_BIN:-$AGENT_LIB_DIR/../epic-lib/pane-tokens.sh}"
AGENT_STATE_DIR="${AGENT_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/agent-runtime}"

die() { echo "agent-executor: $2" >&2; exit "$1"; }

DELIVERY_PR="pr"
DELIVERY_FINDING="finding"
DELIVERY_LEAD="lead"
ROLE_BY_DELIVERY_PR="worker"
ROLE_BY_DELIVERY_FINDING="investigator"
ROLE_BY_DELIVERY_LEAD="lead"
HANDOFF_COMMAND="handoff"
HANDOFF_NOTICE="You are the owner of this task from now on. Communicate directly with the operator. Do not notify the orchestrator and do not write to the epic inbox.jsonl. Commit only your task files using git commit -- <files>. Never use git add -A. Add new PR and canonical artifact links to the epic links.md."

latest_state() {
  local name="$1" latest="" latest_stamp=-1 state_path state_stamp
  for state_path in "$AGENT_STATE_DIR/$name"-*.json; do
    [[ -f "$state_path" ]] || continue
    state_stamp="${state_path##*/}"
    state_stamp="${state_stamp#"$name"-}"
    state_stamp="${state_stamp%.json}"
    [[ "$state_stamp" =~ ^[0-9]+$ ]] || continue
    if (( state_stamp > latest_stamp )); then latest="$state_path"; latest_stamp="$state_stamp"; fi
  done
  printf '%s' "$latest"
}

drop_return_to() {
  local state_path="$1"
  jq 'del(.return_to)' "$state_path" > "$state_path.tmp" && mv "$state_path.tmp" "$state_path" \
    || die 7 "failed to remove return_to from $state_path"
}

handoff() {
  local name="${1:-}" state_path agents
  [[ -n "$name" ]] || die 2 "usage: agent-executor.sh $HANDOFF_COMMAND <name>"
  command -v jq >/dev/null 2>&1 || die 5 "jq not found"
  state_path="$(latest_state "$name")"
  [[ -n "$state_path" ]] || die 5 "no session state found for $name in $AGENT_STATE_DIR"
  agents="$("$HERDR_BIN" agent list 2>/dev/null)" || die 7 "herdr unavailable"
  drop_return_to "$state_path"
  "$AGENT_PROMPT_BIN" "$name" "$HANDOFF_NOTICE" >/dev/null || die 7 "handoff notification failed for $name"
  echo "handoff: name=$name state=$state_path"
}

[[ "${1:-}" == "$HANDOFF_COMMAND" ]] && { handoff "${2:-}"; exit 0; }

[[ $# -ge 4 ]] || die 2 "usage: agent-executor.sh <repo> <slug> <name> <brief> [--delivery pr|finding|lead] [--role worker] [--base <ref>] [--workspace <id>] [--task task-<N>]"
repo="$1"; slug="$2"; name="$3"; brief="$4"; shift 4
delivery="$DELIVERY_PR"; role=""; base=""; workspace=""; task=""
while [[ $# -gt 0 ]]; do case "$1" in
  --delivery) delivery="$2"; shift 2 ;;
  --role) role="$2"; shift 2 ;;
  --base) base="$2"; shift 2 ;;
  --workspace) workspace="$2"; shift 2 ;;
  --task) task="$2"; shift 2 ;;
  *) die 2 "unknown argument: $1" ;;
esac; done

case "$delivery" in
  "$DELIVERY_PR") role="${role:-$ROLE_BY_DELIVERY_PR}" ;;
  "$DELIVERY_FINDING") role="${role:-$ROLE_BY_DELIVERY_FINDING}" ;;
  "$DELIVERY_LEAD") role="${role:-$ROLE_BY_DELIVERY_LEAD}" ;;
  *) die 2 "unknown delivery: $delivery (use $DELIVERY_PR, $DELIVERY_FINDING or $DELIVERY_LEAD)" ;;
esac

command -v git >/dev/null 2>&1 || die 5 "git not found"
command -v jq >/dev/null 2>&1 || die 5 "jq not found"
[[ -f "$brief" ]] || die 5 "brief does not exist: $brief"
[[ "$brief" == /* ]] || die 5 "brief path must be absolute: $brief"

resolve_repo() {
  if [[ -d "$repo" ]]; then
    repo_path="$(cd "$repo" && pwd -P)"
  elif [[ -d "$REPO_ROOTS/$repo" ]]; then
    repo_path="$(cd "$REPO_ROOTS/$repo" && pwd -P)"
  else
    die 5 "repo '$repo' does not exist (checked '$repo' and '$REPO_ROOTS/$repo')"
  fi
  git -C "$repo_path" rev-parse --git-dir >/dev/null 2>&1 || die 5 "$repo_path is not a git repo"
}
[[ "$delivery" == "$DELIVERY_LEAD" ]] || resolve_repo

create_worktree() {
  local repo_name
  repo_name="$(basename "$repo_path")"
  wt="$(dirname "$repo_path")/$repo_name-epic-$slug"
  branch="epic/$slug"
  if [[ -d "$wt" ]]; then
    echo "worktree: reusing $wt"
    return
  fi
  if [[ -z "$base" ]]; then
    if [[ -f "$REPO_REF" ]]; then
      base="$(python3 "$REPO_REF" "$repo_path" | jq -r '.base_ref // empty')" || true
    fi
    base="${base:-origin/main}"
  fi
  if git -C "$repo_path" show-ref --verify --quiet "refs/heads/$branch"; then
    git -C "$repo_path" worktree add "$wt" "$branch" >/dev/null || die 5 "worktree add (existing local branch) failed"
  elif git -C "$repo_path" ls-remote --exit-code --heads origin "$branch" >/dev/null 2>&1; then
    git -C "$repo_path" worktree add "$wt" -b "$branch" "origin/$branch" >/dev/null || die 5 "worktree add (remote tracking branch) failed"
  else
    git -C "$repo_path" worktree add "$wt" -b "$branch" "$base" >/dev/null || die 5 "worktree add failed"
  fi
  echo "worktree: created $wt (branch $branch, base $base)"
}

inbox=""
if [[ "$delivery" == "$DELIVERY_LEAD" ]]; then
  if [[ -x "$EPIC_CONTEXT" ]]; then
    wt="$("$EPIC_CONTEXT" --path "$slug" 2>/dev/null)" || wt=""
  else
    wt=""
  fi
  [[ -n "$wt" && -d "$wt" ]] || die 5 "epic dossier for '$slug' not found"
  branch="-"; inbox="$wt/inbox-$name.jsonl"
elif [[ "$delivery" == "$DELIVERY_FINDING" ]]; then
  wt="$repo_path"; branch="-"
else
  create_worktree
fi

# Spawn tab in Herdr
tab_cmd=("$HERDR_BIN" tab new --cwd "$wt" --name "$name")
[[ -n "$workspace" ]] && tab_cmd+=(--workspace "$workspace")
tab_res="$("${tab_cmd[@]}" 2>&1)" || die 7 "herdr tab new failed: $tab_res"

# Extract pane ID
pane_id="$(echo "$tab_res" | jq -r '.result.tab.pane_id // .result.pane_id // empty' 2>/dev/null || true)"
if [[ -z "$pane_id" ]]; then
  pane_id="$("$HERDR_BIN" agent list 2>/dev/null | jq -r --arg n "$name" '.result.agents[]? | select(.name == $n) | .pane_id' | head -1)"
fi

if [[ -n "$pane_id" && -x "$PANE_TOKENS" ]]; then
  token_args=("$pane_id" --epic "$slug")
  [[ -n "$task" ]] && token_args+=(--task "$task")
  case "$delivery" in
    "$DELIVERY_PR") token_args+=(--stage implement) ;;
    "$DELIVERY_FINDING") token_args+=(--stage investigate) ;;
    "$DELIVERY_LEAD") token_args+=(--stage lead) ;;
  esac
  "$PANE_TOKENS" stamp "${token_args[@]}" >/dev/null 2>&1 || true
fi

# Deliver prompt
prompt_text="Read $brief in full and execute the instructions."
"$AGENT_PROMPT_BIN" "$name" "$prompt_text" >/dev/null 2>&1 || true

[[ -n "$inbox" ]] && echo "inbox: $inbox"
echo "executor: name=$name delivery=$delivery worktree=$wt branch=$branch brief=$brief role=$role pane=${pane_id:-unknown}"
