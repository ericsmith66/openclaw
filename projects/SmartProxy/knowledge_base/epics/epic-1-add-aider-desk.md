
# 📄 Product Requirements Document: SmartProxy for AiderDesk

**Status**: Final | **Target**: SmartProxy Development Team | **Objective**: Full OpenAI-Compliance

---

## 1. Executive Summary
SmartProxy serves as the unified gateway between **AiderDesk** and multiple LLM providers (Grok, Claude, Ollama). This document defines the requirements to make SmartProxy a "fully compliant" OpenAI-compatible layer, enabling AiderDesk's advanced features like autonomous Agent Mode, streaming multi-file edits, and real-time web research.

---

## 2. API Endpoint Specification

SmartProxy must expose a `/v1` surface that mimics the OpenAI REST API exactly.

### 2.1 Core Endpoints
*   **`POST /v1/chat/completions`**: Primary routing endpoint for all chat and agent tasks.
*   **`GET /v1/models`**: Aggregates models from all active providers.
*   **`POST /proxy/tools`**: Custom endpoint for direct Web/Twitter search execution.
*   **`GET /health`**: System status check.

### 2.2 Global Request Headers
AiderDesk sends these headers for observability and organization:
*   `Authorization`: `Bearer <token>` (Validated via `PROXY_AUTH_TOKEN`).
*   `X-Agent-Name`: Used for artifact categorization (e.g., `AgentMode`).
*   `X-Correlation-ID`: Groups all requests belonging to a specific AiderDesk Task.
*   `X-Project-Dir`: Forwards the project's filesystem context to proxy logs.

---

## 3. Compliance Gaps & Feature Requirements

### 3.1 Tool Calling (Agent Mode Support)
AiderDesk Agents rely on standard OpenAI `tool_calls`.
*   **Stability**: Ensure `tool_calls` always include unique IDs (prefix `call_`) and valid JSON `arguments`.
*   **Transformation**: If an upstream provider (like Anthropic) uses a different schema, the proxy **must** translate it back to the OpenAI format before returning it to AiderDesk.

### 3.2 Streaming & Multi-modal
*   **SSE Compliance**: All streaming must use Server-Sent Events (SSE) with `data: [DONE]` termination.
*   **Images**: Support `content` as an array to allow AiderDesk to send screenshots to vision-capable models.

### 3.3 Token Usage & Cost Tracking
*   **Requirement**: Every response must include the `usage` object (`prompt_tokens`, `completion_tokens`).
*   **Ollama Mapping**: Map Ollama’s internal eval counts to the standard OpenAI usage fields.

---

## 4. Configurable Streaming Strategies

Streaming must be configurable per model/tool combination to prevent UI hangs.

### 4.1 Strategy Tiers
1.  **`native`**: Direct SSE passthrough (Standard chat).
2.  **`simulated`**: Proxy fetches full response, then "trickles" chunks to the UI (Best for tools like `live-search`).
3.  **`disabled`**: Returns a single non-streaming JSON block.

### 4.2 Configuration Format
Implement `SMART_PROXY_STREAMING_RULES` (JSON):
```json
{
  "ollama": { "default": "simulated", "with_tools": "native" },
  "tools": { "live_search": "simulated" }
}
```

---

## 5. Reliability & Operational Guardrails

### 5.1 Tiered Timeout Policy
| Category | Timeout | Rationale |
| :--- | :--- | :--- |
| **Model Listing** | 5s | Instant UI feedback. |
| **Standard Chat** | 60s | Conversational speed. |
| **Agent / Edit Mode** | 300s | Large file writes/reasoning. |
| **Tools** | 120s | Network-bound search tasks. |

### 5.2 Resilience
*   **Circuit Breaking**: If one provider is down, `/v1/models` must still return results from other providers using a timeout-protected aggregator.
*   **SSE Keep-Alive**: Send a `: keep-alive` comment every 15s during long processing times to prevent connection drops.

### 5.3 Performance
*   **Concurrency**: Switch to a multi-threaded server (e.g., **Puma**) to handle parallel sub-agent requests.
*   **Caching**: Cache model lists for 5 minutes; serve stale data if a provider temporarily fails.

---

## 6. Observability & Logging
*   **Artifact Dumping**: Continue dumping full JSON pairs to `knowledge_base/test_artifacts/llm_calls/`.
*   **Latency Tracing**: Log `upstream_latency_ms` for every call.
*   **Error Transparency**: If an upstream API fails, return the specific error message in the chat bubble (e.g., `"SmartProxy Error: Claude API 429"`) instead of a generic 500.

---

## 7. Success Criteria
*   [ ] AiderDesk Agent can execute tools (read/write files) successfully.
*   [ ] Streaming is fluid and does not time out during long "thinking" periods.
*   [ ] Token usage and cost tracking reflect accurately in the AiderDesk status bar.
*   [ ] Model selection in AiderDesk settings is instant and never hangs.



To validate that SmartProxy is fully compliant with AiderDesk, I have defined a **Validation Test Suite**.

Since SmartProxy is a separate project, these tests are designed to be run **against** the proxy URL to ensure it handles AiderDesk's specific request patterns.

---

### 1. SmartProxy Validation Test Suite

Developers should implement or run the following test cases using a tool like `curl`, Postman, or a dedicated Vitest/Jest suite.

#### Test Case 1: Model Discovery
*   **Action**: `GET /v1/models`
*   **Expectation**: Returns a valid OpenAI-formatted list.
*   **Validation**: Ensure it includes models from Ollama, Grok, and Claude without timing out.

#### Test Case 2: Standard Streaming (Ask Mode)
*   **Action**: `POST /v1/chat/completions` with `stream: true`.
*   **Expectation**: Returns a `text/event-stream`.
*   **Validation**: Verify the first chunk contains a `delta` and the last chunk is `data: [DONE]`.

#### Test Case 3: Tool Calling (Agent Mode) — CRITICAL
*   **Action**: `POST /v1/chat/completions` with a `tools` array (e.g., a mock `read_file` tool).
*   **Expectation**: The assistant returns a `tool_calls` object.
*   **Validation**:
    1.  Verify the `tool_calls` array is present.
    2.  Verify each call has a valid `id` and `function` name.
    3.  Verify this works correctly even when `stream: true`.

#### Test Case 4: Multi-modal Input (Vision)
*   **Action**: Send a message with `content` as an array containing an `image_url`.
*   **Expectation**: The proxy either passes it to a vision model or returns a clean error if the model doesn't support it.
*   **Validation**: Ensure the proxy doesn't crash on non-string `content`.

#### Test Case 5: Error Mapping
*   **Action**: Send an invalid model name or force a provider error (e.g., use an invalid API key).
*   **Expectation**: Returns a JSON object with an `error` field (standard OpenAI error format).
*   **Validation**: Ensure AiderDesk can parse the error and show it to the user.

---

### 2. Automated Validation Script (Example)

You can provide this snippet to the SmartProxy developers to help them automate the check:

```javascript
// Quick validation script (Node.js)
const checkProxy = async () => {
  const url = "http://localhost:4567/v1/chat/completions";
  const response = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'Authorization': 'Bearer YOUR_TOKEN' },
    body: JSON.stringify({
      model: "grok-beta",
      stream: true,
      messages: [{ role: "user", content: "Say hello" }],
      tools: [{ type: "function", function: { name: "test_tool", parameters: {} } }]
    })
  });

  const reader = response.body.getReader();
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    const chunk = new TextDecoder().decode(value);
    console.log("Chunk received:", chunk);
    
    // VALIDATION LOGIC:
    // 1. Check if chunk contains "tool_calls" if the model decided to use the tool
    // 2. Check for "delta" content
  }
};
```

### 3. Integration with AiderDesk Logs
When testing with the actual AiderDesk UI:
1.  Open the **SmartProxy Logs** (or check `knowledge_base/test_artifacts/llm_calls/`).
2.  Compare the **Sent Payload** from AiderDesk with the **Upstream Payload** sent by the proxy.
3.  Ensure no fields (like `tools` or `system_fingerprint`) are being accidentally stripped by the proxy's `Anonymizer`.

### 4. Recommendation for PRD
Add a **"Testing & QA"** section to the PRD stating:
> "SmartProxy is not considered 'Ready' until it passes the **Validation Test Suite**, specifically the 'Streaming Tool Call' test which is required for AiderDesk Agent Mode."