# Epic: CONTINUE-01 — Continue (RubyMine) Integration via SmartProxy

## Current status (as of 2026-01-04)
- ✅ Continue chat works against SmartProxy using OpenAI-style `POST /v1/chat/completions`.
- ✅ Streaming compatibility required by Continue is working (SSE output is produced even when upstream returns non-streaming JSON).
- ✅ Test coverage:
  - `bin/rails test` passes
  - `bin/rails smart_proxy:live_test` passes
- ✅ 0040 Live search is implemented in SmartProxy (agentic tool calling; gated behind `SMART_PROXY_ENABLE_WEB_TOOLS=false` by default).
  - Live research requires selecting a `grok-*-with-live-search` model alias (e.g., `grok-4-with-live-search`).
  - Plain `grok-*` behaves as “no live search”.
- ✅ Live smoke tests cover the `grok-*-with-live-search` path when enabled.
- ⚠️ SmartProxy fixes are currently **uncommitted** local changes in:
  - `smart_proxy/app.rb`
  - `smart_proxy/lib/ollama_client.rb`

## Open questions
- How should Continue pass the SmartProxy auth token?
  - For `provider: openai` in Continue, the usual mechanism is setting `apiKey:` to the token value.
  - If Continue supports `apiKeyEnvVar:`, prefer that (e.g. `apiKeyEnvVar: SMART_PROXY_AUTH_TOKEN`) so the token is not stored in plaintext.
### Epic Goal
Make SmartProxy a reliable **OpenAI-compatible provider** for the Continue integration inside RubyMine so an editor user can:
- authenticate with SmartProxy,
- select **either Ollama or Grok models** from a model list,
- chat successfully,
- and (optionally) use **web search / live search** via SmartProxy-managed tool calls.
- dont break anything in the rails app.

### Scope
- Continue (RubyMine) can point at `http://localhost:<SMART_PROXY_PORT>/v1`.
- `GET /v1/models` returns a combined model list (Ollama + Grok).
- `POST /v1/chat/completions` works reliably (OpenAI-shaped responses, good errors).
- Streaming support is added **only if Continue requires it** (Continue does; SmartProxy must return valid SSE).
- Grok web search is supported behind a safety gate (default off).

### Known-good Continue config (minimal)
This is the baseline expected to work for chat:
```yaml
models:
  - title: "SmartProxy Ollama (llama3.1:70b)"
    provider: openai
    model: "llama3.1:70b"
    apiBase: "http://127.0.0.1:3002/v1"
    apiKey: "sk-continue" # SmartProxy auth token

  - title: "SmartProxy Grok (with live search)"
    provider: openai
    model: "grok-4-with-live-search"
    apiBase: "http://127.0.0.1:3002/v1"
    apiKey: "sk-continue" # SmartProxy auth token
```

Notes:
- If Continue supports `apiKeyEnvVar`, prefer that instead of `apiKey`.
- Ensure nothing uses `provider: ollama` pointed at the SmartProxy port (`3002`). Ollama-native providers should point at `http://127.0.0.1:11434`.
- `grok-4-with-live-search` is an alias: SmartProxy routes upstream as `grok-4` but only injects/executes web tools when `SMART_PROXY_ENABLE_WEB_TOOLS=true`.

Live search implementation notes:
- SmartProxy executes `web_search` via an inner Grok call and returns strict JSON tool results to Grok, then returns a single final completion to the caller.
- SmartProxy does not depend on xAI `/v1/search/*` endpoints.

### Workflow Context (What “works” means)
- Editor selects a model (from `/v1/models`) and sends chat messages.
- SmartProxy routes requests:
  - `model` starts with `grok` → Grok provider
  - otherwise → Ollama provider
- SmartProxy logs allow correlation from editor errors → proxy request → upstream response.

### Run Artifacts (Observability)
SmartProxy must emit structured logs into `log/smart_proxy.log` for:
- request received (including anonymized payload)
- response received (status, abbreviated body)
- routing decision (grok vs ollama)
- tool loop events (when enabled)

### Non-Goals
- Embeddings/RAG for Continue (separate epic later).
- Any Rails UI changes.
- Rewriting SapAgent behavior (except ensuring it does not block Continue work).

### Risks/Mitigations
- Continue may require SSE streaming → SmartProxy must return valid SSE chunks + `[DONE]` when `stream: true`.
- Continue may reject non-standard OpenAI shapes → keep strict contract checks and clear 4xx errors.
- Web search adds cost/privacy risk → gate behind `SMART_PROXY_ENABLE_WEB_TOOLS=false` default + loop caps.

### Provider Support Notes
- **Preferred model source of truth** for Continue: SmartProxy `GET /v1/models`.
- Grok is available only if `GROK_API_KEY` or `GROK_API_KEY_SAP` is set.

### Atomic PRDs Table
| Priority | Feature | Status | Dependencies |
|----------|---------|--------|--------------|
| 1 | 0010: Continue Compatibility Baseline (auth + OpenAI shapes + diagnostics) | Done (local, uncommitted) | None |
| 2 | 0020: Combined Model Registry for Continue (Ollama + Grok in `/v1/models`) | Done (local, uncommitted) | #1 |
| 3 | 0030: Streaming Support for `/v1/chat/completions` (only if required) | Done (local, uncommitted) | #1 |
| 4 | 0040: Web Search / Live Search Tool Loop (gated, observable, capped) | Implemented (gated, needs Continue validation) | #1, #2 |
| 5 | 0050: “Known-Good Continue Config” + Troubleshooting Guide | In progress | #1, #2 |
