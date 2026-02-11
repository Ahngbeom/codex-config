#!/usr/bin/env bash

codex_get_enforcement_mode() {
  local mode="${CODEX_ENFORCEMENT_MODE:-enforce}"
  case "$mode" in
    warn|enforce)
      echo "$mode"
      ;;
    *)
      echo "[guardrails] Invalid CODEX_ENFORCEMENT_MODE='$mode'. Fallback to 'enforce'." >&2
      echo "enforce"
      ;;
  esac
}

codex_print_mode() {
  local scope="$1"
  local mode="$2"
  echo "[$scope] Enforcement mode: $mode"
}

codex_violation() {
  local mode="$1"
  shift
  local message="$*"

  if [[ "$mode" == "warn" ]]; then
    echo "[warn] $message"
    return 0
  fi

  echo "[error] $message"
  return 1
}

codex_run() {
  local mode="$1"
  local label="$2"
  shift 2

  if "$@"; then
    return 0
  fi

  if [[ "$mode" == "warn" ]]; then
    echo "[warn] $label failed (warn mode; not blocking)."
    return 0
  fi

  echo "[error] $label failed."
  return 1
}
