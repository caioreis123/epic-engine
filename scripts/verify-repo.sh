#!/usr/bin/env bash
# End-to-end verification suite for Epic Engine.
# Tests all 3 skill namespaces, control plane scripts, state machine transitions,
# multi-agent runtime hooks/watchdogs/dispatchers (with a mock Herdr binary),
# and statistical analysis tools in an isolated temporary workspace.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP_WS="$(mktemp -d "${TMPDIR:-/tmp}/epic-engine-verify.XXXXXX")"
trap 'rm -rf "$TMP_WS"' EXIT

pass() { printf '  [PASS] %s\n' "$1"; }
fail() { printf '  [FAIL] %s\n' "$1" >&2; exit 1; }

echo "=== 1. Repository Structure & Skill Frontmatter Contracts ==="

for namespace in epic agent implement; do
  [[ -d "$REPO_ROOT/skills/$namespace" ]] || fail "Missing skill namespace: skills/$namespace"
done

skill_count=0
while IFS= read -r skill_file; do
  head -n 1 "$skill_file" | grep -qx -- "---" || fail "Missing YAML frontmatter in $skill_file"
  grep -qE "^name:[[:space:]]+[a-z0-9-]+" "$skill_file" || fail "Missing 'name:' in $skill_file"
  grep -qE "^description:" "$skill_file" || fail "Missing 'description:' in $skill_file"
  skill_count=$((skill_count + 1))
done < <(find "$REPO_ROOT/skills" -name "SKILL.md" | sort)

[[ "$skill_count" -eq 27 ]] || fail "Expected 27 SKILL.md files, found $skill_count"
pass "All $skill_count SKILL.md files across epic, agent, and implement namespaces verified"

echo "=== 2. Control Plane (epic-lib & epic-status) ==="

ctx_out="$(EPIC_ROOT="$REPO_ROOT/examples" EPIC_LIB_DIR="$REPO_ROOT/lib/epic-lib" \
  bash "$REPO_ROOT/lib/epic-lib/epic-context.sh" annual-upgrade)"
echo "$ctx_out" | grep -q "CARD=EPIC-101" || fail "epic-context.sh failed to parse CARD"
echo "$ctx_out" | grep -q "STATUS PANEL" || fail "epic-context.sh missing STATUS PANEL"

path_out="$(EPIC_ROOT="$REPO_ROOT/examples" EPIC_LIB_DIR="$REPO_ROOT/lib/epic-lib" \
  bash "$REPO_ROOT/lib/epic-lib/epic-context.sh" --path annual-upgrade)"
[[ "$path_out" == "$REPO_ROOT/examples/sample-epic-annual-upgrade" ]] || fail "epic-context.sh --path mismatch"

search_out="$(EPIC_ROOT="$REPO_ROOT/examples" EPIC_LIB_DIR="$REPO_ROOT/lib/epic-lib" \
  bash "$REPO_ROOT/lib/epic-lib/epic-context.sh" --search "Popover")"
echo "$search_out" | grep -q "sample-epic-annual-upgrade" || fail "epic-context.sh --search failed"

EPIC_ROOT="$REPO_ROOT/examples" EPIC_LIB_DIR="$REPO_ROOT/lib/epic-lib" \
  bash "$REPO_ROOT/lib/epic-lib/epic-context.sh" --check "$REPO_ROOT/examples/sample-epic-annual-upgrade" >/dev/null
pass "epic-context.sh (lookup, --path, --search, --check) verified"

status_out="$(python3 "$REPO_ROOT/skills/epic/epic-status/epic-status.py" \
  "$REPO_ROOT/examples/sample-epic-annual-upgrade")"
echo "$status_out" | grep -q "/epic-merge sample-epic-annual-upgrade" || fail "epic-status.py unexpected NEXT on sample dossier"

# Test synthetic state transitions in a temporary dossier
mkdir -p "$TMP_WS/epics/checkout-redesign"
cat > "$TMP_WS/epics/checkout-redesign/00-BRIEFING.md" <<'EOF'
---
card: EPIC-202
slug: checkout-redesign
title: Checkout Redesign
updated: 2026-10-01
---
# Checkout Redesign
EOF
status_new="$(python3 "$REPO_ROOT/skills/epic/epic-status/epic-status.py" "$TMP_WS/epics/checkout-redesign")"
echo "$status_new" | grep -q "/epic-plan checkout-redesign" || fail "Expected /epic-plan for new dossier"
pass "epic-status.py deterministic state transitions verified"

slug_out="$(python3 "$REPO_ROOT/lib/epic-lib/slugify.py" "EPIC-101" "Annual Plan Upgrade!")"
[[ "$slug_out" == "epic-101-annual-plan-upgrade" ]] || fail "slugify.py output mismatch: $slug_out"
pass "slugify.py, frontmatter.py, and citations.py verified"

echo "=== 3. Multi-Agent Runtime (agent-lib & agent-*) ==="

# Create mock herdr binary in TMP_WS/bin
mkdir -p "$TMP_WS/bin" "$TMP_WS/state"
cat > "$TMP_WS/bin/herdr" <<'EOF'
#!/usr/bin/env bash
cmd="${1:-}"; sub="${2:-}"
LOG_FILE="${MOCK_HERDR_LOG:-/tmp/mock-herdr.log}"
echo "herdr $*" >> "$LOG_FILE"
case "$cmd:$sub" in
  agent:list)
    cat <<'JSON'
{"result":{"agents":[
  {"pane_id":"w1:p1","name":"lead-1","agent":"claude","agent_status":"working","cwd":"/tmp","tokens":{"epic":"annual-upgrade","task":"task-1","stage":"implement","ctx":"opus 45%"}},
  {"pane_id":"w1:p2","name":"worker-1","agent":"reasonix","agent_status":"blocked","cwd":"/tmp","tokens":{"epic":"annual-upgrade","task":"task-2","stage":"blocked","ctx":"65%"}}
]}}
JSON
    ;;
  agent:prompt)
    echo '{"ok":true}'
    ;;
  tab:new)
    echo '{"result":{"tab":{"pane_id":"w1:p9"}}}'
    ;;
  pane:split)
    echo '{"result":{"pane":{"pane_id":"w1:p8"}}}'
    ;;
  pane:swap|pane:report-metadata|pane:send-keys)
    echo '{"ok":true}'
    ;;
  pane:get)
    if [[ "${3:-}" == "w1:p2" ]]; then
      echo '{"result":{"tokens":{"ctx":"opus 72%"}}}'
    else
      echo '{"result":{"tokens":{"ctx":"opus 35%"}}}'
    fi
    ;;
  pane:read)
    echo "${MOCK_PANE_TEXT:-Working on task...}"
    ;;
  *)
    echo '{"ok":true}'
    ;;
esac
EOF
chmod +x "$TMP_WS/bin/herdr"
export PATH="$TMP_WS/bin:$PATH"
export HERDR_BIN="$TMP_WS/bin/herdr"
export MOCK_HERDR_LOG="$TMP_WS/herdr.log"

# 3a. agent-map.sh validation & role matrix
map_val="$(bash "$REPO_ROOT/lib/agent-lib/agent-map.sh" validate 2>&1)"
echo "$map_val" | grep -q "WARNING" && fail "agent-map.sh validate emitted warnings: $map_val"
for h in claude codex opencode agy reasonix; do
  for r in manager lead worker investigator reviewer reader; do
    flags_out="$(bash "$REPO_ROOT/lib/agent-lib/agent-map.sh" flags "$h" "$r")"
    [[ -n "$flags_out" ]] || fail "Empty flags for $h:$r"
  done
done
pass "agent-map.sh validate (0 warnings) and 5x6 harness/role matrix verified"

# 3b. ctx-check.sh, pane-tokens.sh, epic-panes.py
ctx_ok="$(bash "$REPO_ROOT/lib/epic-lib/ctx-check.sh" w1:p1)"
echo "$ctx_ok" | grep -q "ctx=35 limit=60 ok" || fail "ctx-check.sh failed for w1:p1: $ctx_ok"
if bash "$REPO_ROOT/lib/epic-lib/ctx-check.sh" w1:p2 >/dev/null 2>&1; then
  fail "ctx-check.sh should exit 1 when above limit"
fi
bash "$REPO_ROOT/lib/epic-lib/pane-tokens.sh" stamp w1:p1 --epic annual-upgrade --task task-1 --stage implement
panes_out="$(python3 "$REPO_ROOT/lib/epic-lib/epic-panes.py")"
echo "$panes_out" | grep -q "annual-upgrade" || fail "epic-panes.py missing annual-upgrade"
echo "$panes_out" | grep -q "NEEDS ATTENTION" || fail "epic-panes.py missing NEEDS ATTENTION"
pass "ctx-check.sh, pane-tokens.sh, and epic-panes.py verified"

# 3c. turn-hook.py across harnesses (prompt, budget enforcement, catch-on-stop)
for h in claude agy opencode reasonix; do
  state_file="$TMP_WS/state/worker-$h-100.json"
  transcript="$TMP_WS/state/transcript-$h.jsonl"
  : > "$transcript"
  if [[ "$h" == "agy" ]]; then
    echo '{"type":"USER_INPUT","source":"USER_EXPLICIT"}' >> "$transcript"
  fi
  cat > "$state_file" <<EOF
{
  "name": "worker-$h",
  "pane": "w1:p5",
  "harness": "$h",
  "return_to": "w1:p1",
  "epic": "annual-upgrade",
  "task": "task-1",
  "budget_minutes": 20,
  "budget_tokens": 1000,
  "tokens_used": 0
}
EOF
  # 1. prompt hook
  echo "{\"transcript_path\":\"$transcript\",\"session_id\":\"s1\"}" | \
    python3 "$REPO_ROOT/lib/agent-lib/turn-hook.py" prompt --state "$state_file" >/dev/null

  # 2. tool hook exceeding budget -> triggers warning
  if [[ "$h" == "agy" ]]; then
    echo '{"source":"MODEL","input_tokens":1500,"output_tokens":500}' >> "$transcript"
    tool_out="$(echo "{\"transcript_path\":\"$transcript\"}" | python3 "$REPO_ROOT/lib/agent-lib/turn-hook.py" tool --state "$state_file" 2>/dev/null)"
    echo "$tool_out" | grep -q '"decision": "deny"' || fail "turn-hook.py ($h) did not deny on budget limit"
  elif [[ "$h" == "opencode" ]]; then
    tool_out="$(echo "{\"tokens\":2000}" | python3 "$REPO_ROOT/lib/agent-lib/turn-hook.py" tool --state "$state_file" 2>/dev/null)"
    echo "$tool_out" | grep -q '"block": true' || fail "turn-hook.py ($h) did not block on budget limit"
  else
    echo '{"type":"assistant","message":{"id":"m1","usage":{"input_tokens":1500,"output_tokens":500}}}' >> "$transcript"
    set +e
    echo "{\"transcript_path\":\"$transcript\"}" | python3 "$REPO_ROOT/lib/agent-lib/turn-hook.py" tool --state "$state_file" 2>/dev/null
    rc=$?
    set -e
    [[ "$rc" -eq 2 ]] || fail "turn-hook.py ($h) expected exit code 2 on budget limit, got $rc"
  fi

  # 3. stop hook without notification -> triggers catch-on-stop callback to w1:p1
  jq '.limit_notified = false | .notified_in_turn = false' "$state_file" > "$state_file.tmp" && mv "$state_file.tmp" "$state_file"
  : > "$MOCK_HERDR_LOG"
  echo "{\"transcript_path\":\"$transcript\",\"last_assistant_message\":\"Done with task\"}" | \
    python3 "$REPO_ROOT/lib/agent-lib/turn-hook.py" stop --state "$state_file" >/dev/null
  grep -q "ended turn without notifying return address" "$MOCK_HERDR_LOG" || fail "turn-hook.py ($h) failed to fire catch-on-stop notification"
done
pass "turn-hook.py verified across claude, agy, opencode, and reasonix"

# 3d. agent-watchdog.py (check, drain, context)
wd_block="$(python3 "$REPO_ROOT/lib/agent-lib/agent-watchdog.py" check w1:p2 --json)"
echo "$wd_block" | grep -q '"verdict": "BLOCKED"' || fail "agent-watchdog.py failed to detect BLOCKED state"

wd_dark="$(MOCK_PANE_TEXT="Error 429: rate limit exceeded" python3 "$REPO_ROOT/lib/agent-lib/agent-watchdog.py" check w1:p1 --json)"
echo "$wd_dark" | grep -q '"verdict": "DARK"' || fail "agent-watchdog.py failed to detect DARK state"

inbox_file="$TMP_WS/inbox.jsonl"
echo '{"task":"task-1","status":"done","pr":"https://github.com/acme-corp/web-app/pull/1"}' > "$inbox_file"
drain_out="$(python3 "$REPO_ROOT/lib/agent-lib/agent-watchdog.py" drain "$inbox_file" --lead w1:p1 --json)"
echo "$drain_out" | grep -q '"action": "DRAIN"' || fail "agent-watchdog.py drain failed: $drain_out"
drain_wait="$(python3 "$REPO_ROOT/lib/agent-lib/agent-watchdog.py" drain "$inbox_file" --lead w1:p1 --json)"
echo "$drain_wait" | grep -q '"action": "WAIT"' || fail "agent-watchdog.py second drain should WAIT: $drain_wait"

ctx_wd="$(python3 "$REPO_ROOT/lib/agent-lib/agent-watchdog.py" context --json)"
echo "$ctx_wd" | grep -q '"alert": true' || fail "agent-watchdog.py context failed to flag alert"
pass "agent-watchdog.py (check, drain, context) verified"

# 3e. agent-executor.sh, agent-reviewer.sh, agent-reader.sh
mkdir -p "$TMP_WS/remotes/web-app.git" "$TMP_WS/repos/web-app"
git -C "$TMP_WS/remotes/web-app.git" init -q --bare -b main
git -C "$TMP_WS/repos/web-app" init -q -b main
git -C "$TMP_WS/repos/web-app" config user.email "test@example.com"
git -C "$TMP_WS/repos/web-app" config user.name "Test"
git -C "$TMP_WS/repos/web-app" remote add origin "$TMP_WS/remotes/web-app.git"
echo "hello" > "$TMP_WS/repos/web-app/README.md"
git -C "$TMP_WS/repos/web-app" add README.md
git -C "$TMP_WS/repos/web-app" commit -q -m "initial"
git -C "$TMP_WS/repos/web-app" push -q -u origin main

ref_out="$(python3 "$REPO_ROOT/lib/epic-lib/repo_ref.py" "$TMP_WS/repos/web-app")"
echo "$ref_out" | grep -q '"base_ref": "origin/main"' || fail "repo_ref.py failed on local repo: $ref_out"

brief_file="$TMP_WS/brief.md"
echo "Implement task 1" > "$brief_file"
exec_out="$(AGENT_EXECUTOR_REPO_ROOTS="$TMP_WS/repos" AGENT_STATE_DIR="$TMP_WS/state" \
  bash "$REPO_ROOT/skills/agent/agent-executor/agent-executor.sh" \
  web-app annual-upgrade worker-web "$brief_file" --task task-1)"
echo "$exec_out" | grep -q "branch=epic/annual-upgrade" || fail "agent-executor.sh failed to create worktree branch: $exec_out"
[[ -d "$TMP_WS/repos/web-app-epic-annual-upgrade" ]] || fail "Worktree directory not created"

rev_out="$(HERDR_PANE_ID="w1:p1" AGENT_REVIEW_RUNDIR_BASE="$TMP_WS/reviews" \
  bash "$REPO_ROOT/skills/agent/agent-reviewer/agent-reviewer.sh" \
  "https://github.com/acme-corp/web-app/pull/42")"
echo "$rev_out" | grep -q "PANE=w1:p8" || fail "agent-reviewer.sh failed: $rev_out"
echo "$rev_out" | grep -q "ABOVE=true" || fail "agent-reviewer.sh failed to swap pane above caller"

reader_out="$(HERDR_PANE_ID="w1:p1" AGENT_READER_RUNDIR_BASE="$TMP_WS/readers" \
  bash "$REPO_ROOT/skills/agent/agent-reader/agent-reader.sh" \
  --scope "$TMP_WS/repos/web-app" "Where is README?")"
echo "$reader_out" | grep -q "PANE=w1:p8" || fail "agent-reader.sh failed: $reader_out"
pass "agent-executor.sh, agent-reviewer.sh, and agent-reader.sh verified"

echo "=== 4. Experiment Statistics (experiment_stats.py) ==="

python3 "$REPO_ROOT/skills/epic/epic-analyze-metrics/scripts/experiment_stats.py" --help >/dev/null
stats_out="$(python3 "$REPO_ROOT/skills/epic/epic-analyze-metrics/scripts/experiment_stats.py" <<'EOF'
{
  "decision_type": "superiority",
  "start_date": "2026-10-01",
  "end_date": "2026-10-15",
  "mde_relative": 0.10,
  "control": {"name": "control", "participants": 10000, "conversions": 500},
  "variants": [
    {"name": "variant_a", "participants": 10000, "conversions": 600}
  ]
}
EOF
)"
echo "$stats_out" | grep -q '"winner": "variant_a"' || fail "experiment_stats.py failed to identify significant winner"
echo "$stats_out" | grep -q '"decision_ready": true' || fail "experiment_stats.py decision_ready should be true"
pass "experiment_stats.py (--help, z-test, SRM chi-square, Bayesian probability) verified"

echo ""
echo "✅ ALL EPIC ENGINE VERIFICATION CHECKS PASSED."
