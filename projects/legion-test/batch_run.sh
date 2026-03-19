#!/bin/bash
# Batch runner: 4 models × 4 prompts = 16 runs
# Resets legion-test between each run
# Usage: SMART_PROXY_TOKEN=xxx ./batch_run.sh [model_filter]

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

if [ -z "$SMART_PROXY_TOKEN" ]; then
  echo "ERROR: SMART_PROXY_TOKEN not set"
  exit 1
fi

# Models to test
MODELS=(
  "grok-4-1-fast-non-reasoning"
  "claude-sonnet-4-6"
  "deepseek-chat"
  "qwen3-coder-next:latest"
)

# Optional: filter to a single model
if [ -n "$1" ]; then
  MODELS=("$1")
  echo "Filtering to model: $1"
fi

PROMPTS=(1 2 3 4)
TOTAL=$((${#MODELS[@]} * ${#PROMPTS[@]}))
CURRENT=0

echo "============================================================"
echo "BATCH RUN: ${#MODELS[@]} models × ${#PROMPTS[@]} prompts = $TOTAL runs"
echo "Models: ${MODELS[*]}"
echo "============================================================"

# Save the initial Rails app state after first setup
RAILS_SETUP_DONE=false

setup_fresh_rails() {
  echo "[RESET] Resetting to initial commit..."
  cd "$SCRIPT_DIR"
  git checkout -- . 2>/dev/null || true
  git clean -fd 2>/dev/null || true

  echo "[RESET] Creating fresh Rails app..."
  # Generate Rails app in /tmp then copy
  TMPDIR=$(mktemp -d)
  cd "$TMPDIR"
  rails new legion-test --database=sqlite3 --skip-javascript --skip-git --skip-docker \
    --skip-action-mailer --skip-action-mailbox --skip-action-text --skip-active-storage \
    --skip-action-cable --skip-hotwire --skip-jbuilder --skip-test --minimal --force 2>&1 | tail -5

  # Copy into project dir (preserve .git)
  cd "$SCRIPT_DIR"
  cp -a "$TMPDIR/legion-test/." "$SCRIPT_DIR/" 2>/dev/null || true

  # Cleanup
  rm -rf "$TMPDIR"

  # Ensure run_test.rb and batch_run.sh survive the reset
  # (They get wiped by git clean — re-extract from stash or parent)
  echo "[RESET] Done. Rails app ready."
}

# Pre-save run_test.rb content
cp "$SCRIPT_DIR/run_test.rb" /tmp/_run_test_backup.rb 2>/dev/null || true
cp "$SCRIPT_DIR/batch_run.sh" /tmp/_batch_run_backup.sh 2>/dev/null || true

# Also preserve results.json if it exists
cp "$SCRIPT_DIR/results.json" /tmp/_results_backup.json 2>/dev/null || true

for MODEL in "${MODELS[@]}"; do
  for PROMPT in "${PROMPTS[@]}"; do
    CURRENT=$((CURRENT + 1))
    echo ""
    echo "############################################################"
    echo "# RUN $CURRENT/$TOTAL: Model=$MODEL  Prompt=$PROMPT"
    echo "############################################################"

    # Reset to clean state
    cd "$SCRIPT_DIR"
    git checkout -- . 2>/dev/null || true
    git clean -fd -e results.json -e run_test.rb -e batch_run.sh 2>/dev/null || true

    # Re-create fresh Rails app
    setup_fresh_rails

    # Restore our scripts
    cp /tmp/_run_test_backup.rb "$SCRIPT_DIR/run_test.rb"
    cp /tmp/_batch_run_backup.sh "$SCRIPT_DIR/batch_run.sh"
    [ -f /tmp/_results_backup.json ] && cp /tmp/_results_backup.json "$SCRIPT_DIR/results.json"

    # Run the test
    echo "[START] Prompt $PROMPT with $MODEL"
    START_TIME=$(date +%s)

    timeout 900 ruby run_test.rb "$PROMPT" "$MODEL" 2>&1 || {
      echo "[TIMEOUT/ERROR] Prompt $PROMPT with $MODEL failed (exit code: $?)"
      # Record failure
      python3 -c "
import json, time
f = 'results.json'
try:
    data = json.load(open(f))
except:
    data = []
data.append({
    'prompt': '$PROMPT',
    'prompt_name': 'Prompt $PROMPT',
    'model': '$MODEL',
    'duration_seconds': $(( $(date +%s) - START_TIME )),
    'iterations': 0,
    'tool_calls': 0,
    'timestamp': time.strftime('%Y-%m-%dT%H:%M:%S'),
    'status': 'timeout_or_error'
})
json.dump(data, open(f, 'w'), indent=2)
" 2>/dev/null || true
    }

    # Backup results after each run
    cp "$SCRIPT_DIR/results.json" /tmp/_results_backup.json 2>/dev/null || true

    END_TIME=$(date +%s)
    ELAPSED=$((END_TIME - START_TIME))
    echo "[DONE] Prompt $PROMPT with $MODEL — ${ELAPSED}s"
  done
done

echo ""
echo "============================================================"
echo "ALL RUNS COMPLETE ($TOTAL total)"
echo "Results saved to: $SCRIPT_DIR/results.json"
echo "============================================================"

# Print summary table
echo ""
echo "SUMMARY:"
python3 -c "
import json
data = json.load(open('results.json'))
print(f\"{'Model':<35} {'Prompt':<8} {'Status':<12} {'Duration':<10} {'Iterations':<12} {'Tools':<8}\")
print('-' * 85)
for r in data:
    print(f\"{r['model']:<35} {r['prompt']:<8} {r['status']:<12} {str(r['duration_seconds'])+'s':<10} {r['iterations']:<12} {r['tool_calls']:<8}\")
" 2>/dev/null || echo "(install python3 for summary table)"
