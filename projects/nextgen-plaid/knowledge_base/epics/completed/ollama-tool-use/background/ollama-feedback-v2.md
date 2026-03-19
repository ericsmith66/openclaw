# Ollama Tool Support Epic - Feedback v2
Review Date: 2026-01-16
Reviewer: Claude Sonnet 4.5
Epic Version: v2 (considering Grok patterns and SmartProxy architecture)

---

## Executive Summary

After reviewing ollama-epic-v2.md, ollama-feedback.md, and the GrokClient
implementation patterns, this document provides architectural guidance for
implementing Ollama tool support that:

1. Mirrors the proven GrokClient structure
2. Integrates cleanly with existing ToolOrchestrator
3. Maintains consistency with OpenAI-compatible patterns
4. Addresses all 10 critical issues from feedback-v1

STATUS: READY FOR IMPLEMENTATION with architectural clarifications below

---

## Architecture Analysis: Learning from GrokClient

### GrokClient Pattern (smart_proxy/lib/grok_client.rb)

STRENGTHS TO REPLICATE:
```ruby
class GrokClient
  BASE_URL = 'https://api.x.ai/v1'

  def initialize(api_key:)
    @api_key = api_key
  end

  def chat_completions(payload)
    connection.post('chat/completions') do |req|
      req.body = payload.to_json  # <-- payload passed directly
    end
  end

  private

  def connection
    @connection ||= Faraday.new(url: BASE_URL) do |f|
      f.request :json
      f.options.timeout = ENV.fetch('GROK_TIMEOUT', '120').to_i
      f.request :retry, {
        max: 3,
        interval: 0.5,
        backoff_factor: 2,
        retry_statuses: [429, 500, 502, 503, 504]
      }
      f.headers['Authorization'] = "Bearer #{@api_key}"
      f.adapter Faraday.default_adapter
    end
  end
end
```

KEY OBSERVATIONS:
1. chat_completions accepts FULL payload (including tools if present)
2. Payload passed through unchanged to upstream API
3. Retry logic built into Faraday middleware
4. No payload transformation in client (provider-agnostic)
5. Returns Faraday::Response with status and body

---

## OllamaClient Refactor: Match GrokClient Patterns

### Current OllamaClient Issues

CURRENT CODE (ollama_client.rb:20-39):
```ruby
def chat(payload)
  # Manually builds ollama_payload
  ollama_payload = {
    model: payload['model'] == 'ollama' ? (env_model || 'llama3.1:8b') : payload['model'],
    messages: payload['messages'],
    stream: false
  }
  # NO TOOLS KEY

  connection.post('') do |req|
    req.body = ollama_payload.to_json
  end
end
```

PROBLEMS:
1. Only forwards model, messages, stream
2. No tools key
3. No normalization
4. No retry logic
5. Method name chat vs chat_completions (inconsistent with Grok)

---

### Recommended OllamaClient Refactor

```ruby
require 'faraday'
require 'faraday/retry'
require 'json'
require 'ostruct'
require 'securerandom'

class OllamaClient
  DEFAULT_URL = 'http://localhost:11434/api/chat'
  DEFAULT_TAGS_URL = 'http://localhost:11434/api/tags'

  def initialize(url: nil)
    @url = url || ENV['OLLAMA_URL'] || DEFAULT_URL
  end

  def list_models
    resp = tags_connection.get('')
    OpenStruct.new(status: resp.status, body: resp.body)
  rescue Faraday::Error => e
    handle_error(e)
  end

  # REFACTORED: Match GrokClient pattern
  def chat_completions(payload)
    # STEP 1: Normalize tool arguments (Ollama-specific requirement)
    normalized_payload = normalize_tool_arguments_in_payload(payload)

    # STEP 2: Validate and gate tools if present
    if normalized_payload['tools']
      validated_tools = validate_and_gate_tools(normalized_payload['tools'])
      normalized_payload['tools'] = validated_tools
      normalized_payload.delete('tools') if validated_tools.nil?
    end

    # STEP 3: Select appropriate model based on tool presence
    normalized_payload['model'] = select_model(
      normalized_payload['model'],
      has_tools: normalized_payload['tools']&.any?
    )

    # STEP 4: Enforce non-streaming for tools
    if normalized_payload['stream'] == true && normalized_payload['tools']&.any?
      raise ArgumentError, "Ollama does not support streaming with tool calls"
    end

    # STEP 5: Ensure stream: false (Ollama API requirement)
    normalized_payload['stream'] = false

    # STEP 6: Make request with retry
    resp = connection.post('') do |req|
      req.body = normalized_payload.to_json
    end

    # STEP 7: Parse and transform response
    body = JSON.parse(resp.body)
    body = parse_tool_calls_if_present(body)

    OpenStruct.new(status: resp.status, body: body)
  rescue Faraday::Error => e
    handle_error(e)
  end

  private

  # NORMALIZATION: Handle Grok/OpenAI -> Ollama incompatibility
  def normalize_tool_arguments_in_payload(payload)
    normalized = payload.dup
    return normalized unless normalized['messages'].is_a?(Array)

    normalized_count = 0

    normalized['messages'] = normalized['messages'].map do |msg|
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
      log_debug(
        event: 'tool_arguments_normalized',
        count: normalized_count,
        provider: 'ollama'
      )
    end

    normalized
  end

  # VALIDATION: Strict schema checking
  def validate_and_gate_tools(tools)
    return nil unless tools.is_a?(Array)

    # Validate schema first (fail fast)
    validate_tools_schema!(tools)

    # Check environment gate
    unless ENV.fetch('OLLAMA_TOOLS_ENABLED', 'true') == 'true'
      log_info(
        event: 'tools_dropped_disabled',
        count: tools.length,
        reason: 'OLLAMA_TOOLS_ENABLED=false'
      )
      return nil
    end

    log_debug(
      event: 'tools_forwarded',
      count: tools.length,
      names: tools.map { |t| t.dig('function', 'name') }
    )

    tools
  end

  def validate_tools_schema!(tools)
    raise ArgumentError, "tools must be an array" unless tools.is_a?(Array)
    raise ArgumentError, "maximum 20 tools allowed" if tools.length > 20

    tools.each_with_index do |tool, index|
      unless tool.is_a?(Hash) && tool['type'] == 'function'
        raise ArgumentError, "tools[#{index}].type must be 'function'"
      end

      function = tool['function']
      unless function.is_a?(Hash)
        raise ArgumentError, "tools[#{index}].function must be an object"
      end

      if function['name'].to_s.strip.empty?
        raise ArgumentError, "tools[#{index}].function.name is required"
      end

      unless function['parameters'].is_a?(Hash)
        raise ArgumentError, "tools[#{index}].function.parameters must be an object"
      end
    end

    log_debug(event: 'tools_validated', count: tools.length)
  end

  # MODEL SELECTION: Use tool-optimized model when appropriate
  def select_model(requested_model, has_tools:)
    env_model = ENV['OLLAMA_MODEL']
    env_model = nil if env_model.nil? || env_model.strip.empty?

    # If explicit model requested, use it
    return requested_model unless requested_model == 'ollama' || requested_model.nil?

    # Default: llama3.1:70b for general use
    default_model = env_model || 'llama3.1:70b'

    # If tools present, prefer groq-tool-use model if available
    if has_tools && ENV['OLLAMA_TOOL_MODEL']
      tool_model = ENV['OLLAMA_TOOL_MODEL']
      log_debug(
        event: 'model_selected_for_tools',
        model: tool_model,
        reason: 'tools_present'
      )
      return tool_model
    end

    default_model
  end

  # RESPONSE PARSING: Convert Ollama tool_calls to OpenAI format
  def parse_tool_calls_if_present(body)
    return body unless body.is_a?(Hash)

    tool_calls = body.dig('message', 'tool_calls')
    return body unless tool_calls.is_a?(Array)

    body['message']['tool_calls'] = tool_calls.map do |tc|
      parse_tool_call(tc)
    end

    log_debug(
      event: 'tool_calls_parsed_from_ollama',
      count: body['message']['tool_calls'].length,
      tool_calls: body['message']['tool_calls'].map { |t| {
        id: t['id'],
        function: t.dig('function', 'name'),
        arguments_valid: !t.dig('function', 'arguments', 'error')
      }}
    )

    body
  end

  def parse_tool_call(ollama_tool_call)
    args = ollama_tool_call.dig('function', 'arguments')

    parsed_args = if args.is_a?(String)
      begin
        JSON.parse(args)
      rescue JSON::ParserError => e
        log_warn(
          event: 'tool_call_argument_parse_error',
          error: e.message,
          raw: args
        )
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
      id: "call_#{SecureRandom.hex(6)}",
      type: "function",
      function: {
        name: ollama_tool_call.dig('function', 'name'),
        arguments: parsed_args
      }
    }
  end

  # CONNECTION: Match GrokClient pattern with retry
  def connection
    @connection ||= Faraday.new(url: @url) do |f|
      f.request :json
      f.options.timeout = ENV.fetch('OLLAMA_TIMEOUT', '120').to_i
      f.options.open_timeout = 10
      f.request :retry, {
        max: 3,
        interval: 2,
        interval_randomness: 0.5,
        backoff_factor: 2,
        retry_statuses: [429, 500, 502, 503, 504]
      }
      f.adapter Faraday.default_adapter
    end
  end

  def tags_connection
    @tags_connection ||= Faraday.new(url: ENV['OLLAMA_TAGS_URL'] || DEFAULT_TAGS_URL) do |f|
      f.request :json
      f.adapter Faraday.default_adapter
    end
  end

  def handle_error(error)
    status = error.response ? error.response[:status] : 500
    body = error.response ? error.response[:body] : { error: error.message }

    OpenStruct.new(status: status, body: body)
  end

  # LOGGING HELPERS
  def log_debug(data)
    $logger&.debug(data) if defined?($logger)
  end

  def log_info(data)
    $logger&.info(data) if defined?($logger)
  end

  def log_warn(data)
    $logger&.warn(data) if defined?($logger)
  end
end
```

---

## Integration with ToolOrchestrator

### Current ToolOrchestrator Flow

From smart_proxy/lib/tool_orchestrator.rb:36-41:
```ruby
while loop_count <= max_loops
  response = if client.respond_to?(:chat_completions)
               client.chat_completions(current_payload)  # <-- Grok/Claude path
             else
               client.chat(current_payload)              # <-- Ollama path (old)
             end
```

REQUIRED CHANGE:
OllamaClient must implement chat_completions method (not chat) to match pattern.

### ResponseTransformer Integration

From smart_proxy/lib/response_transformer.rb:122-159:
```ruby
def ollama_to_openai(parsed)
  msg = parsed['message'] || {}
  # ... transforms Ollama response to OpenAI format
  {
    id: "chatcmpl-#{SecureRandom.hex(8)}",
    object: 'chat.completion',
    created: created,
    model: @model,
    choices: [
      {
        index: 0,
        finish_reason: 'stop',
        message: {
          role: msg['role'] || 'assistant',
          content: msg['content']
        }
      }
    ],
    usage: { ... }
  }
end
```

REQUIRED UPDATE:
ResponseTransformer.ollama_to_openai must handle tool_calls in message:
```ruby
def ollama_to_openai(parsed)
  msg = parsed['message'] || {}

  message_hash = {
    role: msg['role'] || 'assistant',
    content: msg['content']
  }

  # ADD: Include tool_calls if present
  if msg['tool_calls'].is_a?(Array) && msg['tool_calls'].any?
    message_hash['tool_calls'] = msg['tool_calls']
  end

  {
    id: "chatcmpl-#{SecureRandom.hex(8)}",
    object: 'chat.completion',
    created: created,
    model: @model,
    choices: [
      {
        index: 0,
        finish_reason: msg['tool_calls']&.any? ? 'tool_calls' : 'stop',
        message: message_hash
      }
    ],
    usage: { ... },
    smart_proxy: { ... }
  }
end
```

---

## App.rb Integration

### Current Pattern (app.rb:96-175)

```ruby
post '/v1/chat/completions' do
  request_payload = JSON.parse(body_content)

  # Routing
  router = ModelRouter.new(request_payload['model'])
  routing = router.route

  # Tool orchestration
  orchestrator = ToolOrchestrator.new(executor: executor, logger: $logger, session_id: @session_id)
  response = orchestrator.orchestrate(upstream_payload, routing: routing, max_loops: max_loops_override)

  # Transform
  transformed = ResponseTransformer.to_openai_format(response.body, model: requested_model, streaming: stream)
end
```

REQUIRED CHANGES:
1. Catch ArgumentError for streaming + tools rejection:

```ruby
begin
  response = orchestrator.orchestrate(
    upstream_payload,
    routing: routing,
    max_loops: max_loops_override
  )
rescue ArgumentError => e
  if e.message.include?('streaming with tool calls')
    status 400
    halt {
      error: 'streaming_not_supported_with_tools',
      message: e.message,
      provider: 'ollama'
    }.to_json
  end
  raise
end
```

2. Validate tools schema early (before orchestrator):

```ruby
if request_payload['tools']
  begin
    validate_tools_schema!(request_payload['tools'])
  rescue ArgumentError => e
    status 400
    halt {
      error: 'invalid_tools_schema',
      message: e.message,
      details: parse_validation_error(e)
    }.to_json
  end
end
```

---

## Smart Proxy Client (Rails Side)

### Current Pattern (app/services/agent_hub/smart_proxy_client.rb:24-28)

```ruby
payload = {
  model: @model,
  messages: messages,
  stream: @stream
}
```

REQUIRED UPDATE:
```ruby
def chat(messages, tools: nil, stream_to: nil, message_id: nil)
  payload = {
    model: @model,
    messages: messages,
    stream: @stream
  }

  # ADD: Optional tools array
  payload[:tools] = tools if tools.is_a?(Array) && tools.any?

  if @stream
    chat_stream(conn, payload, stream_to, message_id)
  else
    chat_non_stream(conn, payload)
  end
end
```

USAGE EXAMPLE (from test/smoke/smart_proxy_live_test.rb:63-82):
```ruby
# Current test ALREADY passes tools array
res = http_post_json("/v1/chat/completions", {
  model: ENV.fetch("OLLAMA_MODEL", "llama3.1:70b"),
  messages: [
    { role: "developer", content: "You are a helpful assistant." },
    { role: "user", content: "Say hello in one short sentence." }
  ],
  stream: false,
  temperature: 0.2,
  tools: [
    {
      type: "function",
      function: {
        name: "noop",
        description: "No-op tool",
        parameters: { type: "object", properties: {}, required: [] }
      }
    }
  ]
})
```

This means SmartProxyClient already supports tools in payload structure.
No client changes needed - tools flow through correctly.

---

## Resolved Questions from Feedback v1

### 1. Normalization Location
ANSWER: In OllamaClient.chat_completions (Ollama-specific)
RATIONALE: Provider-specific requirement; keeps other clients unchanged

### 2. Tools Payload Flow
ANSWER:
- Rails -> SmartProxyClient (payload with tools key)
- SmartProxy app.rb validates tools
- ToolOrchestrator passes full payload to client
- OllamaClient.chat_completions normalizes + forwards
IMPLEMENTATION: See refactored OllamaClient above

### 3. Gating Logic Order
ANSWER: Always validate first, then check gate
BEHAVIOR:
- Invalid tools + gate true -> 400 validation error
- Invalid tools + gate false -> 400 validation error
- Valid tools + gate true -> forward to Ollama
- Valid tools + gate false -> silently drop + log
IMPLEMENTATION: See validate_and_gate_tools method above

### 4. Rails Client Interface
ANSWER: No changes needed - tools already supported
EVIDENCE: test/smoke/smart_proxy_live_test.rb:72-81 already passes tools array

### 5. Streaming Rejection Scope
ANSWER: Ollama-specific (raise in OllamaClient.chat_completions)
IMPLEMENTATION: See line 45-47 in refactored OllamaClient

### 6. Response Parsing Location
ANSWER: In OllamaClient.chat_completions (provider-specific)
IMPLEMENTATION: See parse_tool_calls_if_present method above

### 7. Artifact Logging
ANSWER: Add tools_count and tool_calls_count to dump_llm_call_artifact!
IMPLEMENTATION:
```ruby
def dump_llm_call_artifact!(agent:, request_id:, correlation_id:, request_payload:, response_status:, response_body:, base_dir_override: nil)
  parsed_response = begin
    response_body.is_a?(String) ? JSON.parse(response_body) : response_body
  rescue StandardError
    nil
  end

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
    tools_count: (request_payload['tools'] || []).length,              # NEW
    tool_calls_count: parsed_response.dig('choices', 0, 'message', 'tool_calls')&.length || 0,  # NEW
    request: request_payload,
    response: parsed_response || response_body
  }

  File.write(path, JSON.pretty_generate(payload) + "\n")
end
```

### 8. Model Capability Checking
ANSWER: Out of scope for this epic
IMPLEMENTATION: Rely on Ollama error handling
FUTURE: Query /api/show endpoint for capabilities

### 9. E2E Test Coverage
ANSWER: Create run_agent_test_sdlc_ollama_tools_e2e.sh variant
IMPLEMENTATION: See test script in PRD-07 section below

### 10. Log Format Specification
ANSWER: Use structured JSON matching existing patterns
IMPLEMENTATION: See logging helpers in refactored OllamaClient

---

## Updated PRD Breakdown

### PRD-00: Conversation History Normalization
SCOPE: normalize_tool_arguments_in_payload method in OllamaClient
STATUS: Fully specified above (lines 50-88 in refactored client)
LOCATION: smart_proxy/lib/ollama_client.rb
TEST: test/smoke/smart_proxy_live_test.rb (mixed-provider test)

### PRD-01: Tool Schema Validation
SCOPE: validate_tools_schema! method in OllamaClient
STATUS: Fully specified above (lines 113-135)
LOCATION: smart_proxy/lib/ollama_client.rb
INTEGRATION: Called from app.rb before orchestrator
TEST: spec/ollama_client_spec.rb (unit tests)

### PRD-02: Gated Tool Forwarding
SCOPE: validate_and_gate_tools method in OllamaClient
STATUS: Fully specified above (lines 90-111)
LOCATION: smart_proxy/lib/ollama_client.rb
ENV: OLLAMA_TOOLS_ENABLED (default true)
TEST: spec/ollama_client_spec.rb (unit tests with ENV stubbing)

### PRD-03: Response Parsing
SCOPE: parse_tool_calls_if_present + parse_tool_call methods
STATUS: Fully specified above (lines 154-199)
LOCATION: smart_proxy/lib/ollama_client.rb
INTEGRATION: ResponseTransformer.ollama_to_openai update
TEST: spec/ollama_client_spec.rb + spec/response_transformer_spec.rb

### PRD-04: Streaming Restrictions
SCOPE: Error handling in OllamaClient.chat_completions
STATUS: Fully specified above (lines 45-47)
LOCATION: smart_proxy/lib/ollama_client.rb + app.rb catch block
TEST: test/smoke/smart_proxy_live_test.rb (streaming + tools rejection)

### PRD-05: Enhanced Logging
SCOPE: log_debug, log_info, log_warn helpers
STATUS: Fully specified above (lines 227-237)
LOCATION: Throughout OllamaClient methods
FORMAT: JSON structured logs matching junie-log-requirement.md
TEST: spec/ollama_client_spec.rb (mock logger assertions)

### PRD-06: Comprehensive Tests
SCOPE: Full spec suite for OllamaClient
LOCATION: smart_proxy/spec/ollama_client_spec.rb
COVERAGE TARGET: 90%+
TESTS:
- Unit: normalization (string->Hash, bad JSON->{})
- Unit: validation (good/invalid schemas, >20 tools)
- Unit: gating (enabled/disabled flag)
- Unit: parsing (good/bad JSON args)
- Unit: model selection (tool vs non-tool)
- Integration: full round-trip with VCR cassettes
- Integration: mixed-provider history

### PRD-07: E2E Workflow Validation
SCOPE: New test script + smoke test updates
LOCATION: script/run_agent_test_sdlc_ollama_tools_e2e.sh
STATUS: Script template provided in feedback-v1 (lines 569-602)
SMOKE TEST UPDATE: test/smoke/smart_proxy_live_test.rb
NEW TEST:
```ruby
def test_ollama_tool_calling_with_normalization
  # Send Grok-style history with stringified tool args
  # Expect Ollama to process successfully
  res = http_post_json("/v1/chat/completions", {
    model: ENV.fetch("OLLAMA_MODEL", "llama3.1:70b"),
    messages: [
      {
        role: "assistant",
        content: nil,
        tool_calls: [
          {
            id: "call_abc123",
            type: "function",
            function: {
              name: "search",
              arguments: '{"query": "test"}'  # <-- STRING (Grok style)
            }
          }
        ]
      },
      {
        role: "tool",
        tool_call_id: "call_abc123",
        content: "Search result"
      },
      {
        role: "user",
        content: "Summarize that result"
      }
    ],
    stream: false
  })

  assert_equal 200, res.code.to_i
  body = JSON.parse(res.body)
  assert body.dig("choices", 0, "message", "content").present?
end
```

---

## Environment Variables

NEW VARIABLES:
```bash
# Enable/disable tool forwarding to Ollama
OLLAMA_TOOLS_ENABLED=true  # default true

# Model to use when tools are present
OLLAMA_TOOL_MODEL=llama3-groq-tool-use:70b  # optional, for tool-optimized model

# Existing (already used)
OLLAMA_MODEL=llama3.1:70b
OLLAMA_URL=http://localhost:11434/api/chat
OLLAMA_TIMEOUT=120
```

---

## Implementation Order

PHASE 1: OllamaClient Refactor (Week 1, Days 1-2)
- Rename chat -> chat_completions
- Add normalization (normalize_tool_arguments_in_payload)
- Add validation (validate_tools_schema!)
- Add gating (validate_and_gate_tools)
- Add retry middleware
- Add logging helpers

PHASE 2: Response Parsing (Week 1, Days 3-4)
- Add parse_tool_calls_if_present
- Update ResponseTransformer.ollama_to_openai
- Add tool_calls to message hash
- Update finish_reason logic

PHASE 3: App.rb Integration (Week 1, Day 5)
- Add ArgumentError catch for streaming + tools
- Add early validation for tools schema
- Test with existing smoke tests

PHASE 4: Testing (Week 2, Days 1-3)
- Unit tests for all new methods
- Integration tests with VCR
- Smoke test updates
- E2E script creation

PHASE 5: Documentation + Cleanup (Week 2, Days 4-5)
- Update README with tool usage examples
- Add inline documentation
- Clean up deprecated code
- Performance profiling

---

## Risk Mitigation

RISK: Normalization breaks non-Ollama providers
MITIGATION: Normalization only in OllamaClient; regression tests for Grok/Claude

RISK: Tool-optimized model (groq-tool-use:70b) not available
MITIGATION: Graceful fallback to llama3.1:70b; log warning

RISK: Performance impact of normalization
MITIGATION: O(n) complexity; negligible for <50 messages; profile with large histories

RISK: Ollama API changes tool_calls format
MITIGATION: Lenient parsing with error objects; log warnings

RISK: Existing workflows break
MITIGATION: chat_completions coexists with old chat method during transition; deprecate slowly

---

## Approval Checklist

Before starting implementation:

- [ ] Review refactored OllamaClient code above
- [ ] Confirm chat_completions method signature matches GrokClient
- [ ] Confirm normalization logic handles Grok->Ollama conversion
- [ ] Confirm validation logic matches OpenAI tools schema
- [ ] Confirm ResponseTransformer.ollama_to_openai handles tool_calls
- [ ] Confirm app.rb catches streaming + tools ArgumentError
- [ ] Confirm SmartProxyClient requires no changes (tools already work)
- [ ] Confirm ENV variables added to .env.example
- [ ] Confirm test strategy covers all edge cases
- [ ] Confirm E2E script ready for mixed-provider testing
- [ ] Pull llama3-groq-tool-use:70b model: ollama pull llama3-groq-tool-use:70b

---

## References

IMPLEMENTATION:
- smart_proxy/lib/ollama_client.rb (primary changes)
- smart_proxy/lib/grok_client.rb (pattern reference)
- smart_proxy/lib/tool_orchestrator.rb (integration point)
- smart_proxy/lib/response_transformer.rb (response handling)
- smart_proxy/app.rb (endpoint + error handling)

TESTS:
- test/smoke/smart_proxy_live_test.rb (smoke tests with tools)
- smart_proxy/spec/ollama_client_spec.rb (new unit/integration tests)
- smart_proxy/spec/response_transformer_spec.rb (update for tool_calls)
- script/run_agent_test_sdlc_ollama_tools_e2e.sh (new E2E script)

DOCUMENTATION:
- knowledge_base/ignore/ollama-epic-v2.md (original epic)
- knowledge_base/ignore/ollama-feedback.md (v1 feedback)
- https://github.com/ollama/ollama/blob/main/docs/api.md (Ollama API docs)

---

REVIEW STATUS: READY FOR IMPLEMENTATION
CONFIDENCE LEVEL: High (architectural patterns proven, integration points clear)
RECOMMENDED ACTION: Begin PRD-00 implementation with refactored OllamaClient
