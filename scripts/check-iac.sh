#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/enforcement.sh
source "$ROOT_DIR/scripts/lib/enforcement.sh"

mode="$(codex_get_enforcement_mode)"
codex_print_mode "iac" "$mode"

run_tf_validate_dir() {
  local dir="$1"
  (
    cd "$dir"
    terraform init -backend=false -input=false -no-color >/dev/null
    terraform validate -no-color
  )
}

if [[ -x "scripts/iac-check.sh" ]]; then
  echo "[iac] Running custom IaC checks: scripts/iac-check.sh"
  if ! codex_run "$mode" "custom IaC checks" scripts/iac-check.sh; then
    exit 1
  fi
fi

tf_files=()
while IFS= read -r file; do
  [[ -n "$file" ]] && tf_files+=("$file")
done < <(find . -type f -name '*.tf' -not -path './.terraform/*' | sort)

if [[ ${#tf_files[@]} -eq 0 ]]; then
  echo "[iac] No Terraform files detected. Skipping."
  exit 0
fi

if ! command -v terraform >/dev/null 2>&1; then
  if ! codex_violation "$mode" "Terraform files detected but terraform binary is missing."; then
    exit 1
  fi
  exit 0
fi

echo "[iac] terraform fmt -check -recursive"
if ! codex_run "$mode" "terraform fmt check" terraform fmt -check -recursive; then
  exit 1
fi

tf_dirs=()
while IFS= read -r dir; do
  [[ -n "$dir" ]] && tf_dirs+=("$dir")
done < <(for tf in "${tf_files[@]}"; do dirname "$tf"; done | sort -u)

for d in "${tf_dirs[@]}"; do
  echo "[iac] terraform init/validate in $d"
  if ! codex_run "$mode" "terraform init/validate in $d" run_tf_validate_dir "$d"; then
    exit 1
  fi
done

if [[ -x "scripts/iac-plan.sh" ]]; then
  echo "[iac] Running custom plan check: scripts/iac-plan.sh"
  if ! codex_run "$mode" "custom IaC plan checks" scripts/iac-plan.sh; then
    exit 1
  fi
else
  if ! codex_violation "$mode" "Terraform files detected, but scripts/iac-plan.sh is missing."; then
    exit 1
  fi
  echo "[iac] Add scripts/iac-plan.sh to enforce environment-specific plan checks."
fi
