#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/enforcement.sh
source "$ROOT_DIR/scripts/lib/enforcement.sh"

mode="$(codex_get_enforcement_mode)"
codex_print_mode "db" "$mode"

if [[ -x "scripts/db-check.sh" ]]; then
  echo "[db] Running custom DB checks: scripts/db-check.sh"
  if ! codex_run "$mode" "custom DB checks" scripts/db-check.sh; then
    exit 1
  fi
  exit 0
fi

migration_roots=("db/migrations" "migrations")
sql_files=()
for root in "${migration_roots[@]}"; do
  if [[ -d "$root" ]]; then
    while IFS= read -r file; do
      [[ -n "$file" ]] && sql_files+=("$file")
    done < <(find "$root" -type f -name '*.sql' | sort)
  fi
done

if [[ ${#sql_files[@]} -eq 0 ]]; then
  echo "[db] No SQL migration files detected. Skipping."
  exit 0
fi

status=0

for file in "${sql_files[@]}"; do
  base="$(basename "$file")"
  dir="$(dirname "$file")"

  if [[ "$base" == *_up.sql ]]; then
    down_file="${dir}/${base%_up.sql}_down.sql"
    if [[ ! -f "$down_file" ]]; then
      if ! codex_violation "$mode" "Missing rollback migration for $file (expected: $down_file)"; then
        status=1
      fi
    fi
  fi
done

for file in "${sql_files[@]}"; do
  if grep -E -n -i '(^|[^A-Z_])(drop[[:space:]]+table|drop[[:space:]]+column|truncate[[:space:]]+table)([^A-Z_]|$)' "$file" >/dev/null; then
    if ! grep -n -- '-- allow-destructive' "$file" >/dev/null; then
      if ! codex_violation "$mode" "Destructive SQL found without '-- allow-destructive': $file"; then
        status=1
      fi
    fi
  fi
done

if [[ $status -ne 0 ]]; then
  echo "[db] Migration guardrail checks failed."
  exit 1
fi

echo "[db] Migration checks passed."
