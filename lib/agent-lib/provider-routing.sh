#!/usr/bin/env bash

ROUTE_KIND=""
ROUTE_PROVIDER=""
ROUTE_MODEL=""
ROUTE_THINKING=""
ROUTE_FLAGS=""

AGENT_LIB_DIR="${AGENT_LIB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
if [[ -f "$AGENT_LIB_DIR/agent-lib.sh" ]]; then
  # shellcheck source=/dev/null
  . "$AGENT_LIB_DIR/agent-lib.sh"
fi

# resolve_role_route <harness> [role] -> ROUTE_MODEL, ROUTE_THINKING, ROUTE_PROVIDER, ROUTE_FLAGS.
# Returns 3 when no map or entry is found (caller falls back to harness defaults).
resolve_role_route() {
  local harness="$1" role="${2:-${AGENT_ROLE:-worker}}" flags
  declare -F agent_flags >/dev/null 2>&1 || return 3
  agent_has_map 2>/dev/null || return 3
  flags="$(agent_flags "$harness" "$role" 0 2>/dev/null)" || return 3
  [[ -n "$flags" ]] || return 3
  ROUTE_FLAGS="$flags"
  ROUTE_PROVIDER="$(agent_family "$harness" 2>/dev/null || printf '%s' "$harness")"
  if [[ "$harness" == "pi" ]]; then
    case "$ROUTE_PROVIDER" in
      openai) ROUTE_PROVIDER="openai-codex" ;;
    esac
  fi
  ROUTE_MODEL="$(agent_model "$harness" "$role" 0 2>/dev/null)"
  ROUTE_THINKING="$(agent_effort "$harness" "$role" 0 2>/dev/null)"
  return 0
}

# resolve_child_route <parent-harness> <role> -> ROUTE_KIND, ROUTE_FLAGS, ROUTE_MODEL, ROUTE_THINKING, ROUTE_PROVIDER.
resolve_child_route() {
  local parent="$1" role="$2" route
  declare -F agent_route >/dev/null 2>&1 || return 3
  route="$(agent_route "$parent" "$role" 2>/dev/null)" || return 3
  IFS=$'\t' read -r ROUTE_KIND ROUTE_MODEL ROUTE_THINKING <<<"$route"
  ROUTE_FLAGS="$(agent_route_flags "$parent" "$role" 2>/dev/null)" || return 3
  ROUTE_PROVIDER="$(agent_family "$ROUTE_KIND" 2>/dev/null || printf '%s' "$ROUTE_KIND")"
  return 0
}

resolve_parent_route() {
  local parent_provider="${AGENT_PARENT_PROVIDER:-${PI_PROVIDER:-}}"

  if [[ -z "$parent_provider" ]]; then
    if [[ -n "${CLAUDE_CODE_SESSION_ID:-}" ]]; then
      parent_provider="anthropic"
    elif [[ -n "${CODEX_THREAD_ID:-${CODEX_SESSION_ID:-}}" ]]; then
      parent_provider="openai-codex"
    elif [[ -n "${REASONIX_SESSION_ID:-${REASONIX_HOME:-}}" ]]; then
      parent_provider="deepseek"
    fi
  fi

  ROUTE_KIND="pi"
  ROUTE_THINKING="high"
  case "$parent_provider" in
    anthropic|claude)
      ROUTE_PROVIDER="anthropic"
      ROUTE_MODEL="opus"
      ;;
    openai-codex|codex|openai)
      ROUTE_PROVIDER="openai-codex"
      ROUTE_MODEL="gpt-5.6-luna"
      ;;
    deepseek|deep-seek|reasonix)
      ROUTE_PROVIDER="deepseek"
      ROUTE_MODEL="deepseek-v4-flash"
      ;;
    *)
      echo "provider-routing: unable to identify parent provider. Use AGENT_PARENT_PROVIDER=claude|codex|deepseek." >&2
      return 2
      ;;
  esac
}

herdr_pane_agent_kind() {
  local bin="${HERDR_BIN:-herdr}"
  "$bin" pane current 2>/dev/null | jq -r '.result.pane.agent // empty' 2>/dev/null || true
}

resolve_parent_harness() {
  local harness="${AGENT_PARENT_HARNESS:-}"
  [[ -n "$harness" ]] || harness="$(herdr_pane_agent_kind)"
  if [[ -z "$harness" ]]; then
    if [[ -n "${CLAUDE_CODE_SESSION_ID:-}" ]]; then
      harness="claude"
    elif [[ -n "${CODEX_THREAD_ID:-${CODEX_SESSION_ID:-}}" ]]; then
      harness="codex"
    elif [[ -n "${OPENCODE:-}" ]]; then
      harness="opencode"
    elif [[ -n "${AGY_SESSION_ID:-${AGY:-}}" ]]; then
      harness="agy"
    elif [[ -n "${REASONIX_SESSION_ID:-${REASONIX:-}}" ]]; then
      harness="reasonix"
    fi
  fi

  ROUTE_KIND=""
  case "$harness" in
    claude|codex|opencode|agy|muse|reasonix) ROUTE_KIND="$harness" ;;
    *)
      echo "provider-routing: unable to identify parent harness (pane reported '${harness:-empty}'; supported: claude, codex, opencode, agy, muse, reasonix). Use AGENT_PARENT_HARNESS=<harness>." >&2
      return 2
      ;;
  esac
}
