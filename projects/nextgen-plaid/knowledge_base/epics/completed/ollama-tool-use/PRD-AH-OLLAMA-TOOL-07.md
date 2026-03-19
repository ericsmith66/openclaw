# PRD-AH-OLLAMA-TOOL-07: Rails Client Integration and E2E Workflow Validation

Epic: EPIC-AH-OLLAMA-TOOL-USE
Status: Ready for Implementation
Priority: High

---

## Overview

Ensure Rails application can pass conversation histories and tool schemas to
SmartProxy, and validate end-to-end mixed-provider workflows.

---

## Problem Statement

Need to verify:
- Rails SmartProxyClient correctly serializes full histories with tool_calls
- Mixed-provider workflows (Grok -> Ollama) work end-to-end
- No performance regressions
- Model selection respected in agent workflows

GOAL:
- No changes needed to SmartProxyClient (already works)
- E2E script validates mixed-provider workflows
- Evidence of successful tool execution with Ollama

---

## Requirements

### Functional Requirements

#### SmartProxyClient (NO CHANGES REQUIRED)
- Already serializes full message history including tool_calls/tool_results
- Already passes tools array in payload
- Evidence: test/smoke/smart_proxy_live_test.rb:63-82

#### E2E Test Script
1. Create script/run_agent_test_sdlc_ollama_tools_e2e.sh
2. Test mixed-provider workflow:
   - Grok for SAP/Coordinator/Planner phases
   - Ollama for CWA execution phase
3. Validate:
   - Normalization events logged
   - Model selection events logged
   - Tool calls parsed successfully
   - No HTTP 400 errors
4. Exit code 0 on success, non-zero on failure

#### Performance Requirements
- <2s added latency per loop
- No degradation in non-tool requests
- Normalization overhead <1ms for typical histories

---

## Implementation

### Location

NO CHANGES: app/services/agent_hub/smart_proxy_client.rb
NEW FILE: script/run_agent_test_sdlc_ollama_tools_e2e.sh

### Code Reference

#### E2E Test Script

FILE: script/run_agent_test_sdlc_ollama_tools_e2e.sh

```bash
#!/usr/bin/env bash
set -euo pipefail

# Test mixed-provider workflow: Grok (SAP/Coord/Planner) -> Ollama (CWA)
# Validates normalization of Grok-style tool calls when consumed by Ollama

cd "$(dirname "$0")/.."

RUN_ID="${1:-$(ruby -e 'require "securerandom"; puts SecureRandom.uuid')}"

export AI_TOOLS_EXECUTE="${AI_TOOLS_EXECUTE:-true}"
export OLLAMA_TOOLS_ENABLED="${OLLAMA_TOOLS_ENABLED:-true}"
export OLLAMA_TOOL_MODEL="${OLLAMA_TOOL_MODEL:-llama3-groq-tool-use:70b}"

bundle exec rake agent:test_sdlc -- \
  --run-id="$RUN_ID" \
  --mode=end_to_end \
  --input="Create a simple CRUD feature for managing AiWorkflowTags" \
  --prompt-sap=knowledge_base/prompts/sap_prd.md.erb \
  --prompt-coord=knowledge_base/prompts/coord_analysis.md.erb \
  --prompt-planner=knowledge_base/prompts/planner_breakdown.md \
  --prompt-cwa=knowledge_base/prompts/cwa_execution.md.erb \
  --rag-sap=foundation \
  --rag-coord=foundation \
  --rag-planner=foundation \
  --rag-cwa=tier-1 \
  --sandbox-level=loose \
  --max-tool-calls=50 \
  --model-sap=grok-4-latest \
  --model-coord=grok-4-latest \
  --model-planner=grok-4-latest \
  --model-cwa=llama3-groq-tool-use:70b \
  --debug

echo ""
echo "E2E test completed. Check logs for:"
echo "  - tool_arguments_normalized events"
echo "  - model_selected_for_tools events"
echo "  - tool_calls_parsed_from_ollama events"
```

#### Usage

```bash
# Run with default UUID
./script/run_agent_test_sdlc_ollama_tools_e2e.sh

# Run with specific ID
./script/run_agent_test_sdlc_ollama_tools_e2e.sh my-test-run-001

# Disable tools for comparison
OLLAMA_TOOLS_ENABLED=false ./script/run_agent_test_sdlc_ollama_tools_e2e.sh
```

---

## Acceptance Criteria

- [ ] SmartProxy client passes full history + tools without serialization errors
- [ ] Model selector respected: groq-tool-use used for tool-heavy requests
- [ ] E2E script completes successfully with mixed providers
- [ ] No unhandled exceptions in tool loop
- [ ] Logs show full trajectory (tool calls, results, model used)
- [ ] No HTTP 400 errors from Ollama
- [ ] No performance regression (<2s added per loop)

---

## Test Cases

### Manual E2E Test

```bash
# Prerequisites
# 1. Ollama running with llama3-groq-tool-use:70b pulled
ollama pull llama3-groq-tool-use:70b

# 2. SmartProxy running
cd smart_proxy
bundle exec ruby app.rb

# 3. Rails app configured
export GROK_API_KEY="your-key"
export OLLAMA_TOOLS_ENABLED="true"
export OLLAMA_TOOL_MODEL="llama3-groq-tool-use:70b"

# 4. Run E2E test
./script/run_agent_test_sdlc_ollama_tools_e2e.sh test-run-001

# 5. Check logs
grep "tool_arguments_normalized" log/smart_proxy.log
grep "model_selected_for_tools" log/smart_proxy.log
grep "tool_calls_parsed_from_ollama" log/smart_proxy.log

# 6. Check run artifacts
ls -la knowledge_base/test_artifacts/test-run-001/
cat knowledge_base/test_artifacts/test-run-001/run_summary.md
```

### Smoke Test (Existing, proves client works)

From test/smoke/smart_proxy_live_test.rb:63-82:

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
          description: "Get the current weather in a given location",
          parameters: {
            type: "object",
            properties: {
              location: {
                type: "string",
                description: "The city and state, e.g. San Francisco, CA"
              }
            },
            required: ["location"]
          }
        }
      }
    ]
  })

  assert_equal 200, res.code.to_i
  body = JSON.parse(res.body)
  assert body.dig("choices", 0, "message", "content"), "Expected content"
  assert body["usage"], "Expected usage"
end
```

### Log Validation Test

```ruby
describe 'E2E tool flow logging' do
  it 'logs all expected events for mixed-provider workflow' do
    # Run E2E script
    system("./script/run_agent_test_sdlc_ollama_tools_e2e.sh test-e2e-log")

    log_content = File.read('log/smart_proxy.log')

    # Verify normalization
    expect(log_content).to include('tool_arguments_normalized')

    # Verify model selection
    expect(log_content).to include('model_selected_for_tools')
    expect(log_content).to include('llama3-groq-tool-use:70b')

    # Verify parsing
    expect(log_content).to include('tool_calls_parsed_from_ollama')

    # Verify no errors
    expect(log_content).not_to include('cannot unmarshal string')
  end
end
```

### Performance Test

```ruby
describe 'performance impact' do
  it 'adds <2s overhead per tool loop' do
    # Baseline: Non-tool request
    start_time = Time.now
    10.times do
      http_post_json("/v1/chat/completions", {
        model: "llama3.1:70b",
        messages: [{ role: "user", content: "Hello" }]
      })
    end
    baseline = Time.now - start_time

    # With tools
    start_time = Time.now
    10.times do
      http_post_json("/v1/chat/completions", {
        model: "llama3.1:70b",
        messages: [{ role: "user", content: "Hello" }],
        tools: [
          {
            type: "function",
            function: { name: "test", parameters: {} }
          }
        ]
      })
    end
    with_tools = Time.now - start_time

    overhead_per_request = (with_tools - baseline) / 10
    expect(overhead_per_request).to be < 2.0
  end
end
```

---

## Log Events to Verify

After E2E run, check logs contain:

### 1. Normalization Events
```json
{
  "event": "tool_arguments_normalized",
  "count": 2,
  "provider": "ollama"
}
```

### 2. Model Selection Events
```json
{
  "event": "model_selected_for_tools",
  "model": "llama3-groq-tool-use:70b",
  "reason": "tools_present"
}
```

### 3. Tool Calls Parsed Events
```json
{
  "event": "tool_calls_parsed_from_ollama",
  "count": 1,
  "tool_calls": [
    {
      "id": "call_abc123",
      "function": "execute_shell",
      "arguments_valid": true
    }
  ]
}
```

### 4. No Errors
```
# Should NOT appear:
"cannot unmarshal string into tool_calls.function.arguments"
"tools_validation_failed"
```

---

## Success Metrics

- E2E script exits 0 (success)
- Zero HTTP 400 errors from Ollama
- All expected log events present
- Tool execution completes successfully
- Mixed-provider workflow completes end-to-end
- Performance within acceptable bounds (<2s overhead)
- Model selection works as expected

---

## Validation Checklist

- [ ] Run E2E script with default settings
- [ ] Verify log events (normalization, model selection, parsing)
- [ ] Check no HTTP 400 errors in logs
- [ ] Verify tool execution artifacts created
- [ ] Run with OLLAMA_TOOLS_ENABLED=false (should drop tools)
- [ ] Run smoke tests (all pass)
- [ ] Measure performance (baseline vs with-tools)
- [ ] Verify SmartProxyClient unchanged (git diff app/services/agent_hub/smart_proxy_client.rb)

---

## Dependencies

- All PRDs 00-06 (complete implementation and tests)
- Ollama running with llama3-groq-tool-use:70b model
- Grok API key for mixed-provider workflow
- Rails SDLC test infrastructure (rake agent:test_sdlc)

---

## Evidence of Success

1. **Smoke Test Evidence**: test/smoke/smart_proxy_live_test.rb:63-82 already passes tools to Ollama endpoint
2. **Client Evidence**: SmartProxyClient already serializes tools in payload (no changes needed)
3. **E2E Evidence**: Script completes successfully with all log events present
4. **Performance Evidence**: <2s overhead measured in tests
5. **Integration Evidence**: Mixed-provider workflows complete without errors
