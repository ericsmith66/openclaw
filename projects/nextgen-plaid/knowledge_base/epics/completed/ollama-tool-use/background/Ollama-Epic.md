--- Note this is the orriginal PRD for support in tools use for ollama. bellow this PRD has been brooken down out into en epic with multiple prds. please review the epic and prd and make sure the requirements are conssitant and complete ask quesitons and propose solutions. as necessary.


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

--- End 




Here is the full, detailed **Epic Narrative** for the SmartProxy refactor, including objectives, approach, end-state capabilities, and the complete list of atomic PRDs with expanded descriptions.

### Epic Narrative: Refactor SmartProxy Ollama Interface for Tool Support and Cross-LLM Interoperability

**Vision Context**  
SmartProxy acts as the thin, local HTTP wrapper between the Rails application (AiFinancialAdvisor service) and the on-premises Ollama instance (Llama 3.1 70B/405B). Currently it supports basic chat completions but breaks when mixing LLM providers in workflows (e.g., Claude generates a PRD with tool calls, Grok reviews it, then Ollama executes simulation steps). The spike revealed a critical incompatibility: Grok/OpenAI-style tool_calls[].function.arguments arrive as JSON strings, while Ollama /api/chat expects JSON objects → resulting in HTTP 400 "cannot unmarshal string into …".  
This epic makes SmartProxy robust for tool use and provider interoperability, enabling reliable end-to-end runs of scripts like run_agent_test_sdlc_e2e.sh with mixed LLMs (Claude for structured PRD generation, Grok for reasoning, Ollama for local simulation/execution), all while staying fully on-premises.

**Objectives**
- Eliminate 400 errors in mixed-provider conversation histories by normalizing tool call arguments.
- Enable forwarding of OpenAI-compatible tools to Ollama (when supported by the model).
- Parse Ollama tool call responses back into OpenAI-compatible format for downstream consumers.
- Add strict validation, gating, logging, and error handling for production reliability.
- Ensure full E2E script success when switching providers mid-workflow.

**Approach**
- Start with normalization (PRD-00) to immediately fix the spike failure.
- Progress to tool acceptance/validation → forwarding → parsing → restrictions (streaming) → logging → tests → Rails client integration.
- Implementation in `smart_proxy/lib/ollama_client.rb` (core logic) and `smart_proxy/app.rb` (Sinatra endpoints).
- Minimal changes to Rails caller `app/services/agent_hub/smart_proxy_client.rb`.
- Use RSpec for unit/integration tests; focus on regression coverage for mixed histories.
- Environment flag `OLLAMA_TOOLS_ENABLED` for safe rollout.
- Junie to use Claude Sonnet 4.5 (default) in RubyMine; switch to Grok 4.1 if complex prompt engineering or tool schema reasoning is needed during test writing.

**End-State Capabilities**
- SmartProxy accepts and normalizes Grok/Claude/OpenAI-style histories with stringified tool arguments → calls Ollama successfully.
- Validates and forwards tools (max 20) to Ollama /api/chat when enabled.
- Returns parsed tool_calls in OpenAI format (with generated IDs) from Ollama responses.
- Rejects streaming + tools combinations with clear 400 error.
- Comprehensive debug logs for troubleshooting.
- E2E script (run_agent_test_sdlc_e2e.sh) runs cleanly with mixed providers (e.g., Claude → Grok → Ollama).
- No cloud calls; all local; secure for HNW financial simulations.

**Atomic PRDs**

| PRD ID                  | Title                                              | Detailed Description / Scope                                                                 |
|-------------------------|----------------------------------------------------|-----------------------------------------------------------------------------------------------|
| PRD-AH-OLLAMA-TOOL-00   | Conversation History Normalization                 | Add helper method in ollama_client.rb that walks inbound messages, finds any tool_calls[].function.arguments that are strings, attempts JSON.parse, replaces with Hash if successful (or {} on failure). Apply before every Ollama /api/chat call. Include regression spec reproducing the exact 400 error from spike. Log count of normalized tool calls. |
| PRD-AH-OLLAMA-TOOL-01   | Tool Acceptance and Validation                     | Update /v1/chat/completions endpoint to accept optional `tools` array (OpenAI format: type:"function", function.name, function.parameters as object). Validate strictly: max 20 tools, required fields present, raise ArgumentError with detailed path (e.g. "tools[3].function.name missing"). Return HTTP 400 JSON error with path-specific messages. |
| PRD-AH-OLLAMA-TOOL-02   | Gated Tool Forwarding to Ollama                    | Add env flag OLLAMA_TOOLS_ENABLED (default true). If true and tools present + valid, include `tools:` key in payload to Ollama /api/chat. If false, silently drop tools and proceed with content-only chat. Log whether tools were forwarded or dropped. |
| PRD-AH-OLLAMA-TOOL-03   | Parse Ollama Tool Calls to OpenAI Format           | In response handling: if response.message.tool_calls exists, map each to OpenAI style: generate id ("call_" + SecureRandom.hex(6)), type:"function", name from tool_calls[].function.name, arguments: parse JSON string → Hash (lenient: on parse fail insert {error: "invalid JSON", raw: original, parse_error: $!}). Return in choices[0].message.tool_calls array. |
| PRD-AH-OLLAMA-TOOL-04   | Streaming and Error Handling for Tools             | When stream: true and tools present (or tool_calls requested), return HTTP 400 early with JSON {"error": "Tool calls require non-streaming mode"} before calling Ollama. Add test coverage for this rejection. |
| PRD-AH-OLLAMA-TOOL-05   | Logging Enhancements for Tool Interactions         | Add debug-level logs (using Logger) for: inbound normalization count, tool schema validation result, tools forwarded count + names, parsed tool_calls count + names, argument parse failures, any dropped tools due to flag. Align with junie-log-requirement.md format. |
| PRD-AH-OLLAMA-TOOL-06   | Unit/Integration Tests and Acceptance Criteria     | Add RSpec suite in smart_proxy/spec: unit tests for normalization (string → Hash, bad JSON → {}), validation (good/invalid schemas), forwarding (payload includes tools when enabled), parsing (good/bad args), streaming rejection. Integration tests for full /v1/chat/completions round-trip. Include AC for mixed-provider history success (Grok-style → Ollama). |
| PRD-AH-OLLAMA-TOOL-07   | Rails Client Integration and E2E Workflow Support  | Minor updates to app/services/agent_hub/smart_proxy_client.rb to pass histories/tools correctly. Verify run_agent_test_sdlc_e2e.sh runs end-to-end with mixed providers (e.g., set env vars or config to switch between Claude/Grok/Ollama mid-script). Add README note on usage. |

**Execution Order Recommendation**  
0 → 1 → 2 → 3 → 4 → 5 → 6 → 7  
(Start with normalization to unblock E2E immediately, end with integration to prove full workflow.)

Next step:  
Do you want me to generate the rake agent:test_sdlc command lines for these 8 PRDs (≤100 words input each)? Or first ask Junie to review this epic narrative?


Here is the **detailed Epic Narrative** for the **Refactor SmartProxy Ollama Interface for Tool Support and Cross-LLM Interoperability**, including the full objectives, approach, end-state capabilities, and all atomic PRDs with expanded scope, requirements, architectural notes, and rationale tied to the repo and spike learnings.

### Epic Narrative: Refactor SmartProxy Ollama Interface for Tool Support and Cross-LLM Interoperability

**Vision Context**  
SmartProxy (in `smart_proxy/` directory) serves as the local, OpenAI-compatible thin layer between the Rails app (AiFinancialAdvisor service) and on-premises Ollama (Llama 3.1 70B/405B). It enables the financial education AI to call tools (e.g., Python simulators for Monte Carlo/GRAT/estate-tax) while staying fully local and private.  
The spike revealed a blocking interoperability issue: Grok/Claude/OpenAI-style `tool_calls[].function.arguments` arrive as JSON **strings** in conversation history, but Ollama `/api/chat` strictly expects JSON **objects** → causing HTTP 400 "cannot unmarshal string into …".  
This epic fixes that normalization gap, adds safe tool forwarding, parsing, validation, and gating, so E2E workflows (e.g., run_agent_test_sdlc_e2e.sh) can mix providers: Claude for structured PRD generation, Grok for reasoning/review, Ollama for local execution/simulation — all without format errors or cloud leakage.

**Objectives**
- Prevent 400 errors in mixed-provider histories via automatic normalization of tool call arguments.
- Safely forward OpenAI-style tools to Ollama when the model supports them.
- Parse Ollama tool call responses back into consistent OpenAI format for Rails/AiFinancialAdvisor.
- Enforce validation, env gating, streaming restrictions, and detailed logging.
- Enable seamless E2E script runs with provider switching mid-flow.

**Approach**
- Atomic progression: Fix normalization first (unblocks spike failure), then validation/forwarding, parsing, restrictions, logging, tests, and Rails integration.
- Core changes in `smart_proxy/lib/ollama_client.rb` (normalization helpers, payload building, response parsing).
- Endpoint updates in `smart_proxy/app.rb` (Sinatra: /v1/chat/completions).
- Minimal Rails-side tweaks in `app/services/agent_hub/smart_proxy_client.rb` (history/tool passing).
- Use RSpec in `smart_proxy/spec/` for coverage.
- Env flag `OLLAMA_TOOLS_ENABLED` for controlled rollout.
- Junie: Use **Claude Sonnet 4.5** (default) in RubyMine for Ruby/Sinatra work; switch to **Grok 4.1** if needed for tool schema reasoning or complex test prompt design.
- Local-only; no cloud LLM calls.

**End-State Capabilities**
- Mixed histories (Grok → Claude → Ollama) pass without 400.
- Tools validated (max 20, schema checked) and forwarded to Ollama if enabled.
- Ollama tool_calls returned as OpenAI-compatible array with IDs and parsed args (lenient on bad JSON).
- Streaming rejected when tools present (clear error).
- Logs capture every key event (normalization, validation, forwarding, parsing failures).
- run_agent_test_sdlc_e2e.sh succeeds with mixed providers (e.g., Claude generates PRD → Grok reviews → Ollama simulates).
- Full regression coverage for edge cases.

**Atomic PRDs**

1. **PRD-AH-OLLAMA-TOOL-00: Conversation History Normalization**  
   **Overview**: Prerequisite fix for spike failure — normalize inbound conversation history so Ollama receives tool call arguments as JSON objects instead of strings.  
   **Requirements**
    - Functional: In `ollama_client.rb`, add `normalize_tool_arguments(messages)` helper. Walk every message; for each tool_call in tool_calls array: if function.arguments is String, JSON.parse it → replace with Hash if successful, or {} on failure/parse error. Apply before building Ollama payload.
    - Non-functional: Log count of normalized calls (debug level). Performance: O(n) on message count.
    - Architectural: Called early in chat handling flow. Aligns with local-only rule; no external deps.  
      **Acceptance Criteria**
    - Grok-style history with string args → Ollama payload has Hash.
    - Bad JSON → {} with log.
    - No tool_calls → unchanged.
    - Regression spec reproduces 400 error and shows fix.  
      **Test Cases**
    - Unit: spec for helper with string/Hash/bad JSON inputs.
    - Integration: Mock Ollama response; assert payload sent correctly.

2. **PRD-AH-OLLAMA-TOOL-01: Tool Acceptance and Validation**  
   **Overview**: Make /v1/chat/completions accept and strictly validate OpenAI tools schema before any forwarding.  
   **Requirements**
    - Functional: Accept optional `tools` array in request body. Validate: type=="function", function.name present/non-empty, function.parameters object, max 20 tools. Raise ArgumentError with path (e.g. "tools[2].function.name missing"). Return HTTP 400 JSON {error: "...", details: {...}}.
    - Non-functional: Validation <10ms.  
      **Acceptance Criteria**
    - Valid tools → proceed.
    - Invalid/missing fields → 400 with path error.
    - >20 tools → 400.  
      **Test Cases**
    - Unit: Validation helper specs (good/invalid).
    - Integration: Sinatra endpoint tests (200 vs 400).

3. **PRD-AH-OLLAMA-TOOL-02: Gated Tool Forwarding to Ollama**  
   **Overview**: Conditionally include validated tools in Ollama /api/chat payload based on env flag.  
   **Requirements**
    - Functional: Check `ENV["OLLAMA_TOOLS_ENABLED"]` (default "true"). If true + tools valid → add `tools:` to payload. If false → drop tools silently. Log action (forwarded/dropped + count).
    - Architectural: In ollama_client.rb payload builder.  
      **Acceptance Criteria**
    - Flag true → tools in payload.
    - Flag false → no tools, content-only.
    - Log entry for both cases.  
      **Test Cases**
    - Unit: Payload builder with/without flag.
    - Mock HTTP call asserts correct JSON.

4. **PRD-AH-OLLAMA-TOOL-03: Parse Ollama Tool Calls to OpenAI Format**  
   **Overview**: Convert Ollama response.message.tool_calls to OpenAI-compatible tool_calls array.  
   **Requirements**
    - Functional: For each tool_call: id = "call_" + hex(6), type="function", name from function.name, arguments = JSON.parse(string) → Hash (lenient: on fail {error: "invalid JSON", raw: original, parse_error: msg}). Return in choices[0].message.tool_calls.
    - Log parse failures.  
      **Acceptance Criteria**
    - Good args → Hash in output.
    - Bad args → error object in args.
    - No tool_calls → nil array.  
      **Test Cases**
    - Unit: Parsing helper specs (good/bad JSON).

5. **PRD-AH-OLLAMA-TOOL-04: Streaming and Error Handling for Tools**  
   **Overview**: Prevent tool calls in streaming mode (Ollama limitation).  
   **Requirements**
    - Functional: If stream:true and tools/tool_calls requested → return 400 early {"error": "Tool calls require non-streaming mode"} before Ollama call.  
      **Acceptance Criteria**
    - Streaming + tools → 400.
    - Streaming no tools → proceed.  
      **Test Cases**
    - Integration: Endpoint rejects correctly.

6. **PRD-AH-OLLAMA-TOOL-05: Logging Enhancements for Tool Interactions**  
   **Overview**: Comprehensive debug logging for all tool-related events.  
   **Requirements**
    - Functional: Log normalization count, validation result, forwarded/dropped count + tool names, parsed tool_calls count/names, parse failures. Follow junie-log-requirement.md format.  
      **Acceptance Criteria**
    - Logs visible in development/production for each flow.  
      **Test Cases**
    - Mock Logger; assert log calls.

7. **PRD-AH-OLLAMA-TOOL-06: Unit/Integration Tests and Acceptance Criteria**  
   **Overview**: Full test coverage for the refactor.  
   **Requirements**
    - Functional: Specs in smart_proxy/spec for normalization, validation, forwarding, parsing, streaming rejection, mixed-history AC (Grok-style → Ollama success).  
      **Acceptance Criteria**
    - 90%+ coverage on new code.
    - Regression suite passes.  
      **Test Cases**
    - Unit + integration as above.

8. **PRD-AH-OLLAMA-TOOL-07: Rails Client Integration and E2E Workflow Support**  
   **Overview**: Ensure Rails caller works with new features; validate full E2E.  
   **Requirements**
    - Functional: Minor tweaks to smart_proxy_client.rb for history/tools. Test run_agent_test_sdlc_e2e.sh with mixed providers. Add README notes.  
      **Acceptance Criteria**
    - E2E script succeeds with Claude → Grok → Ollama flow.  
      **Test Cases**
    - Manual E2E run; optional script assertions.

Next steps:  
Ready for rake agent:test_sdlc inputs for these PRDs? Or want Junie to review this epic first and provide estimates/questions?