#!/usr/bin/env bash
set -euo pipefail

# Helper script to run the long `agent:test_sdlc` command without hitting shell/tool command-length limits.

cd "$(dirname "$0")/.."

if command -v rbenv >/dev/null 2>&1; then
  eval "$(rbenv init -)"
fi

RUN_ID="${1:-}"
if [[ -z "$RUN_ID" ]]; then
  RUN_ID="$(ruby -e 'require "securerandom"; puts SecureRandom.uuid')"
fi

export AI_TOOLS_EXECUTE="${AI_TOOLS_EXECUTE:-true}"

# SmartProxy auth token must be present for local runs.
if [[ -z "${PROXY_AUTH_TOKEN:-}" ]]; then
  echo "WARN: PROXY_AUTH_TOKEN is not set; SmartProxy may return 401." >&2
fi

bundle exec rake agent:test_sdlc -- \
  --run-id="$RUN_ID" \
  --mode=end_to_end \
  --input="Add an admin page at /admin/ai_workflow_runs that lists the 50 most recent AiWorkflowRuns with columns: correlation_id, status, created_at, updated_at, and active_artifact_id. Add filters for status and a text search for correlation_id. Include a show page at /admin/ai_workflow_runs/:id showing metadata JSON and linked_artifact_ids. Add request specs or system tests to cover the index and show pages." \
  --prompt-sap=knowledge_base/prompts/sap_prd.md.erb \
  --prompt-coord=knowledge_base/prompts/coord_analysis.md.erb \
  --prompt-planner=knowledge_base/prompts/planner_breakdown.md \
  --prompt-cwa=knowledge_base/prompts/cwa_execution.md.erb \
  --rag-sap=foundation \
  --rag-coord=foundation \
  --rag-planner=foundation \
  --rag-cwa=tier-1 \
  --sandbox-level=loose \
  --max-tool-calls=250 \
  --model-sap=grok-4-latest \
  --model-coord=grok-4-latest \
  --model-planner=grok-4-latest \
  --model-cwa=grok-4-latest \
  --debug
