# 📄 Product Requirements Document: Add DeepSeek AI Provider to SmartProxy

**Status**: Draft | **Target**: SmartProxy Development Team | **Objective**: Integrate DeepSeek as a new AI provider

---

## 1. Executive Summary
SmartProxy currently supports Grok, Claude, and Ollama as LLM providers. This document defines the requirements to add DeepSeek as a new provider, enabling AiderDesk and other clients to leverage DeepSeek's models through the same OpenAI-compatible proxy layer.

DeepSeek provides an OpenAI-compatible API endpoint, making integration straightforward. The integration must follow existing patterns for provider detection, model listing, and request routing.

---

## 2. Integration Requirements

### 2.1 Provider Detection
- Model names starting with `deepseek` (case-insensitive) should route to DeepSeek provider.
- Environment variable `DEEPSEEK_API_KEY` must be present; otherwise, DeepSeek models are omitted.
- Environment variable `DEEPSEEK_MODELS` (optional) defines a comma-separated list of model IDs to expose (default: `deepseek-chat,deepseek-coder`).

### 2.2 Client Implementation
- Create `DeepSeekClient` class in `lib/deepseek_client.rb`.
- Follow the pattern of `GrokClient` (OpenAI-compatible API).
- Base URL: `https://api.deepseek.com/v1`.
- Support both `chat_completions` method (for tool orchestration) and `chat` method (for compatibility).
- Include timeout configuration via `DEEPSEEK_TIMEOUT` environment variable (default 120 seconds).
- Implement error handling consistent with other clients.

### 2.3 Model Listing
- Extend `ModelAggregator` with `list_deepseek_models` method.
- If `DEEPSEEK_API_KEY` is missing, return empty array.
- Parse `DEEPSEEK_MODELS` environment variable or use default list.
- Each model entry must include required fields: `id`, `object`, `owned_by`, `created`, `smart_proxy.provider`.
- Optionally support `-with-live-search` suffix for tool-enabled variants (if DeepSeek supports tool calling).

### 2.4 Routing Updates
- Update `ModelRouter` to add `use_deepseek?` method.
- Add `:deepseek` provider symbol and corresponding client instantiation.
- Ensure routing logic prioritizes DeepSeek when model name matches.

### 2.5 Environment Configuration
- Update `.env.example` with DeepSeek variables.
- Document usage in README.md.

### 2.6 Testing
- Add unit tests for `DeepSeekClient`.
- Update `model_router_spec.rb` and `model_aggregator_spec.rb` to include DeepSeek scenarios.
- Ensure existing tests continue to pass.

---

## 3. Compliance & Compatibility

### 3.1 OpenAI Compatibility
DeepSeek's API is OpenAI-compatible, so minimal transformation is required. However, ensure:
- Response format matches OpenAI spec (including `tool_calls` if supported).
- Error mapping follows OpenAI error format.

### 3.2 Tool Calling Support
Investigate whether DeepSeek supports function/tool calling. If yes, ensure tool calls are properly passed through and transformed if needed. If not, consider whether to disable tools for DeepSeek models (similar to Ollama's tool gating).

### 3.3 Streaming
DeepSeek supports streaming. Ensure streaming responses are passed through correctly (SSE format).

---

## 4. Implementation Steps

1. **Review existing provider patterns** – Understand Grok/Claude/Ollama client implementations.
2. **Create DeepSeekClient class** – Implement API client with proper error handling and timeouts.
3. **Update ModelRouter** – Add DeepSeek detection and routing.
4. **Update ModelAggregator** – Add model listing for DeepSeek.
5. **Update environment configuration** – Add variables to `.env.example`.
6. **Update README.md** – Document DeepSeek support.
7. **Write tests** – Unit tests for new client and updated specs.
8. **Run full test suite** – Ensure no regressions.
9. **Integration testing** – Verify DeepSeek models appear in `/v1/models` and chat completions work.

---

## 5. Success Criteria

- [ ] DeepSeek models appear in `/v1/models` when `DEEPSEEK_API_KEY` is set.
- [ ] Chat completions requests with model `deepseek-chat` are routed to DeepSeek and return valid responses.
- [ ] Streaming works for DeepSeek models.
- [ ] Tool calling works if supported by DeepSeek (or gracefully disabled).
- [ ] Environment variables are documented.
- [ ] All existing tests pass.

---

## 6. Open Questions / Risks

- Does DeepSeek support tool calling? Need to verify API documentation.
- Are there any rate limits or special headers required?
- What is the exact base URL? Confirm via DeepSeek documentation.
- Does DeepSeek support `system` messages? (Assume yes, as OpenAI-compatible.)

---

## 7. References

- Existing providers: GrokClient, ClaudeClient, OllamaClient.
- ModelRouter and ModelAggregator current implementations.
- DeepSeek API documentation (to be consulted during implementation).

---

*Epic created by AiderDesk on 2025-02-16*