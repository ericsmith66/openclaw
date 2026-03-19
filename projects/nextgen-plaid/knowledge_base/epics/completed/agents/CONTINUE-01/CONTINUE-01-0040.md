### PRD 0040: Grok Live Web Search (agentic, gated, observable, capped)

**Overview**: Add optional live web search capability for Grok requests using an agentic pattern:
- Grok is provided a `web_search` tool definition.
- Grok requests the tool via `tool_calls`.
- SmartProxy executes `web_search` by making a secondary Grok request ("inner call") to `POST /v1/chat/completions` that returns strict JSON search results back to the main conversation.

Continue remains unaware; it receives only the final assistant output.

**Requirements**:
1) **Gate**
   - Add `SMART_PROXY_ENABLE_WEB_TOOLS` (default `false`).
   - With gate disabled, SmartProxy must not enable any live search behavior (no outbound “search-enabled” Grok requests).
2) **Agentic Tool Loop (Grok tool-calling + SmartProxy execution)**
   - When `model` routes to Grok and live search is enabled:
     - SmartProxy injects a `tools` definition for `web_search` (and optionally `x_keyword_search`).
     - Grok may return `finish_reason: tool_calls`.
     - SmartProxy must append the assistant tool-calling message, execute the tool(s), append `role: tool` messages, and continue until a final `stop` or the loop cap is reached.
   - Tool execution must not depend on xAI Search API endpoints (e.g., `/v1/search/*`), since those may be unavailable depending on xAI account entitlements.
   - Tool execution must use Grok itself ("inner call") on `POST /v1/chat/completions` to obtain live web/news results.
     - Use an agentic inner prompt that asks Grok to "perform a real-time web search" and return strict JSON.
   - Opt-in model alias (for Continue UX):
     - Continue can request `grok-4-with-live-search`.
     - SmartProxy routes upstream as `grok-4` but only enables/injects live-search tools when this alias is used **and** `SMART_PROXY_ENABLE_WEB_TOOLS=true`.
3) **Loop / Cap**
   - SmartProxy must cap any retry/iteration logic used to satisfy a live-search request.
   - Default cap uses `SMART_PROXY_MAX_LOOPS` (even if the implementation no longer uses OpenAI tool-calls).
4) **Deprecation resilience**
   - Implement only the agentic approach (tool calling + inner Grok call). No legacy fallback strategy.
   - Keep live-search tool execution isolated in one place (single adapter/function) so future xAI payload changes can be made with minimal blast radius.
   - Support basic configuration knobs (agentic-only):
     - `SMART_PROXY_LIVE_SEARCH_MAX_RESULTS=3`
     - `SMART_PROXY_LIVE_SEARCH_SOURCES=web,news` (comma-separated; used only for the inner prompt contract)
5) **Observability**
   - Log live-search enablement and tool execution events:
     - `live_search_enabled` (include `session_id`, requested model, upstream model)
     - `tool_request_received` / `tool_response_sent` (include `session_id`, tool name, anonymized args, abbreviated result)
     - `live_search_search_call_made` (include `session_id`, anonymized params)
6) **Safety**
   - Ensure live search cannot be invoked when tools are disabled.
   - Ensure any logged search query / params are anonymized/sanitized similarly to chat payload.

**Architectural Context**: Continue expects a plain chat completion response. Live search must be entirely inside SmartProxy request shaping and upstream Grok behavior: the editor never sees any intermediate artifacts.

**Acceptance Criteria**:
- With `SMART_PROXY_ENABLE_WEB_TOOLS=false`, Grok chat works but live search is not enabled.
- With `SMART_PROXY_ENABLE_WEB_TOOLS=true` and `model=grok-4-with-live-search`, a prompt asking for fresh information results in:
  - Grok requesting `web_search` via `tool_calls`
  - SmartProxy executing it via an inner Grok call
  - Grok producing a final answer that reflects live search.
- Logs show live-search enablement and response correlation clearly.

**Operator Note (Model Selection)**:
- Any human or agent that requires live research must explicitly request a `grok-*-with-live-search` model alias.
- Requests to plain `grok-*` models must behave as “no live search” (even if the prompt asks for research), unless the alias is used and `SMART_PROXY_ENABLE_WEB_TOOLS=true`.

**Notes**:
- A working reference agentic flow exists in `grok_web_search_roundtrip.rb`:
  - tool call: `web_search`
  - tool execution implemented via an inner Grok call
- If `citations` are not returned (or are empty), SmartProxy should still treat the request as successful; citations support may vary by model/version.

**Test Cases**:
- Manual: run Continue with Grok model, ask for “latest” information; verify behavior with gate off vs on.
- Manual: verify cap works (`SMART_PROXY_MAX_LOOPS`) if any retries are implemented.

**Workflow**: Implement in SmartProxy request shaping for Grok; validate with Continue.

**Context Used**:
- `smart_proxy/app.rb` (tool endpoints and orchestration hooks)
- `grok_web_search_roundtrip.rb` (known-good `search_parameters` payload)
