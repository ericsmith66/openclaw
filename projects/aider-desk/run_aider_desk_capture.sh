#!/usr/bin/env bash
set -euo pipefail

# Directory where logs will be stored
LOG_DIR="/tmp"
# Command to run the application
CMD=(npm run dev)

# Ensure the log directory exists
mkdir -p "$LOG_DIR"

while true; do
  ts=$(date +"%Y-%m-%d_%H-%M-%S")
  log_file="$LOG_DIR/aider-desk_${ts}.log"

  echo "Starting session at $ts"
  echo "Logging to $log_file"
  echo "Command: ${CMD[*]}"
  echo "Press Ctrl+C to stop this session."

  # Check if we should pass -remove-task via env var to avoid CLI parsing issues with electron-vite
  cmd_to_run=("${CMD[@]}")
  env_vars=()
  pass_args=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -remove-task|--remove-task)
        if [[ -n "${2:-}" ]]; then
          env_vars+=("AIDER_DESK_REMOVE_TASK_PROJECT=$2")
          shift 2
        else
          pass_args+=("$1")
          shift
        fi
        ;;
      *)
        pass_args+=("$1")
        shift
        ;;
    esac
  done

  # Execute the command, redirecting both stdout and stderr to the log file and console
  if [[ ${#env_vars[@]} -gt 0 ]]; then
    env "${env_vars[@]}" "${cmd_to_run[@]}" -- "${pass_args[@]+"${pass_args[@]}"}" 2>&1 | tee "$log_file"
  else
    "${cmd_to_run[@]}" -- "${pass_args[@]+"${pass_args[@]}"}" 2>&1 | tee "$log_file"
  fi

  echo "Session ended. Log saved to $log_file"

  read -r -p "Start another session? [y/N] " ans || ans="n"
  if [[ ! "$ans" =~ ^[Yy]$ ]]; then
    break
  fi
  echo ""
done
