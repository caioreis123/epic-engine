#!/usr/bin/env bash
# Shared library for agent skills. Use with: source agent-lib.sh
# Source of truth: models.json (harness x role map -> model/effort + metrics).
AGENT_LIB_SELF_DIR="${AGENT_LIB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"

agent_map_file() { printf '%s' "${AGENT_MAP_FILE:-$AGENT_LIB_SELF_DIR/models.json}"; }

agent_jq() { jq "$@" "$(agent_map_file)" 2>/dev/null; }

agent_has_map() {
  [[ -f "$(agent_map_file)" ]] && jq -e . "$(agent_map_file)" >/dev/null 2>&1
}

agent_family() {
  local harness="$1" fam
  fam="$(agent_jq -r --arg h "$harness" '.harnesses[$h] // empty')"
  [[ -n "$fam" ]] || return 2
  if [[ "$fam" == "parent" ]]; then
    case "${AGENT_PARENT_FAMILY:-${AGENT_PARENT_PROVIDER:-}}" in
      anthropic|claude)            fam=anthropic ;;
      openai-codex|codex|openai)   fam=openai ;;
      google|gemini|opencode|agy)  fam=google ;;
      deepseek|deep-seek|reasonix) fam=deepseek ;;
      *) return 3 ;;
    esac
  fi
  printf '%s' "$fam"
}

agent_tier() {
  local harness="$1" role="$2" index="${3:-0}" fam out
  fam="$(agent_family "$harness")" || return $?
  out="$(agent_jq -r --arg f "$fam" --arg r "$role" --argjson i "$index" \
    '(.assignments[$f][$r][$i] // empty) | "\(.model)\t\(.effort)"')"
  [[ -n "$out" ]] || return 4
  printf '%s\n' "$out"
}

agent_model()  { agent_tier "$1" "$2" "${3:-0}" | cut -f1; }
agent_effort() { agent_tier "$1" "$2" "${3:-0}" | cut -f2; }

agent_tier_count() {
  local harness="$1" role="$2" fam
  fam="$(agent_family "$harness")" || return $?
  agent_jq -r --arg f "$fam" --arg r "$role" '(.assignments[$f][$r] // []) | length'
}

agent_escalate_index() {
  local n; n="$(agent_tier_count "$1" "$2")" || return $?
  if [[ "${n:-0}" -ge 2 ]]; then printf '1'; else printf '0'; fi
}

agent_flags() {
  local harness="$1" role="${2:-worker}" index="${3:-0}" fam model effort
  fam="$(agent_family "$harness")"  || return $?
  model="$(agent_model "$harness" "$role" "$index")" || return $?
  effort="$(agent_effort "$harness" "$role" "$index")"
  agent_format_flags "$harness" "$fam" "$model" "$effort"
}

agent_format_flags() {
  local harness="$1" fam="$2" model="$3" effort="$4" provider
  case "$harness" in
    pi)
      case "$fam" in
        anthropic) provider=anthropic ;;
        openai)    provider=openai-codex ;;
        google)    provider=google ;;
        deepseek)  provider=deepseek ;;
        *) return 2 ;;
      esac
      printf '%s\n' "--provider $provider --model $model --thinking $effort" ;;
    codex)    printf '%s\n' "--model $model -c model_reasoning_effort=$effort" ;;
    claude)   printf '%s\n' "--model $model --effort $effort" ;;
    agy)      printf '%s\n' "--model $model --effort $effort" ;;
    reasonix) printf '%s\n' "--model $model --effort $effort" ;;
    deepseek) export AGENT_EFFORT="$effort"; printf '%s\n' "--model $model" ;;
    opencode)
      case "$fam" in
        anthropic) provider=anthropic ;;
        openai)    provider=openai ;;
        google)    provider=google ;;
        deepseek)  provider=deepseek ;;
        *) return 2 ;;
      esac
      export AGENT_EFFORT="$effort"
      printf '%s\n' "--model $provider/$model" ;;
    *) return 2 ;;
  esac
}

agent_route() {
  local out
  out="$(agent_jq -r --arg p "$1" --arg r "$2" \
    '(.routes[$p][$r] // empty) | "\(.harness)\t\(.model)\t\(.effort)"')"
  [[ -n "$out" ]] || return 4
  printf '%s\n' "$out"
}

agent_route_flags() {
  local route harness model effort fam
  route="$(agent_route "$1" "$2")" || return $?
  IFS=$'\t' read -r harness model effort <<<"$route"
  fam="$(agent_family "$harness")" || return $?
  agent_format_flags "$harness" "$fam" "$model" "$effort"
}

agent_budget() { agent_jq -r --arg r "$1" '.defaults.budgets_minutes[$r] // 20'; }
agent_budget_tokens() { agent_jq -r --arg r "$1" '.defaults.budgets_tokens[$r] // empty'; }
agent_default_role() { agent_jq -r '.defaults.role // "worker"'; }
agent_context_alert_pct() { agent_jq -r '.defaults.context_alert_pct // 60'; }
