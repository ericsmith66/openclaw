#!/usr/bin/env bash
set -euo pipefail

# ----------------------------
# Config (override via env)
# ----------------------------
SMARTPROXY_BASE_URL="${SMARTPROXY_BASE_URL:-http://127.0.0.1:3002}"
SMARTPROXY_TOKEN="${SMARTPROXY_TOKEN:-sk-continue}"

# Optional: xAI key for direct API checks
XAI_KEY="${XAI_KEY:-}"

# Query used for search tests
QUERY="${QUERY:-Tesla TSLA price today}"

have() { command -v "$1" >/dev/null 2>&1; }

print_header() {
  printf "\n==== %s ====\n" "$1"
}

# Prefer jq if present, but don't require it
pretty_json() {
  if have jq; then
    jq .
  else
    cat
  fi
}

req_id() {
  # unique-ish request id for correlation
  echo "test-$(date +%s)-$RANDOM"
}

# ----------------------------
# SmartProxy checks
# ----------------------------
print_header "SmartProxy /health"
curl -sS -i "${SMARTPROXY_BASE_URL}/health" || true

echo

print_header "SmartProxy /v1/models"
curl -sS -i \
  -H "Authorization: Bearer ${SMARTPROXY_TOKEN}" \
  "${SMARTPROXY_BASE_URL}/v1/models" \
  | (have jq && tail -n +1 | pretty_json || cat)

echo

print_header "SmartProxy /proxy/tools (expects 200 if SMART_PROXY_ENABLE_WEB_TOOLS=true)"
curl -sS -i \
  -H "Authorization: Bearer ${SMARTPROXY_TOKEN}" \
  -H "Content-Type: application/json" \
  "${SMARTPROXY_BASE_URL}/proxy/tools" \
  -d "{\"query\":\"${QUERY}\",\"num_results\":3}" \
  | cat

echo

print_header "SmartProxy Ollama chat (non-streaming)"
curl -sS -i \
  -H "Authorization: Bearer ${SMARTPROXY_TOKEN}" \
  -H "Content-Type: application/json" \
  "${SMARTPROXY_BASE_URL}/v1/chat/completions" \
  -d '{
    "model": "llama3.1:70b",
    "stream": false,
    "messages": [
      {"role": "user", "content": "Reply with 9x9="}
    ]
  }' \
  | cat

echo

print_header "SmartProxy Ollama chat (streaming SSE)"
echo "(Should output data: ... lines and end with data: [DONE])"
curl -N -sS \
  -H "Authorization: Bearer ${SMARTPROXY_TOKEN}" \
  -H "Content-Type: application/json" \
  "${SMARTPROXY_BASE_URL}/v1/chat/completions" \
  -d '{
    "model": "llama3.1:70b",
    "stream": true,
    "messages": [
      {"role": "user", "content": "Stream a 1-sentence greeting."}
    ]
  }' \
  | sed -n '1,50p'

echo

print_header "SmartProxy Grok alias path (0040) - grok-4-with-live-search"
echo "NOTE: Requires SmartProxy to have GROK_API_KEY or GROK_API_KEY_SAP set"
curl -sS -i \
  -H "Authorization: Bearer ${SMARTPROXY_TOKEN}" \
  -H "Content-Type: application/json" \
  "${SMARTPROXY_BASE_URL}/v1/chat/completions" \
  -d '{
    "model": "grok-4-with-live-search",
    "stream": false,
    "temperature": 0,
    "messages": [
      {"role": "system", "content": "Use web search tools when needed and include a source URL."},
      {"role": "user", "content": "What is the TSLA price today? Provide the price and a source URL."}
    ]
  }' \
  | cat

# ----------------------------
# Direct xAI checks (optional)
# ----------------------------
if [[ -n "${XAI_KEY}" ]]; then
  print_header "Direct xAI chat/completions (sanity)"
  curl -sS -i \
    -H "Authorization: Bearer ${XAI_KEY}" \
    -H "Content-Type: application/json" \
    -H "X-Request-ID: $(req_id)" \
    https://api.x.ai/v1/chat/completions \
    -d '{
      "model": "grok-4",
      "messages": [{"role":"user","content":"Reply with OK"}],
      "stream": false
    }' \
    | cat

  echo

  print_header "Direct xAI search probes (likely to 404 if Search API not enabled)"
  echo "-- /v1/search/web"
  curl -sS -i \
    -H "Authorization: Bearer ${XAI_KEY}" \
    -H "Content-Type: application/json" \
    -H "X-Request-ID: $(req_id)" \
    https://api.x.ai/v1/search/web \
    -d "{\"query\":\"${QUERY}\",\"num_results\":3}" \
    | cat

  echo
  echo "-- /v1/search/x"
  curl -sS -i \
    -H "Authorization: Bearer ${XAI_KEY}" \
    -H "Content-Type: application/json" \
    -H "X-Request-ID: $(req_id)" \
    https://api.x.ai/v1/search/x \
    -d "{\"query\":\"${QUERY}\",\"limit\":3,\"mode\":\"top\"}" \
    | cat

  echo
  echo "-- /v1/search (unified)"
  curl -sS -i \
    -H "Authorization: Bearer ${XAI_KEY}" \
    -H "Content-Type: application/json" \
    -H "X-Request-ID: $(req_id)" \
    https://api.x.ai/v1/search \
    -d "{\"query\":\"${QUERY}\",\"num_results\":3}" \
    | cat

else
  print_header "Direct xAI checks skipped"
  echo "Set XAI_KEY env var to run direct xAI API calls, e.g.:"
  echo "  export XAI_KEY=..."
fi

print_header "Done"