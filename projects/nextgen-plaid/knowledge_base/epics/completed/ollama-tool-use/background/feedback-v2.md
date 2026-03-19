# Ollama Tool Use Epic - Architectural Feedback (v2)

This document provides comprehensive architectural review and answers to all
questions raised in feedback-v1.md.

---

## Executive Summary

SPIKE FINDING: During SDLC E2E work, Grok-generated tool_calls (string arguments)
caused HTTP 400 from Ollama (expects object arguments).

SOLUTION: Normalize in OllamaClient, validate early, gate with env flag, select
tool-optimized model, retry transient errors.

PATTERN: Mirror GrokClient (chat_completions method, full payload, Faraday retry).

EVIDENCE: SmartProxyClient needs no changes (test/smoke/smart_proxy_live_test.rb:63-82
proves tools already work).

---

## Questions from Feedback V1 - All Resolved

### Q1: Where should normalization happen?

ANSWER: In OllamaClient.normalize_tool_arguments_in_payload (private method)

RATIONALE:
- Ollama-specific problem (other providers don't need it)
- Provider clients own transformations (not orchestrator)
- GrokClient pattern: transformations in client
- Keeps ToolOrchestrator provider-agnostic

CODE LOCATION: smart_proxy/lib/ollama_client.rb, line 68-108

---

### Q2: How should the full tools payload flow through the system?

ANSWER: Full passthrough from Rails -> SmartProxy -> OllamaClient -> Ollama

FLOW:
1. Rails: SmartProxyClient serializes full payload (already works)
2. SmartProxy: app.rb forwards to ToolOrchestrator
3. ToolOrchestrator: Calls client.chat_completions(payload) - full payload
4. OllamaClient: Normalizes, validates, gates, forwards to Ollama
5. Response: Parsed by OllamaClient, transformed by ResponseTransformer

NO CHANGES NEEDED:
- SmartProxyClient (already passes tools)
- ToolOrchestrator (already checks respond_to?(:chat_completions))

CHANGES NEEDED:
- OllamaClient: Rename chat -> chat_completions, accept full payload
- ResponseTransformer: Include tool_calls in ollama_to_openai

PATTERN MATCH: Exactly like GrokClient.chat_completions

---

### Q3: Should gating logic happen before or after validation?

ANSWER: Always validate first (fail fast), then check gate

RATIONALE:
- Invalid tools should fail immediately with clear error
- Don't waste compute on invalid schemas
- Gate check is cheap (ENV lookup)
- User gets actionable error before gate drops tools silently

ORDER:
1. validate_tools_schema!(tools) - raises ArgumentError on invalid
2. Check ENV['OLLAMA_TOOLS_ENABLED']
3. If false: log and return nil (drop tools)
4. If true: log and return tools (forward)

CODE LOCATION: smart_proxy/lib/ollama_client.rb, line 110-139

---

### Q4: Does SmartProxyClient need changes?

ANSWER: NO CHANGES REQUIRED

EVIDENCE: test/smoke/smart_proxy_live_test.rb:63-82 already passes tools array
to Ollama endpoint and receives proper response.

EXISTING CODE:
```ruby
def test_chat_completions_ollama_style_with_tools_returns_choices_and_usage
  res = http_post_json("/v1/chat/completions", {
    model: ENV.fetch("OLLAMA_MODEL", "llama3.1:70b"),
    messages: [
      { role: "user", content: "List 3 colors" }
    ],
    tools: [
      {
        type: "function",
        function: {
          name: "get_current_weather",
          # ... full tool definition ...
        }
      }
    ]
  })
end
```

This test PASSES, proving SmartProxyClient already serializes tools correctly.

---

### Q5: Should we reject streaming + tools at the Sinatra boundary or in OllamaClient?

ANSWER: Reject in OllamaClient, catch in app.rb

RATIONALE:
- Ollama-specific limitation (other providers may support it)
- Provider clients own constraints
- app.rb catches ArgumentError and returns 400
- Clear separation of concerns

IMPLEMENTATION:
- OllamaClient: Raise ArgumentError if stream:true && tools present
- app.rb: Catch ArgumentError, check message, return HTTP 400

CODE LOCATIONS:
- smart_proxy/lib/ollama_client.rb, line 45-47 (raise)
- smart_proxy/app.rb, wrap orchestrate call (catch)

---

### Q6: Where should we parse tool_calls from Ollama responses?

ANSWER: In OllamaClient.parse_tool_calls_if_present (before returning)

RATIONALE:
- Provider-specific format needs provider-specific parsing
- OllamaClient returns normalized response to orchestrator
- ResponseTransformer expects consistent format
- Separation: OllamaClient does Ollama->internal, ResponseTransformer does internal->OpenAI

FLOW:
1. Ollama returns response with tool_calls
2. OllamaClient.parse_tool_calls_if_present converts to OpenAI format
3. Returns OpenStruct(status, body) to orchestrator
4. ResponseTransformer.ollama_to_openai includes tool_calls in choices[0].message

CODE LOCATIONS:
- smart_proxy/lib/ollama_client.rb, line 189-244 (parsing)
- smart_proxy/lib/response_transformer.rb, line 122-159 (transformation)

---

### Q7: Should we update artifact logging to include tool metadata?

ANSWER: YES - Add tools_count and tool_calls_count to dump_llm_call_artifact!

NEW FIELDS:
- tools_count: (request_payload['tools'] || []).length
- tool_calls_count: parsed_response.dig('choices', 0, 'message', 'tool_calls')&.length || 0

RATIONALE:
- Observability: Track tool usage across runs
- Debugging: Correlate tools sent vs tool_calls received
- Analytics: Understand tool adoption and success rates

CODE LOCATION: smart_proxy/app.rb, line 368 (dump_llm_call_artifact! method)

---

### Q8: Should we check if Ollama supports the requested model?

ANSWER: OUT OF SCOPE for this epic

RATIONALE:
- Ollama returns clear error if model not available
- Pre-checking adds complexity and latency
- Model list may change between check and request
- Better to rely on Ollama's error + retry logic
- Future enhancement: Cache model list and pre-validate

RECOMMENDATION: Document model requirements in README, rely on Ollama errors

---

### Q9: How should E2E tests handle tool execution?

ANSWER: Create new variant: run_agent_test_sdlc_ollama_tools_e2e.sh

REQUIREMENTS:
- Test mixed-provider workflow (Grok -> Ollama)
- Validate normalization, model selection, parsing
- Exit 0 on success, non-zero on failure
- Log all tool-related events

EXISTING TEST: script/run_agent_test_sdlc_e2e.sh
NEW TEST: script/run_agent_test_sdlc_ollama_tools_e2e.sh

CHANGES:
- Set ENV vars: OLLAMA_TOOLS_ENABLED=true, OLLAMA_TOOL_MODEL=llama3-groq-tool-use:70b
- Use Ollama for CWA phase (execution)
- Verify logs contain expected events

CODE LOCATION: script/run_agent_test_sdlc_ollama_tools_e2e.sh (new file)

---

### Q10: What should log format look like for tool events?

ANSWER: JSON structured logging following junie-log-requirement.md

FORMAT:
```json
{
  "timestamp": "2026-01-16T10:30:45Z",
  "severity": "DEBUG",
  "event": "tool_arguments_normalized",
  "count": 2,
  "provider": "ollama"
}
```

EVENTS TO LOG:
- tool_arguments_normalized (DEBUG)
- tools_validated (DEBUG)
- tools_forwarded (DEBUG)
- tools_dropped_disabled (INFO)
- model_selected_for_tools (DEBUG)
- tool_calls_parsed_from_ollama (DEBUG)
- tool_call_argument_parse_error (WARN)
- streaming_rejected_with_tools (WARN)
- tools_validation_failed (ERROR)

CODE LOCATION: Throughout smart_proxy/lib/ollama_client.rb

---

## Architecture Decisions

### AD1: Follow GrokClient Pattern

DECISION: OllamaClient.chat_completions matches GrokClient structure exactly

RATIONALE:
- Proven pattern (Grok works flawlessly)
- ToolOrchestrator already supports it
- Consistent interface across providers
- Easy to maintain and extend

IMPLEMENTATION:
```ruby
def chat_completions(payload)
  # Full payload passthrough
  # Provider-specific transformations
  # Faraday retry middleware
  # Return OpenStruct(status, body)
end
```

---

### AD2: Provider-Specific Transformations in Clients

DECISION: Normalization, validation, parsing all in OllamaClient (not orchestrator)

RATIONALE:
- Orchestrator stays provider-agnostic
- Each client owns its provider's quirks
- Easy to add new providers
- Clear separation of concerns

PATTERN:
- GrokClient: No special transformations (OpenAI-compatible)
- OllamaClient: Normalization + validation + parsing
- ClaudeClient: (Future) Claude-specific transformations

---

### AD3: Fail Fast with Clear Errors

DECISION: Validate tools schema before gating, raise ArgumentError with path-specific messages

RATIONALE:
- User gets actionable error immediately
- Don't waste compute on invalid requests
- Debugging is easier with specific errors
- Gate can silently drop tools (after validation)

EXAMPLE ERRORS:
- "tools[2].function.name is required"
- "tools[0].type must be 'function'"
- "maximum 20 tools allowed"

---

### AD4: Lenient Response Parsing

DECISION: On tool_call argument parse errors, insert error object (don't fail)

RATIONALE:
- Model may occasionally produce invalid JSON
- Better to mark as error than block entire response
- Orchestrator can decide how to handle
- User sees error in result, can retry

ERROR OBJECT:
```json
{
  "error": "invalid_json",
  "raw": "the bad json string",
  "parse_error": "unexpected token at..."
}
```

---

### AD5: Model Selection Strategy

DECISION: Use tool-optimized model when tools present and ENV configured

LOGIC:
1. If explicit model requested (not 'ollama' or nil): Use it
2. Else if tools present && ENV['OLLAMA_TOOL_MODEL']: Use tool model
3. Else: Use ENV['OLLAMA_MODEL'] or default llama3.1:70b

RATIONALE:
- Tool-optimized models have higher accuracy (90%+ BFCL)
- User can override with explicit model request
- Graceful fallback if tool model not configured
- Logged for observability

MODEL RECOMMENDATION: llama3-groq-tool-use:70b for tool calls

---

## Risk Mitigation

### Risk 1: Normalization breaks non-Ollama providers

MITIGATION: Normalization only in OllamaClient
VERIFICATION: Regression tests for Grok/Claude

### Risk 2: Tool-optimized model not available

MITIGATION: OLLAMA_TOOL_MODEL is optional, fallback to default
VERIFICATION: Model selection logs show fallback

### Risk 3: Performance impact

MITIGATION: O(n) normalization negligible for <50 messages
VERIFICATION: Profile with large histories, add timing logs

### Risk 4: Ollama API changes

MITIGATION: Lenient parsing, log warnings, version pinning
VERIFICATION: Track Ollama version in README

### Risk 5: Existing workflows break

MITIGATION: chat_completions coexists with old chat method
VERIFICATION: ToolOrchestrator checks respond_to?(:chat_completions)

---

## Implementation Phases

PHASE 1 (Days 1-2): OllamaClient refactor
- Normalization, validation, gating, model selection
- Faraday retry middleware
- Logging helpers
- Rename chat -> chat_completions

PHASE 2 (Days 3-4): Response parsing
- parse_tool_calls_if_present, parse_tool_call
- Update ResponseTransformer.ollama_to_openai
- Streaming + tools check

PHASE 3 (Day 5): App.rb integration
- ArgumentError catch
- Early validation
- Artifact logging update

PHASE 4 (Days 6-8): Testing
- Unit tests (OllamaClient)
- Integration tests (ResponseTransformer, app)
- Smoke tests (live Ollama)
- E2E script

PHASE 5 (Days 9-10): Documentation + cleanup
- README updates
- Inline documentation
- Performance profiling
- Deprecation notices

---

## Success Criteria

- [ ] Zero HTTP 400 errors from Ollama in mixed-provider workflows
- [ ] 90%+ test coverage on new code
- [ ] E2E script completes successfully
- [ ] All log events present in traces
- [ ] No performance regression (<2s added per loop)
- [ ] Tool-optimized model used when configured
- [ ] Existing tests pass (no regressions)
- [ ] SmartProxyClient unchanged (verified by git diff)

---

## References

ARCHITECTURAL PATTERNS:
- smart_proxy/lib/grok_client.rb (reference pattern)
- smart_proxy/lib/tool_orchestrator.rb (integration point)
- smart_proxy/lib/response_transformer.rb (response handling)

EVIDENCE:
- test/smoke/smart_proxy_live_test.rb:63-82 (tools already work)
- smart_proxy/app.rb:96-265 (endpoint handling)

DOCUMENTATION:
- https://github.com/ollama/ollama/blob/main/docs/api.md
- knowledge_base/prds/prds-junie-log/junie-log-requirement.md

---

## Confidence Assessment

CONFIDENCE: HIGH

REASONS:
1. Pattern proven (GrokClient works)
2. Integration points clear (ToolOrchestrator, ResponseTransformer)
3. Evidence SmartProxyClient needs no changes (test proves it)
4. All questions answered with rationale
5. Risk mitigation strategies defined
6. Implementation phases scoped

READY FOR IMPLEMENTATION: YES
