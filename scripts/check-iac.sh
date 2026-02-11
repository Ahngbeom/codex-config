#!/usr/bin/env bash
set -euo pipefail

if [[ -x "scripts/iac-check.sh" ]]; then
  echo "[iac] Running custom IaC checks: scripts/iac-check.sh"
  scripts/iac-check.sh
  exit 0
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
  echo "[iac] Terraform files detected but terraform binary is missing."
  exit 1
fi

echo "[iac] terraform fmt -check -recursive"
terraform fmt -check -recursive

dirs=$(for tf in "${tf_files[@]}"; do dirname "$tf"; done | sort -u)
for d in $dirs; do
  echo "[iac] terraform init/validate in $d"
  (
    cd "$d"
    terraform init -backend=false -input=false -no-color >/dev/null
    terraform validate -no-color
  )
done

if [[ -x "scripts/iac-plan.sh" ]]; then
  echo "[iac] Running custom plan check: scripts/iac-plan.sh"
  scripts/iac-plan.sh
else
  echo "[iac] Terraform files detected, but scripts/iac-plan.sh is missing."
  echo "[iac] Add scripts/iac-plan.sh to enforce environment-specific plan checks."
  exit 1
fi
