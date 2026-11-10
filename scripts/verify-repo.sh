#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "Verifying Epic Engine repository structure and contracts..."

for namespace in epic agent implement; do
  if [[ ! -d "$REPO_ROOT/skills/$namespace" ]]; then
    echo "Missing skill namespace directory: skills/$namespace" >&2
    exit 1
  fi
done

while IFS= read -r skill_file; do
  if ! head -n 1 "$skill_file" | grep -qx -- "---"; then
    echo "Missing YAML frontmatter in: $skill_file" >&2
    exit 1
  fi
  if ! grep -qE "^name:[[:space:]]+[a-z0-9-]+" "$skill_file"; then
    echo "Missing 'name:' frontmatter key in: $skill_file" >&2
    exit 1
  fi
done < <(find "$REPO_ROOT/skills" -name "SKILL.md" | sort)

EPIC_ROOT="$REPO_ROOT/examples" EPIC_LIB_DIR="$REPO_ROOT/lib/epic-lib" \
  bash "$REPO_ROOT/lib/epic-lib/epic-context.sh" annual-upgrade >/dev/null

python3 "$REPO_ROOT/skills/epic/epic-status/epic-status.py" \
  "$REPO_ROOT/examples/sample-epic-annual-upgrade" >/dev/null

echo "✅ Epic Engine structure, skill frontmatters, and sample dossier verified."
