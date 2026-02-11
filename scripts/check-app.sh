#!/usr/bin/env bash
set -euo pipefail

if [[ -x "scripts/app-check.sh" ]]; then
  echo "[app] Running custom app checks: scripts/app-check.sh"
  scripts/app-check.sh
  exit 0
fi

if [[ -f "package.json" || -d "src" || -d "apps" || -d "services" ]]; then
  echo "[app] App-like files detected, but no custom check script found."
  echo "[app] Add scripts/app-check.sh to run lint/unit/integration checks."
  exit 1
fi

echo "[app] No app project detected. Skipping."
