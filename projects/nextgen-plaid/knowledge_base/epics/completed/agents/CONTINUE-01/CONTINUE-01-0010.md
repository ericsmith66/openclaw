### PRD 0010: Continue Compatibility Baseline (auth + OpenAI shapes + diagnostics)

**Overview**: Ensure SmartProxy behaves as a dependable OpenAI-compatible endpoint for Continue (RubyMine) at minimum: authentication, correct response shapes for `POST /v1/chat/completions`, and useful error messages/logging so editor-side failures are debuggable.

**Requirements**:
1) **Auth Compatibility**
   - Continue sends `Authorization: Bearer <token>`.
   - SmartProxy rejects invalid tokens with a clear OpenAI-shaped error payload.
2) **OpenAI Response Shape (Non-Streaming)**
   - `/v1/chat/completions` always returns:
     - `choices[0].message.content`
     - `usage` (even if token counts are 0)
   - If `model` is missing/blank → return 400 with an OpenAI-ish error structure.
3) **Diagnostics / Observability**
   - Log `chat_completions_request_received` and `chat_completions_response_received` with a stable `session_id`.
   - Log routing decision as `route: "grok"|"ollama"`.
4) **Compatibility Guardrails**
   - Ignore unknown fields without crashing.
   - If upstream fails, return an OpenAI-shaped error response.

**Architectural Context**: Continue (RubyMine) behaves like an OpenAI client: it will call `GET /v1/models` and `POST /v1/chat/completions`. SmartProxy should be treated as a contract surface: stable payload handling, stable errors, and logs suitable for correlation.

**Acceptance Criteria**:
- Continue can connect (no auth loop / no 401 when configured correctly).
- Sending a chat message returns a response Continue can display.
- Invalid request gets a readable 4xx response (especially missing `model`).
- `log/smart_proxy.log` contains enough data to correlate an editor error to a proxy request and response.

**Test Cases**:
- Manual: configure Continue base URL + token; send a short message.
- Manual: omit token → verify 401 with OpenAI-shaped error.
- Manual: send request missing `model` → verify 400 “model is required” with OpenAI-ish error payload.

**Workflow**: Implement minimal changes in SmartProxy only; validate using Continue + log correlation.

**Context Used**:
- `smart_proxy/app.rb` (auth, `/v1/chat/completions` logging and response shaping)
- `log/smart_proxy.log` (correlation and debugging)
