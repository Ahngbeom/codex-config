#!/usr/bin/env bash
set -euo pipefail

if [[ -x "scripts/db-check.sh" ]]; then
  echo "[db] Running custom DB checks: scripts/db-check.sh"
  scripts/db-check.sh
  exit 0
fi

migration_roots=("db/migrations" "migrations")
sql_files=()
for root in "${migration_roots[@]}"; do
  if [[ -d "$root" ]]; then
    while IFS= read -r file; do
      sql_files+=("$file")
    done < <(find "$root" -type f -name '*.sql' | sort)
  fi
done

if [[ ${#sql_files[@]} -eq 0 ]]; then
  echo "[db] No SQL migration files detected. Skipping."
  exit 0
fi

status=0

# Rule 1: paired up/down migrations
for file in "${sql_files[@]}"; do
  base="$(basename "$file")"
  dir="$(dirname "$file")"

  if [[ "$base" == *_up.sql ]]; then
    down_file="${dir}/${base%_up.sql}_down.sql"
    if [[ ! -f "$down_file" ]]; then
      echo "[db] Missing rollback migration for $file (expected: $down_file)"
      status=1
    fi
  fi
done

# Rule 2: destructive statements require explicit annotation
for file in "${sql_files[@]}"; do
  if grep -E -n -i '(^|[^A-Z_])(drop[[:space:]]+table|drop[[:space:]]+column|truncate[[:space:]]+table)([^A-Z_]|$)' "$file" >/dev/null; then
    if ! grep -n -- '-- allow-destructive' "$file" >/dev/null; then
      echo "[db] Destructive SQL found without '-- allow-destructive': $file"
      status=1
    fi
  fi
done

if [[ $status -ne 0 ]]; then
  echo "[db] Migration guardrail checks failed."
  exit $status
fi

echo "[db] Migration checks passed."
