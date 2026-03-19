### Modified PRD (aligned to what we learned/changed during this spike)

#### PRD-AH-OLLAMA-TOOL-01 (Revised): SmartProxy Ollama Tool Calling + Conversation Compatibility
**Version**: 1.1a (Adjusted to incorporate spike learnings)

### 0) Why this PRD needs adjustment
During the SDLC E2E work we hit a concrete interoperability issue when mixing providers/models in one workflow:
- Grok/OpenAI-style assistant messages can include `tool_calls[].function.arguments` as a **JSON string**.
- Ollama `/api/chat` expects `tool_calls[].function.arguments` as a **JSON object**.
- Without normalization, Ollama returns HTTP 400:
  `cannot unmarshal string into ... tool_calls.function.arguments`

So this PRD must include a **prerequisite normalization layer** even before “native tool forwarding” is implemented.

### 1) Scope (what to build)
Enhance SmartProxy’s Ollama adapter so it can:
1) **Forward OpenAI-style `tools`** to Ollama `/api/chat` when enabled.
2) **Parse Ollama `message.tool_calls`** into OpenAI-style `tool_calls`.
3) **Normalize conversation history** to avoid cross-provider incompatibilities:
    - Coerce `messages[].tool_calls[].function.arguments` from JSON string → object for Ollama.

### 2) File locations (as implemented in this repo)
- Primary implementation: `smart_proxy/lib/ollama_client.rb`
- SmartProxy HTTP surface: `smart_proxy/app.rb` (Sinatra)
- Rails caller (if present/needed): `app/services/agent_hub/smart_proxy_client.rb` (as you specified)

### 3) Functional requirements (revised)
#### FR0 (NEW, prerequisite): Normalize inbound messages for Ollama
Before calling Ollama `/api/chat`:
- If any message contains `tool_calls`, then for each tool call:
    - If `tool_call.function.arguments` is a String:
        - attempt `JSON.parse` → if Hash, replace
        - if parse fails or not a Hash, replace with `{}`
- This normalization happens regardless of whether `tools` forwarding is enabled.

#### Implement FR0 first (normalization)
- Add normalization helper in `smart_proxy/lib/ollama_client.rb` that converts stringified `tool_calls.function.arguments` into Hash.
- Add a regression spec for this (this is the exact failure we hit in E2E).

#### FR1: Accept optional `tools` array in SmartProxy `/v1/chat/completions`
- Accept OpenAI-compatible `tools`:
    - Each tool must have `type == "function"`
    - `function.name` non-empty
    - `function.parameters` is an object

#### FR2: Validate tools schema (strict) before forwarding
- Enforce max 20 tools
- Raise `ArgumentError` with path-specific errors (e.g. `tools[2].function.name is missing`)
- SmartProxy should return HTTP 400 with JSON error body.

#### FR3: Gate forwarding behind env
- `OLLAMA_TOOLS_ENABLED` default `true`
- If disabled, drop tools and do content-only behavior.

#### FR4: Forward validated tools to Ollama payload
- Include `tools:` in the JSON payload to `/api/chat`.

#### FR5: Parse tool calls from Ollama response
- Parse `response.message.tool_calls` when present.
- Normalize to OpenAI-style `tool_calls`:
    - generate `id: "call_<hex>"`
    - `type: "function"`
    - parse `arguments` if string; if parse fails, insert error object (lenient)

#### FR6: Streaming + tools behavior
- If `stream: true` and `tools` present:
    - return HTTP 400: `{"error":"Tool calls require non-streaming mode"}`

### 4) Logging requirements (same intent, aligned to spike reality)
- Add debug logs in SmartProxy for:
    - tool schema validation results
    - tools forwarded count
    - parsed tool_calls count + names
    - argument parse failures
    - inbound-message normalization performed (count of tool_calls normalized)

### 5) Acceptance criteria additions (delta)
Add these to your AC list:
- **AC0 (NEW)**: Mixed-provider history works: SmartProxy accepts a Grok-style tool_call history and successfully calls Ollama without 400.

### 6) Tests (adjusted to match what we already learned)
- Unit/spec for normalization:
    - given `messages[].tool_calls[].function.arguments` as JSON string → Ollama receives Hash
- Unit/spec for tool forwarding:
    - valid tools included in Ollama payload
    - invalid tools schema returns 400 with path error
- Unit/spec for tool_calls parsing:
    - good JSON args → Hash
    - bad JSON args → `{ error:, raw:, parse_error: }`

---




