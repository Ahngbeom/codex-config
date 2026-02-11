#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"

pass_count=0
fail_count=0

cleanup() {
  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

record_pass() {
  local name="$1"
  echo "[PASS] $name"
  pass_count=$((pass_count + 1))
}

record_fail() {
  local name="$1"
  local expected="$2"
  local got="$3"
  echo "[FAIL] $name (expected=$expected got=$got)"
  fail_count=$((fail_count + 1))
}

run_case() {
  local name="$1"
  local expected="$2"
  local workdir="$3"
  shift 3

  local output
  set +e
  output=$(cd "$workdir" && "$@" 2>&1)
  local rc=$?
  set -e

  if [[ "$expected" == "success" && $rc -eq 0 ]]; then
    record_pass "$name"
  elif [[ "$expected" == "failure" && $rc -ne 0 ]]; then
    record_pass "$name"
  else
    record_fail "$name" "$expected" "$rc"
    echo "$output"
  fi
}

setup_repo() {
  local repo="$1"
  mkdir -p "$repo/scripts/lib"
  cp "$ROOT_DIR/scripts/check-app.sh" "$repo/scripts/check-app.sh"
  cp "$ROOT_DIR/scripts/check-iac.sh" "$repo/scripts/check-iac.sh"
  cp "$ROOT_DIR/scripts/check-db-migrations.sh" "$repo/scripts/check-db-migrations.sh"
  cp "$ROOT_DIR/scripts/lib/enforcement.sh" "$repo/scripts/lib/enforcement.sh"
  chmod +x "$repo/scripts/check-app.sh" "$repo/scripts/check-iac.sh" "$repo/scripts/check-db-migrations.sh"
}

create_tf_stub() {
  local repo="$1"
  mkdir -p "$repo/bin"
  cat > "$repo/bin/terraform" <<'TFEOF'
#!/usr/bin/env bash
case "$1" in
  fmt)
    exit 0
    ;;
  init)
    exit 0
    ;;
  validate)
    exit 0
    ;;
  plan)
    echo "Plan: 0 to add, 0 to change, 0 to destroy."
    exit 0
    ;;
  *)
    exit 0
    ;;
esac
TFEOF
  chmod +x "$repo/bin/terraform"
}

# 1) app repo: package.json + missing app-check -> failure
repo1="$TMP_ROOT/repo-app-missing-custom"
setup_repo "$repo1"
printf '{"name":"demo"}\n' > "$repo1/package.json"
run_case "app missing scripts/app-check.sh" "failure" "$repo1" env CODEX_ENFORCEMENT_MODE=enforce scripts/check-app.sh

# 2) infra repo: .tf + terraform missing -> failure
repo2="$TMP_ROOT/repo-iac-no-terraform"
setup_repo "$repo2"
mkdir -p "$repo2/infra"
printf 'terraform {}\n' > "$repo2/infra/main.tf"
run_case "iac missing terraform binary" "failure" "$repo2" env CODEX_ENFORCEMENT_MODE=enforce PATH="/usr/bin:/bin" scripts/check-iac.sh

# 3) infra repo: .tf + missing iac-plan -> failure
repo3="$TMP_ROOT/repo-iac-missing-plan"
setup_repo "$repo3"
mkdir -p "$repo3/infra"
printf 'terraform {}\n' > "$repo3/infra/main.tf"
create_tf_stub "$repo3"
run_case "iac missing scripts/iac-plan.sh" "failure" "$repo3" env CODEX_ENFORCEMENT_MODE=enforce PATH="$repo3/bin:/usr/bin:/bin" scripts/check-iac.sh

# 4) db repo: up migration only -> failure
repo4="$TMP_ROOT/repo-db-missing-down"
setup_repo "$repo4"
mkdir -p "$repo4/migrations"
printf 'create table t(id int);\n' > "$repo4/migrations/001_create_t_up.sql"
run_case "db up migration without down migration" "failure" "$repo4" env CODEX_ENFORCEMENT_MODE=enforce scripts/check-db-migrations.sh

# 5) db repo: destructive sql without annotation -> failure
repo5="$TMP_ROOT/repo-db-destructive"
setup_repo "$repo5"
mkdir -p "$repo5/migrations"
printf 'drop table users;\n' > "$repo5/migrations/002_drop_users_up.sql"
printf 'create table users(id int);\n' > "$repo5/migrations/002_drop_users_down.sql"
run_case "db destructive sql without allow annotation" "failure" "$repo5" env CODEX_ENFORCEMENT_MODE=enforce scripts/check-db-migrations.sh

# 6) docs-only repo: all checks should pass
repo6="$TMP_ROOT/repo-docs-only"
setup_repo "$repo6"
printf '# docs only\n' > "$repo6/README.md"
run_case "docs-only app check" "success" "$repo6" env CODEX_ENFORCEMENT_MODE=enforce scripts/check-app.sh
run_case "docs-only iac check" "success" "$repo6" env CODEX_ENFORCEMENT_MODE=enforce PATH="/usr/bin:/bin" scripts/check-iac.sh
run_case "docs-only db check" "success" "$repo6" env CODEX_ENFORCEMENT_MODE=enforce scripts/check-db-migrations.sh

# 7) mixed repo with all custom scripts -> success
repo7="$TMP_ROOT/repo-mixed-happy-path"
setup_repo "$repo7"
mkdir -p "$repo7/src" "$repo7/infra" "$repo7/migrations"
printf 'terraform {}\n' > "$repo7/infra/main.tf"
printf 'create table ok(id int);\n' > "$repo7/migrations/010_ok_up.sql"
printf 'drop table ok; -- allow-destructive\n' > "$repo7/migrations/010_ok_down.sql"
create_tf_stub "$repo7"

cat > "$repo7/scripts/app-check.sh" <<'EOF_APP'
#!/usr/bin/env bash
set -euo pipefail
echo "app checks passed"
EOF_APP

cat > "$repo7/scripts/iac-plan.sh" <<'EOF_IAC'
#!/usr/bin/env bash
set -euo pipefail
echo "iac plan checks passed"
EOF_IAC

cat > "$repo7/scripts/db-check.sh" <<'EOF_DB'
#!/usr/bin/env bash
set -euo pipefail
echo "db checks passed"
EOF_DB

chmod +x "$repo7/scripts/app-check.sh" "$repo7/scripts/iac-plan.sh" "$repo7/scripts/db-check.sh"

run_case "mixed app custom check" "success" "$repo7" env CODEX_ENFORCEMENT_MODE=enforce scripts/check-app.sh
run_case "mixed iac custom check" "success" "$repo7" env CODEX_ENFORCEMENT_MODE=enforce PATH="$repo7/bin:/usr/bin:/bin" scripts/check-iac.sh
run_case "mixed db custom check" "success" "$repo7" env CODEX_ENFORCEMENT_MODE=enforce scripts/check-db-migrations.sh

echo "[summary] pass=$pass_count fail=$fail_count"
if [[ $fail_count -ne 0 ]]; then
  exit 1
fi
