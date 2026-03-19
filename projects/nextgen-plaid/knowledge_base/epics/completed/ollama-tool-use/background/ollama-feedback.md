# Epic Review: Ollama Tool Calling + Cross-LLM Interoperability
Review Date: 2026-01-16
Reviewer: Claude Sonnet 4.5
Epic Version: 1.1a

---

## Executive Summary

The epic is well-structured and comprehensive but has 10 critical gaps requiring
clarification before implementation. Primary issues: unclear data flow through
the orchestrator, missing interface contracts, and incomplete E2E test coverage.

Status: REQUIRES CLARIFICATION before PRD-00 implementation.

---

## Strengths

1. Clear Motivation: Spike identified concrete bug (HTTP 400 on mixed-provider
   histories with stringified tool arguments)
2. Logical Ordering: PRD-00 (normalization) correctly prioritized to unblock
   E2E immediately
3. Comprehensive Scope: Covers full lifecycle (validation -> forwarding ->
   parsing -> error handling -> logging -> testing)
4. Security-Conscious: Local-only, environment gating (OLLAMA_TOOLS_ENABLED),
   max tool limits (20)
5. Detailed Requirements: Most PRDs have clear acceptance criteria and test cases

---

## Critical Issues and Questions

### 1. Normalization Location and Data Flow (PRD-00)

ISSUE: The PRD states normalization happens in ollama_client.rb but doesn't
specify where in the request pipeline:

Current flow (from code analysis):
```
app.rb:96 (/v1/chat/completions)
  |
  v
ToolOrchestrator.orchestrate
  |
  v
[Provider routing logic]
  |
  v
OllamaClient.chat (line 20-39) ( EAS Ollama-specific here or another ollamic spesific file )
  |
  v
Ollama /api/chat
```

QUESTIONS:
1. Does normalization happen in OllamaClient#chat (Ollama-specific)?
2. Or in ToolOrchestrator (provider-agnostic)?
3. Or in app.rb before routing?
4. Should normalization apply to ALL providers or just Ollama? (EAS only if its neccesary to reach the goals for the project )

CURRENT CODE GAP:
- ollama_client.rb:20-39 builds payload but has no normalization logic
- No normalize_tool_arguments(messages) helper exists ( EAS we need to be able to have upstream and down stream LLM understant each other tool calling response for example Coordinator builds a plan CWA needs to be able to consume it ) ) 

RECOMMENDATION:
- Add normalization in OllamaClient#chat at line 20 (Ollama-specific requirement) (eas agree)
- Create helper: normalize_tool_arguments(messages) that walks messages array  (eas agree)
- Apply before building ollama_payload at line 28 (eas agree)

EXAMPLE IMPLEMENTATION:
```ruby
def chat(payload)
  # Normalize Ollama-specific requirements
  normalized_messages = normalize_tool_arguments(payload['messages'])

  ollama_payload = {
    model: payload['model'],
    messages: normalized_messages,
    stream: false
  }
  # rest of implementation
end

private

def normalize_tool_arguments(messages)
  return messages unless messages.is_a?(Array)

  normalized_count = 0
  result = messages.map do |msg|
    next msg unless msg['tool_calls'].is_a?(Array)

    msg_copy = msg.dup
    msg_copy['tool_calls'] = msg['tool_calls'].map do |tc|
      tc_copy = tc.dup
      args = tc.dig('function', 'arguments')

      if args.is_a?(String)
        tc_copy['function'] = tc['function'].dup
        tc_copy['function']['arguments'] = JSON.parse(args) rescue {}
        normalized_count += 1
      end

      tc_copy
    end

    msg_copy
  end

  if normalized_count > 0
    $logger.debug({
      event: 'tool_arguments_normalized',
      count: normalized_count
    })
  end

  result
end
```

---

### 2. Tools Payload Interface (PRD-02/PRD-04)

ISSUE: PRDs don't specify how tools array flows through the system.

CURRENT CODE:
- app.rb:96-100 receives request payload
- ollama_client.rb:28-32 builds payload with model, messages, stream only
- No tools key forwarded

QUESTIONS:
1. Does app.rb extract tools from request and pass to orchestrator? ( EAS pass to orchestrator)
2. Does ToolOrchestrator forward tools to OllamaClient? (EAS yes to be consistant with prior conversation) 
3. What's the new signature for OllamaClient#chat(payload)? eas I dont know . we should use the patterns in openAi or grok

MISSING REQUIREMENTS:

FR4 (revised):
```ruby
# In OllamaClient#chat
def chat(payload)
  normalized_messages = normalize_tool_arguments(payload['messages'])

  env_model = ENV['OLLAMA_MODEL']
  env_model = nil if env_model.nil? || env_model.strip.empty?

  ollama_payload = {
    model: payload['model'] == 'ollama' ? (env_model || 'llama3.1:8b') : payload['model'],
    messages: normalized_messages,
    stream: false
  }

  # FR2: Validate tools if present
  if payload['tools']
    validated_tools = validate_and_gate_tools(payload['tools'])
    ollama_payload[:tools] = validated_tools if validated_tools
  end

  connection.post('') do |req|
    req.body = ollama_payload.to_json
  end
end
```

ADD TO PRD-02: Document the interface contract:
- Input: payload['tools'] (optional Array)
- Output: ollama_payload[:tools] included if validation passes and
  OLLAMA_TOOLS_ENABLED=true

---

### 3. Gating Logic Order (PRD-01/PRD-02 Conflict)

ISSUE: Unclear order of operations when tools are present.

CURRENT PRD FLOW:
1. PRD-01: Validate tools schema (strict)
2. PRD-02: Check OLLAMA_TOOLS_ENABLED flag

AMBIGUITY:
- If flag is false and tools are invalid, do we:
  - A) Return 400 validation error?
  - B) Silently drop tools (no validation)?
  - C) Log warning and proceed?

QUESTIONS:
1. Should validation happen before or after flag check? ( EAS Before )
2. What's the behavior matrix?

RECOMMENDATION: Always validate first (fail fast principle): (Eas Agree)

| Scenario | Tools Valid? | Flag Enabled? | Behavior                 |
|----------|--------------|---------------|--------------------------|
| 1        | No           | Yes           | 400 validation error     |
| 2        | No           | No            | 400 validation error     |
| 3        | Yes          | Yes           | Forward to Ollama        |
| 4        | Yes          | No            | Silently drop + log      |

ADD TO PRD-02:
```ruby
def validate_and_gate_tools(tools)
  # Always validate first (fail fast)
  validate_tools_schema!(tools) # raises ArgumentError on invalid

  # Then check gate
  unless ENV.fetch('OLLAMA_TOOLS_ENABLED', 'true') == 'true'
    $logger.info({
      event: 'tools_dropped_disabled',
      count: tools.length
    })
    return nil
  end

  $logger.debug({
    event: 'tools_forwarded',
    count: tools.length,
    names: tools.map { |t| t.dig('function', 'name') }
  })

  tools
end
```

---

### 4. Rails Client Integration Details (PRD-07)

ISSUE: PRD-07 says "minor tweaks" but provides no specification.

CURRENT CODE (app/services/agent_hub/smart_proxy_client.rb:24-28):
```ruby
payload = {
  model: @model,
  messages: messages,
  stream: @stream
}
```

QUESTIONS:
1. How does Rails pass tools to SmartProxy? ( eas see the grok pattern look in live test and smoke test)
2. Does SmartProxyClient#chat need a new tools: parameter? ( EAS I dont know but we want to keep business logic out of smartprox . Its a crap berrier between NextGen and LLM providers. all calls should look the same regardless of LLM provider)
3. How do mixed-provider histories work if Rails already sent stringified
   arguments from Grok? ( moslty we have just been using grok)

MISSING REQUIREMENTS:

ADD TO PRD-07:

NEW INTERFACE:
```ruby
# app/services/agent_hub/smart_proxy_client.rb
def chat(messages, tools: nil, stream_to: nil, message_id: nil)
  payload = {
    model: @model,
    messages: messages,
    stream: @stream
  }

  payload[:tools] = tools if tools # Optional tools array

  if @stream
    chat_stream(conn, payload, stream_to, message_id)
  else
    chat_non_stream(conn, payload)
  end
end
```

USAGE EXAMPLE:
```ruby
# In an agent or service
tools = [
  {
    type: "function",
    function: {
      name: "run_python_simulation",
      description: "Execute Monte Carlo simulation",
      parameters: {
        type: "object",
        properties: {
          scenario: { type: "string" },
          iterations: { type: "integer" }
        }
      }
    }
  }
]

client = AgentHub::SmartProxyClient.new(model: 'llama3.1:70b')
response = client.chat(messages, tools: tools)
```

E2E TESTING:
- Add test case to run_agent_test_sdlc_e2e.sh with --model-cwa=llama3.1:70b
- Or create run_agent_test_sdlc_ollama_tools_e2e.sh variant

---

### 5. Streaming Rejection Scope (PRD-04/FR6)

ISSUE: FR6 conflicts with existing streaming logic.

CURRENT CODE (app.rb:164-166):
```ruby
# Disable upstream streaming for tool-opt-in requests
# (e.g. grok-4-with-live-search)
if request_payload['stream'] == true && tools_opt_in
  upstream_payload['stream'] = false
end
```

FR6 SAYS:
> If stream: true and tools present -> return HTTP 400

QUESTIONS:
1. Does FR6 apply to all providers or just Ollama? eas I would not change other providers to prevent regression ( assuming they are working )
2. Should we reject in app.rb (global) or OllamaClient (provider-specific)? eas I dont know -- look at the test
3. How does this interact with the existing tool-opt-in override? eas I dont know -- look at the test

AMBIGUITY:
- Grok supports streaming + tools (SmartProxy disables upstream streaming, then
  simulates SSE)
- Ollama doesn't support streaming + tools (should reject early) EAS We are trying to support tool call ( ollama has a pattern but its not openAI)

RECOMMENDATION: Make FR6 Ollama-specific:

ADD TO PRD-04:
```ruby
# In OllamaClient#chat
def chat(payload)
  # Ollama limitation: can't stream with tools
  if payload['stream'] == true && payload['tools']&.any?
    raise ArgumentError, "Ollama does not support streaming with tool calls"
  end

  # rest of implementation
end
```

THEN IN APP.RB, catch the error:
```ruby
begin
  response = orchestrator.orchestrate(
    upstream_payload,
    routing: routing,
    max_loops: max_loops_override
  )
rescue ArgumentError => e
  if e.message.include?('streaming with tool calls')
    halt 400, {
      error: 'streaming_not_supported_with_tools',
      message: e.message
    }.to_json
  end
  raise
end
```

---

### 6. Response Parsing Location (PRD-03)

ISSUE: Doesn't specify where tool_calls parsing happens.

CURRENT FLOW:
```
OllamaClient#chat returns OpenStruct
  |
  v
ToolOrchestrator processes response
  |
  v
ResponseTransformer.to_openai_format
  |
  v
Returns to Rails
```

QUESTIONS:
1. Where should response.message.tool_calls be parsed? EAS  If the client needs it
2. Should parsing happen in OllamaClient (provider-specific)? EAS I dont know 
3. Or in ResponseTransformer (provider-agnostic)? EAS I dont know
4. What's the return type of OllamaClient#chat after parsing? EAS I dont know

RECOMMENDATION: Parse in OllamaClient#chat (provider-specific logic):

ADD TO PRD-03:
```ruby
def chat(payload)
  # build and send request

  resp = connection.post('') do |req|
    req.body = ollama_payload.to_json
  end

  body = JSON.parse(resp.body)

  # Parse tool calls if present
  if body.dig('message', 'tool_calls')
    body['message']['tool_calls'] = parse_tool_calls(
      body['message']['tool_calls']
    )
  end

  OpenStruct.new(status: resp.status, body: body)
rescue Faraday::Error => e
  handle_error(e)
end

private

def parse_tool_calls(ollama_tool_calls)
  ollama_tool_calls.map do |tc|
    args = tc.dig('function', 'arguments')

    # Ollama may return arguments as string or object
    parsed_args = if args.is_a?(String)
      begin
        JSON.parse(args)
      rescue JSON::ParserError => e
        $logger.warn({
          event: 'tool_call_argument_parse_error',
          error: e.message,
          raw: args
        })
        {
          error: 'invalid_json',
          raw: args,
          parse_error: e.message
        }
      end
    else
      args
    end

    {
      id: "call_#{SecureRandom.hex(6)}", # Generate OpenAI-style ID
      type: "function",
      function: {
        name: tc.dig('function', 'name'),
        arguments: parsed_args
      }
    }
  end
end
```

---

### 7. Artifact Logging (Missing Requirement)

ISSUE: No specification for how tool calls appear in test artifacts.

CURRENT CODE (app.rb:368-411):
```ruby
def dump_llm_call_artifact!(
  agent:,
  request_id:,
  correlation_id:,
  request_payload:,
  response_status:,
  response_body:,
  base_dir_override: nil
)
  payload = {
    ts: Time.now.utc.iso8601,
    request_id: request_id,
    correlation_id: correlation_id,
    agent: agent,
    model: request_payload['model'],
    request_bytes: request_payload.to_json.bytesize,
    response_status: response_status,
    response_bytes: response_body.to_s.bytesize,
    usage: usage,
    request: request_payload,
    response: parsed_response || response_body
  }
  # write to file
end
```

QUESTIONS:
1. Should tools in request be logged separately? EAS Yes 
2. Should tool_calls in response be highlighted? EAS if helpfull
3. Should normalization be visible (before/after comparison)? EAS I dont know 

RECOMMENDATION:

ADD TO PRD-05 or create PRD-08:
- Extract tools count to top-level metadata
- Extract tool_calls count to top-level metadata
- Add normalized_tool_calls_count if normalization occurred

EXAMPLE:
```ruby
payload = {
  # existing fields
  tools_count: (request_payload['tools'] || []).length,
  tool_calls_count: parsed_response.dig(
    'choices', 0, 'message', 'tool_calls'
  )&.length || 0,
  normalized_count: @normalized_count || 0, # Set during normalization
  request: request_payload,
  response: parsed_response || response_body
}
```

---

### 8. Model Capability Checking (Missing Feature)

ISSUE: Not all Ollama models support tools.

CONTEXT:
- llama3.1:8b -> may not support tools
- llama3.1:70b / llama3.1:405b -> likely support tools
- llama3.2:3b -> likely doesn't support tools

QUESTIONS:
1. Should SmartProxy check model capabilities before forwarding tools? Yes 
2. Should it return 400 "Model X doesn't support tools"? Yes
3. Or rely on Ollama's error handling (let it return 400)? 
4. How do we handle model-specific limits (some models support less than 20 tools)? It likeley that we are using 

RECOMMENDATION: Document, don't implement (for this epic):

ADD TO PRD-02 (or mark as out-of-scope):
> Out of Scope: Model capability checking. SmartProxy will forward validated
> tools to Ollama and rely on Ollama's error response if the model doesn't
> support tools. Future enhancement: query Ollama /api/show for model
> capabilities.

RATIONALE:
- Keeps epic focused
- Ollama API may not expose capability metadata yet
- Reduces complexity for initial implementation

---

### 9. E2E Test Coverage (PRD-07 Gap)

ISSUE: run_agent_test_sdlc_e2e.sh uses only Grok, not Ollama.

CURRENT SCRIPT (line 38-41):
```bash
--model-sap=grok-4-latest \
--model-coord=grok-4-latest \
--model-planner=grok-4-latest \
--model-cwa=grok-4-latest \
```

EPIC CLAIMS:
> "E2E script (run_agent_test_sdlc_e2e.sh) runs cleanly with mixed providers
> (e.g., Claude -> Grok -> Ollama)"

QUESTIONS:
1. Should PRD-07 create a new E2E script variant?
2. Or document manual override (e.g., --model-cwa=llama3.1:70b)?
3. How do we test mixed-provider histories (Grok generates tool_calls with
   string args -> Ollama consumes them)?

RECOMMENDATION:

ADD TO PRD-07:

NEW TEST SCRIPT: script/run_agent_test_sdlc_ollama_tools_e2e.sh
```bash
#!/usr/bin/env bash
set -euo pipefail

# Test mixed-provider workflow: Grok (SAP/Coord/Planner) -> Ollama (CWA)
# Validates normalization of Grok-style tool calls when consumed by Ollama

cd "$(dirname "$0")/.."

RUN_ID="${1:-$(ruby -e 'require "securerandom"; puts SecureRandom.uuid')}"

export AI_TOOLS_EXECUTE="${AI_TOOLS_EXECUTE:-true}"
export OLLAMA_TOOLS_ENABLED="${OLLAMA_TOOLS_ENABLED:-true}"

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
  --model-cwa=llama3.1:70b \
  --debug
```

ACCEPTANCE CRITERIA:
- Script completes without HTTP 400 from Ollama
- Logs show tool_arguments_normalized events
- CWA agent successfully executes with Ollama + tools

---

### 10. Log Format Specification (PRD-05 Gap)

ISSUE: References junie-log-requirement.md but doesn't show structure.

CURRENT FORMAT (app.rb:46-52):
```ruby
$logger.formatter = proc do |severity, datetime, _progname, msg|
  {
    timestamp: datetime,
    severity: severity,
    message: msg
  }.to_json + "\n"
end
```

QUESTIONS:
1. What's the exact format for tool events?
2. Should tool_calls be nested or flattened?
3. What's the structure for "normalized N tool calls"?

RECOMMENDATION:

ADD TO PRD-05 - Example log entries:

NORMALIZATION EVENT:
```json
{
  "timestamp": "2026-01-16T10:30:45Z",
  "severity": "DEBUG",
  "event": "tool_arguments_normalized",
  "session_id": "abc123",
  "correlation_id": "run-456",
  "message_index": 3,
  "tool_calls_normalized": 2,
  "details": [
    {
      "tool_call_id": "call_abc",
      "function": "search",
      "converted": "string to object"
    },
    {
      "tool_call_id": "call_def",
      "function": "execute",
      "converted": "string to object"
    }
  ]
}
```

TOOL VALIDATION SUCCESS:
```json
{
  "timestamp": "2026-01-16T10:30:45Z",
  "severity": "DEBUG",
  "event": "tools_validated",
  "session_id": "abc123",
  "tools_count": 3,
  "tools": ["search", "execute", "analyze"]
}
```

TOOL VALIDATION FAILURE:
```json
{
  "timestamp": "2026-01-16T10:30:45Z",
  "severity": "WARN",
  "event": "tools_validation_failed",
  "session_id": "abc123",
  "error": "tools[2].function.name is missing",
  "tools_sent": 5
}
```

TOOLS FORWARDED:
```json
{
  "timestamp": "2026-01-16T10:30:46Z",
  "severity": "INFO",
  "event": "tools_forwarded_to_ollama",
  "session_id": "abc123",
  "tools_count": 3,
  "tools": ["search", "execute", "analyze"],
  "model": "llama3.1:70b"
}
```

TOOLS DROPPED (flag disabled):
```json
{
  "timestamp": "2026-01-16T10:30:46Z",
  "severity": "INFO",
  "event": "tools_dropped_disabled",
  "session_id": "abc123",
  "tools_count": 3,
  "reason": "OLLAMA_TOOLS_ENABLED=false"
}
```

TOOL CALLS PARSED:
```json
{
  "timestamp": "2026-01-16T10:30:47Z",
  "severity": "DEBUG",
  "event": "tool_calls_parsed_from_ollama",
  "session_id": "abc123",
  "tool_calls_count": 2,
  "tool_calls": [
    {
      "id": "call_a1b2c3",
      "function": "search",
      "arguments_valid": true
    },
    {
      "id": "call_d4e5f6",
      "function": "execute",
      "arguments_valid": false,
      "parse_error": "invalid JSON"
    }
  ]
}
```

---

## Questions for Product/Engineering

### High Priority (Block PRD-00 implementation)

1. NORMALIZATION SCOPE: Should normalization be Ollama-specific or apply to all
   providers?
   - Recommendation: Ollama-specific (in OllamaClient)
   - Rationale: Other providers don't have this requirement

2. TOOLS PAYLOAD FLOW: What's the exact interface for passing tools through the
   orchestrator?
   - Recommendation: Add explicit interface contracts to PRD-02/04
   - Deliverable: Method signatures + example payloads

3. GATING BEHAVIOR: When OLLAMA_TOOLS_ENABLED=false + valid tools sent, should
   we error or silently drop?
   - Recommendation: Silently drop with info log (graceful degradation)
   - Rationale: Allows runtime feature toggling without breaking clients

### Medium Priority (Clarify before PRD-03/04)

4. STREAMING REJECTION: Is FR6 Ollama-specific or applies to all providers?
   - Recommendation: Ollama-specific
   - Rationale: Grok already handles streaming + tools via SmartProxy workaround

5. RESPONSE PARSING: Where should tool_calls parsing happen?
   - Recommendation: In OllamaClient#chat before returning
   - Rationale: Provider-specific logic, cleaner separation of concerns

6. MODEL CAPABILITIES: Should SmartProxy check if Ollama model supports tools?
   - Recommendation: Mark as out-of-scope for this epic
   - Rationale: Reduces complexity; Ollama will error if unsupported

### Low Priority (Clarify before PRD-07)

7. RAILS CLIENT INTERFACE: Should SmartProxyClient#chat add tools: parameter?
   - Recommendation: Yes, optional keyword argument
   - Deliverable: Example usage in PRD-07

8. E2E TESTING: Should PRD-07 create new script or document manual override?
   - Recommendation: Create run_agent_test_sdlc_ollama_tools_e2e.sh
   - Rationale: Explicit test coverage for mixed-provider scenarios

9. ARTIFACT LOGGING: Should tool calls be logged separately in test artifacts?
   - Recommendation: Yes, add tools_count and tool_calls_count to metadata
   - Rationale: Easier debugging and testing

10. LOG FORMAT: What's the exact junie-log-requirement.md format?
    - Recommendation: Use provided examples above
    - Deliverable: Add example log entries to PRD-05

---

## Recommended Next Steps

### Immediate Actions (Before Development)

1. CLARIFY HIGH-PRIORITY QUESTIONS (1-3 above)
   - Schedule 30-min sync with product/engineering
   - Document decisions in PRD-00/01/02

2. UPDATE PRD-00 (Normalization)
   - Add explicit flow diagram showing where normalization happens
   - Add example implementation of normalize_tool_arguments helper
   - Add regression test case reproducing exact 400 error from spike

3. UPDATE PRD-02/04 (Tool Forwarding)
   - Add method signature for OllamaClient#chat(payload)
   - Add example ollama_payload structure with tools: key
   - Add gating logic flowchart (validate -> check flag -> forward/drop)

4. UPDATE PRD-05 (Logging)
   - Replace junie-log-requirement.md reference with explicit examples
   - Add 6 example log entries (normalized, validated, forwarded, dropped,
     parsed, parse-error)

5. UPDATE PRD-07 (Integration)
   - Add SmartProxyClient#chat interface with tools: parameter
   - Create run_agent_test_sdlc_ollama_tools_e2e.sh script
   - Add acceptance criteria: "E2E runs with --model-cwa=llama3.1:70b without
     HTTP 400"

### PRD Implementation Order (After Clarifications)

PHASE 1: FOUNDATION (Week 1)
- PRD-00: Normalization (unblocks E2E)
- PRD-01: Validation (fail fast on bad input)

PHASE 2: CORE FEATURES (Week 1-2)
- PRD-02: Gated forwarding
- PRD-03: Response parsing
- PRD-04: Streaming rejection

PHASE 3: OBSERVABILITY (Week 2)
- PRD-05: Logging enhancements
- Artifact logging (if in scope)

PHASE 4: TESTING AND INTEGRATION (Week 2-3)
- PRD-06: Unit/integration tests (90% coverage target)
- PRD-07: Rails client + E2E test script

---

## Risk Assessment

| Risk                                          | Severity | Likelihood | Mitigation                                                                        |
|-----------------------------------------------|----------|------------|-----------------------------------------------------------------------------------|
| Normalization breaks non-Ollama providers     | High     | Medium     | Make normalization Ollama-specific; add regression tests for Grok/Claude          |
| Ollama model doesn't support tools            | Medium   | Low        | Document model requirements (llama3.1:70b+); rely on Ollama error handling        |
| Performance impact of normalization           | Low      | Low        | O(n) on message count; negligible for typical conversations (less than 50 msgs)   |
| E2E test doesn't catch cross-provider issues  | Medium   | High       | Create explicit mixed-provider E2E script with Grok -> Ollama flow                |
| Streaming rejection breaks existing workflows | Medium   | Medium     | Make rejection Ollama-specific; preserve existing Grok streaming behavior         |

---

## Approval Checklist

Before starting PRD-00 implementation:

- [ ] All 10 high-priority questions answered
- [ ] PRD-00 updated with flow diagram + example implementation
- [ ] PRD-02/04 updated with interface contracts
- [ ] PRD-05 updated with example log entries
- [ ] PRD-07 updated with Rails client interface + E2E script
- [ ] Team consensus on normalization scope (Ollama-only vs universal)
- [ ] Team consensus on gating behavior (error vs silent-drop)
- [ ] Spike validation: confirm exact Ollama API expectations for tools payload

---

## References

- Original PRD: knowledge_base/ignore/Ollama-Epic.md
- Current Implementation:
  - smart_proxy/lib/ollama_client.rb:1-65
  - smart_proxy/app.rb:1-414
  - app/services/agent_hub/smart_proxy_client.rb:1-124
- E2E Test Script: script/run_agent_test_sdlc_e2e.sh
- Ollama API Docs: https://github.com/ollama/ollama/blob/main/docs/api.md

---

REVIEW STATUS: REQUIRES CLARIFICATION
CONFIDENCE LEVEL: Medium (comprehensive analysis, but critical gaps remain)
RECOMMENDED ACTION: Schedule alignment meeting before PRD-00 development sprint
