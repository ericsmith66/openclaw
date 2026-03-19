#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

RUN_ID="0004_grok"
OUT_DIR="bulk_test/${RUN_ID}/with_epic"
mkdir -p "$OUT_DIR"

: "${SMART_PROXY_PORT:=3002}"
: "${PROXY_AUTH_TOKEN:?PROXY_AUTH_TOKEN is required}"
: "${AI_MODEL:=grok-4}"

RUN_WINDOW_FILE="bulk_test/${RUN_ID}/run_window.txt"
echo "$(date '+%Y-%m-%d %H:%M:%S %z')" > "$RUN_WINDOW_FILE"

EPIC_PATH="knowledge_base/epics/AGENT-05/AGENT-05-Epic.md"
EPIC_CONTENT="$(ruby -e 'print File.read(ARGV[0])' "$EPIC_PATH")"

title_for_id() {
  local id="$1"
  ruby -e 'id=ARGV[0]; path=ARGV[1]; row=File.read(path).lines.find{|l| l.include?("| "+id+":")}; puts(row ? row.split("|")[2].strip : "")' "$id" "$EPIC_PATH"
}

generate_prd() {
  local id="$1"
  local title
  title="$(title_for_id "$id")"

  local prompt
  prompt=$(cat <<EOF
Generate an atomic PRD for: "${id}: ${title}" using the baseline PRD template/headings from knowledge_base/epics/AGENT-05/.
KB-only.
Include a section titled "Context Used" with citations to ${EPIC_PATH} sections.
Keep under 1000 words.
Return only the PRD markdown.
EOF
)

  jq -n \
    --arg model "$AI_MODEL" \
    --arg epic "$EPIC_CONTENT" \
    --arg prompt "$prompt" \
    '{
      model: $model,
      messages: [
        {role:"system", content:("Context:\n" + $epic)},
        {role:"user", content:$prompt}
      ],
      temperature: 0.2
    }' \
  | curl -sS --max-time 900 \
      -H "Authorization: Bearer ${PROXY_AUTH_TOKEN}" \
      -H "Content-Type: application/json" \
      -d @- \
      "http://localhost:${SMART_PROXY_PORT}/v1/chat/completions" \
  | jq -r '.choices[0].message.content' \
  > "${OUT_DIR}/PRD-${id}.md"
}

generate_prd 0010
generate_prd 0020
generate_prd 0030

echo "$(date '+%Y-%m-%d %H:%M:%S %z')" >> "$RUN_WINDOW_FILE"

echo "Wrote:"
ls -1 "$OUT_DIR" | sed 's/^/ - /'
