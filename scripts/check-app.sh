#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/enforcement.sh
source "$ROOT_DIR/scripts/lib/enforcement.sh"

mode="$(codex_get_enforcement_mode)"
codex_print_mode "app" "$mode"

if [[ -x "scripts/app-check.sh" ]]; then
  echo "[app] Running custom app checks: scripts/app-check.sh"
  if ! codex_run "$mode" "custom app checks" scripts/app-check.sh; then
    exit 1
  fi
  exit 0
fi

if [[ -f "package.json" || -d "src" || -d "apps" || -d "services" ]]; then
  if ! codex_violation "$mode" "App-like files detected, but scripts/app-check.sh is missing."; then
    exit 1
  fi
  echo "[app] Add scripts/app-check.sh to run lint/unit/integration checks."
  exit 0
fi

echo "[app] No app project detected. Skipping."
