#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

MODE="plan"
REPO_FILE="$ROOT_DIR/config/repos.txt"
CODEX_CONFIG_REF="master"

repo_specs=()
created=0
updated=0
unchanged=0

usage() {
  cat <<USAGE
Usage: scripts/sync-codex-config.sh [options]

Options:
  --plan                      Show planned changes only (default)
  --apply                     Apply changes
  --repo <path|type|stage>    Add target repo spec (repeatable)
  --repo-file <path>          Inventory file path (default: config/repos.txt)
  --config-ref <ref>          Ref used in workflow template (default: master)
  --help                      Show this help

Spec format:
  path|project_type|stage
  - project_type: app | infra | db | mixed
  - stage: 1|warn|stage1 or 2|enforce|stage2

Examples:
  scripts/sync-codex-config.sh --plan
  scripts/sync-codex-config.sh --apply --repo "/path/to/app|app|1"
  scripts/sync-codex-config.sh --apply --repo-file config/repos.txt --config-ref v1
USAGE
}

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  echo "$value"
}

normalize_stage_mode() {
  local stage_raw="$1"
  local lowered
  lowered="$(printf '%s' "$stage_raw" | tr '[:upper:]' '[:lower:]')"
  case "$lowered" in
    ""|"1"|"warn"|"stage1")
      echo "warn"
      ;;
    "2"|"enforce"|"stage2")
      echo "enforce"
      ;;
    *)
      echo "[sync] Invalid stage '$stage_raw'. Use 1/warn or 2/enforce." >&2
      return 1
      ;;
  esac
}

is_valid_project_type() {
  case "$1" in
    app|infra|db|mixed)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

log_action() {
  local action="$1"
  local detail="$2"
  if [[ "$MODE" == "plan" ]]; then
    echo "[plan] $action: $detail"
  else
    echo "[apply] $action: $detail"
  fi
}

ensure_dir() {
  local dir="$1"
  if [[ -d "$dir" ]]; then
    return 0
  fi

  log_action "mkdir" "$dir"
  if [[ "$MODE" == "apply" ]]; then
    mkdir -p "$dir"
  fi
}

sync_file() {
  local src="$1"
  local dst="$2"
  local existed_before=0

  ensure_dir "$(dirname "$dst")"

  [[ -f "$dst" ]] && existed_before=1

  if [[ -f "$dst" ]] && cmp -s "$src" "$dst"; then
    unchanged=$((unchanged + 1))
    log_action "unchanged" "$dst"
    return 0
  fi

  if [[ "$MODE" == "apply" ]]; then
    cp "$src" "$dst"
  fi

  if [[ $existed_before -eq 1 ]]; then
    updated=$((updated + 1))
    log_action "update" "$dst"
  else
    created=$((created + 1))
    log_action "create" "$dst"
  fi
}

sync_template_if_missing() {
  local src="$1"
  local dst="$2"

  if [[ -f "$dst" ]]; then
    unchanged=$((unchanged + 1))
    log_action "keep" "$dst"
    return 0
  fi

  ensure_dir "$(dirname "$dst")"
  if [[ "$MODE" == "apply" ]]; then
    cp "$src" "$dst"
  fi

  created=$((created + 1))
  log_action "create-template" "$dst"
}

render_workflow_caller() {
  local dst="$1"
  local project_type="$2"
  local enforcement_mode="$3"
  local existed_before=0

  local template="$ROOT_DIR/templates/workflows/codex-guardrails.yml"
  ensure_dir "$(dirname "$dst")"
  [[ -f "$dst" ]] && existed_before=1

  local rendered
  rendered="$(sed \
    -e "s|__CODEX_CONFIG_REF__|$CODEX_CONFIG_REF|g" \
    -e "s|__PROJECT_TYPE__|$project_type|g" \
    -e "s|__ENFORCEMENT_MODE__|$enforcement_mode|g" \
    "$template")"

  if [[ -f "$dst" ]] && [[ "$rendered" == "$(cat "$dst")" ]]; then
    unchanged=$((unchanged + 1))
    log_action "unchanged" "$dst"
    return 0
  fi

  if [[ "$MODE" == "apply" ]]; then
    printf '%s\n' "$rendered" > "$dst"
  fi

  if [[ $existed_before -eq 1 ]]; then
    updated=$((updated + 1))
    log_action "update" "$dst"
  else
    created=$((created + 1))
    log_action "create" "$dst"
  fi
}

parse_repo_spec() {
  local raw_spec="$1"
  local path type stage

  IFS='|' read -r path type stage <<< "$raw_spec"
  path="$(trim "${path:-}")"
  type="$(trim "${type:-mixed}")"
  stage="$(trim "${stage:-1}")"

  if [[ -z "$path" ]]; then
    echo "[sync] Empty repo path in spec: $raw_spec" >&2
    return 1
  fi

  if ! is_valid_project_type "$type"; then
    echo "[sync] Invalid project type '$type' for $path. Use app|infra|db|mixed." >&2
    return 1
  fi

  local enforcement_mode
  enforcement_mode="$(normalize_stage_mode "$stage")"

  echo "$path|$type|$enforcement_mode"
}

load_repo_specs() {
  if [[ ${#repo_specs[@]} -gt 0 ]]; then
    return 0
  fi

  if [[ ! -f "$REPO_FILE" ]]; then
    echo "[sync] Repo file not found: $REPO_FILE" >&2
    return 1
  fi

  while IFS= read -r line; do
    line="$(trim "$line")"
    [[ -z "$line" ]] && continue
    [[ "${line:0:1}" == "#" ]] && continue

    local parsed
    parsed="$(parse_repo_spec "$line")"
    repo_specs+=("$parsed")
  done < "$REPO_FILE"

  if [[ ${#repo_specs[@]} -eq 0 ]]; then
    echo "[sync] No repo specs found. Add entries to $REPO_FILE or pass --repo." >&2
    return 1
  fi
}

apply_sync_to_repo() {
  local repo_path="$1"
  local project_type="$2"
  local enforcement_mode="$3"

  local abs_repo
  if [[ "$repo_path" == /* ]]; then
    abs_repo="$repo_path"
  else
    abs_repo="$ROOT_DIR/$repo_path"
  fi

  if [[ ! -d "$abs_repo" ]]; then
    echo "[sync] Repo path does not exist: $abs_repo" >&2
    return 1
  fi

  abs_repo="$(cd "$abs_repo" && pwd)"

  echo "[sync] Target: $abs_repo (type=$project_type, mode=$enforcement_mode)"

  sync_file "$ROOT_DIR/AGENTS.md" "$abs_repo/AGENTS.md"

  sync_file "$ROOT_DIR/scripts/check-app.sh" "$abs_repo/scripts/check-app.sh"
  sync_file "$ROOT_DIR/scripts/check-iac.sh" "$abs_repo/scripts/check-iac.sh"
  sync_file "$ROOT_DIR/scripts/check-db-migrations.sh" "$abs_repo/scripts/check-db-migrations.sh"
  sync_file "$ROOT_DIR/scripts/lib/enforcement.sh" "$abs_repo/scripts/lib/enforcement.sh"

  sync_file "$ROOT_DIR/skills/app-dev/SKILL.md" "$abs_repo/skills/app-dev/SKILL.md"
  sync_file "$ROOT_DIR/skills/app-dev/templates/pr-summary-template.md" "$abs_repo/skills/app-dev/templates/pr-summary-template.md"
  sync_file "$ROOT_DIR/skills/infra-ops/SKILL.md" "$abs_repo/skills/infra-ops/SKILL.md"
  sync_file "$ROOT_DIR/skills/infra-ops/references/plan-review-checklist.md" "$abs_repo/skills/infra-ops/references/plan-review-checklist.md"
  sync_file "$ROOT_DIR/skills/dba-ops/SKILL.md" "$abs_repo/skills/dba-ops/SKILL.md"
  sync_file "$ROOT_DIR/skills/dba-ops/checklists/migration-safety-checklist.md" "$abs_repo/skills/dba-ops/checklists/migration-safety-checklist.md"

  sync_file "$ROOT_DIR/standards/coding/README.md" "$abs_repo/standards/coding/README.md"
  sync_file "$ROOT_DIR/standards/security/README.md" "$abs_repo/standards/security/README.md"
  sync_file "$ROOT_DIR/standards/sre/README.md" "$abs_repo/standards/sre/README.md"

  if [[ "$abs_repo" == "$ROOT_DIR" ]]; then
    sync_file \
      "$ROOT_DIR/.github/workflows/codex-guardrails.yml" \
      "$abs_repo/.github/workflows/codex-guardrails.yml"
  else
    render_workflow_caller "$abs_repo/.github/workflows/codex-guardrails.yml" "$project_type" "$enforcement_mode"
  fi

  if [[ "$abs_repo" != "$ROOT_DIR" ]]; then
    case "$project_type" in
      app)
        sync_template_if_missing "$ROOT_DIR/templates/scripts/app-check.sh" "$abs_repo/scripts/app-check.sh"
        ;;
      infra)
        sync_template_if_missing "$ROOT_DIR/templates/scripts/iac-plan.sh" "$abs_repo/scripts/iac-plan.sh"
        ;;
      db)
        sync_template_if_missing "$ROOT_DIR/templates/scripts/db-check.sh" "$abs_repo/scripts/db-check.sh"
        ;;
      mixed)
        sync_template_if_missing "$ROOT_DIR/templates/scripts/app-check.sh" "$abs_repo/scripts/app-check.sh"
        sync_template_if_missing "$ROOT_DIR/templates/scripts/iac-plan.sh" "$abs_repo/scripts/iac-plan.sh"
        sync_template_if_missing "$ROOT_DIR/templates/scripts/db-check.sh" "$abs_repo/scripts/db-check.sh"
        ;;
    esac
  fi

  if [[ "$MODE" == "apply" ]]; then
    chmod +x \
      "$abs_repo/scripts/check-app.sh" \
      "$abs_repo/scripts/check-iac.sh" \
      "$abs_repo/scripts/check-db-migrations.sh"

    [[ -f "$abs_repo/scripts/app-check.sh" ]] && chmod +x "$abs_repo/scripts/app-check.sh"
    [[ -f "$abs_repo/scripts/iac-plan.sh" ]] && chmod +x "$abs_repo/scripts/iac-plan.sh"
    [[ -f "$abs_repo/scripts/db-check.sh" ]] && chmod +x "$abs_repo/scripts/db-check.sh"
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --plan)
      MODE="plan"
      shift
      ;;
    --apply)
      MODE="apply"
      shift
      ;;
    --repo)
      if [[ $# -lt 2 ]]; then
        echo "[sync] --repo requires a value." >&2
        exit 1
      fi
      repo_specs+=("$(parse_repo_spec "$2")")
      shift 2
      ;;
    --repo-file)
      if [[ $# -lt 2 ]]; then
        echo "[sync] --repo-file requires a path." >&2
        exit 1
      fi
      REPO_FILE="$2"
      shift 2
      ;;
    --config-ref)
      if [[ $# -lt 2 ]]; then
        echo "[sync] --config-ref requires a value." >&2
        exit 1
      fi
      CODEX_CONFIG_REF="$2"
      shift 2
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      echo "[sync] Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

load_repo_specs

for spec in "${repo_specs[@]}"; do
  IFS='|' read -r repo_path project_type enforcement_mode <<< "$spec"
  apply_sync_to_repo "$repo_path" "$project_type" "$enforcement_mode"
done

echo "[sync] Done. created=$created updated=$updated unchanged=$unchanged mode=$MODE"
