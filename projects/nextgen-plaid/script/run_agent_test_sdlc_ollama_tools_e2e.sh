#!/usr/bin/env bash
set -euo pipefail

# Test mixed-provider workflow: Grok (SAP/Coord/Planner) -> Ollama (CWA)
# Validates normalization of Grok-style tool calls when consumed by Ollama

cd "$(dirname "$0")/.."

if command -v rbenv >/dev/null 2>&1; then
  eval "$(rbenv init -)"
fi

RUN_ID="${1:-$(ruby -e 'require "securerandom"; puts SecureRandom.uuid')}"

export AI_TOOLS_EXECUTE="${AI_TOOLS_EXECUTE:-true}"
export OLLAMA_TOOLS_ENABLED="${OLLAMA_TOOLS_ENABLED:-true}"
export OLLAMA_TOOL_MODEL="${OLLAMA_TOOL_MODEL:-llama3-groq-tool-use:70b}"

# SmartProxy auth token must be present for local runs.
if [[ -z "${PROXY_AUTH_TOKEN:-}" ]]; then
  echo "WARN: PROXY_AUTH_TOKEN is not set; SmartProxy may return 401." >&2
fi

bundle exec rake agent:test_sdlc -- \
  --run-id="$RUN_ID" \
  --mode=end_to_end \
  --input="Create a simple CRUD feature for managing AiWorkflowTags" \
  --prompt-sap=knowledge_base/prompts/sap_prd.md.erb \
  --prompt-coord=knowledge_base/prompts/coord_analysis.md.erb \
  --prompt-planner=knowledge_base/prompts/planner_breakdown.md \
  --prompt-cwa=knowledge_base/prompts/cwa_execution.md.erb \
  --rag-sap=foundation \
  --rag-coord=foundation \
  --rag-planner=foundation \
  --rag-cwa=tier-1 \
  --sandbox-level=loose \
  --max-tool-calls=50 \
  --model-sap=grok-4-latest \
  --model-coord=grok-4-latest \
  --model-planner=grok-4-latest \
  --model-cwa=llama3-groq-tool-use:70b \
  --debug

echo ""
echo "E2E test completed. Check logs for:"
echo "  - tool_arguments_normalized events"
echo "  - model_selected_for_tools events"
echo "  - tool_calls_parsed_from_ollama events"
echo ""
echo "Verify no HTTP 400 errors from Ollama:"
echo "  grep -i '400' log/smart_proxy.log | grep -i ollama"
echo ""
echo "Check run artifacts:"
echo "  ls -la knowledge_base/test_artifacts/$RUN_ID/"
