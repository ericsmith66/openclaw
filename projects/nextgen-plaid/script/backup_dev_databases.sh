#!/usr/bin/env bash

set -euo pipefail

# Development DB backup (PostgreSQL)
# - Dumps dev databases daily
# - Retains the last 7 days (by mtime)
# - Stores backups outside the repo (iCloud Drive path by default)

DEST_DIR_DEFAULT="/Users/ericsmith66/Library/Mobile Documents/com~apple~CloudDocs/Dev-Backups/M3-UltraServer"
DEST_DIR="${DEST_DIR:-$DEST_DIR_DEFAULT}"

RETENTION_DAYS="${RETENTION_DAYS:-7}"
DRY_RUN="${DRY_RUN:-0}"

# These are defined in config/database.yml under development:
DBS=(
  "nextgen_plaid_development"
  "nextgen_plaid_development_queue"
  "nextgen_plaid_development_cable"
)

PROJECT_TAG="nextgen-plaid__dev"

timestamp() {
  date "+%Y-%m-%d_%H%M%S"
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "ERROR: required command not found: $1" >&2
    exit 1
  fi
}

main() {
  require_cmd pg_dump
  require_cmd find
  require_cmd mkdir
  require_cmd rm

  mkdir -p "$DEST_DIR"

  local ts
  ts="$(timestamp)"

  # Store each run in its own directory
  local run_dir
  run_dir="$DEST_DIR/${PROJECT_TAG}__${ts}"

  mkdir -p "$run_dir"

  # Create dumps (custom format; suitable for pg_restore)
  for db in "${DBS[@]}"; do
    local out
    out="$run_dir/${db}.dump"

    echo "Backing up ${db} -> ${out}"
    if [[ "$DRY_RUN" == "1" ]]; then
      echo "DRY_RUN=1; skipping pg_dump for ${db}"
    else
      pg_dump \
        --format=custom \
        --no-owner \
        --no-acl \
        --file "$out" \
        "$db"
    fi
  done

  # Retention: delete backup *run directories* older than RETENTION_DAYS
  # (macOS/BSD find supports -mtime)
  echo "Pruning backup runs older than ${RETENTION_DAYS} days in: ${DEST_DIR}"
  find "$DEST_DIR" \
    -maxdepth 1 \
    -type d \
    -name "${PROJECT_TAG}__*" \
    -mtime "+${RETENTION_DAYS}" \
    -print0 \
  | xargs -0 rm -rf

  # Backward-compat retention: if older scripts created flat files, prune those too.
  find "$DEST_DIR" \
    -maxdepth 1 \
    -type f \
    -name "${PROJECT_TAG}__*.dump" \
    -mtime "+${RETENTION_DAYS}" \
    -print \
    -delete
}

main "$@"
