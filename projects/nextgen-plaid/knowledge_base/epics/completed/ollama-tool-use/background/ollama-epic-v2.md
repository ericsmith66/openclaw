# Epic: Implement Structured Tool Use in SmartProxy for Reliable Local AI Execution

Epic ID: EPIC-AH-OLLAMA-TOOL-USE
Priority: High
Status: Ready for Implementation
Version: 2.0 (Revised with architectural feedback)

---

## Epic Narrative

### Vision Context

SmartProxy is the thin, local OpenAI-compatible HTTP wrapper between the Rails
AiFinancialAdvisor service and on-premises Ollama (primarily Llama-family models).
The current modular structure separates provider clients (lib/ollama_client.rb,
lib/grok_client.rb, lib/claude_client.rb), endpoint handling (app.rb), external
tool/search abstractions (lib/tool_client.rb, lib/live_search.rb), and utilities
(lib/anonymizer.rb).

PROBLEM IDENTIFIED IN SPIKE:
During SDLC E2E work, we hit a critical interoperability issue when mixing
providers in one workflow:
- Grok/OpenAI-style assistant messages include tool_calls[].function.arguments
  as a JSON STRING
- Ollama /api/chat expects tool_calls[].function.arguments as a JSON OBJECT
- Without normalization, Ollama returns HTTP 400: "cannot unmarshal string into
  tool_calls.function.arguments"

This epic adds structured tool calling support to:
- Fix Ollama flakiness (inconsistent arg parsing, plain-text fallback, narration
  over execution)
- Enable reliable invocation of Python simulators (estate-tax.py, GRAT.py,
  monte_carlo.py)
- Support future SafeShellTool / ProjectSearchTool patterns
- Preserve local-only execution for HNW privacy

### Objectives

1. Normalize histories to eliminate 400 errors from string-vs-object tool arg
   mismatches
2. Validate, forward, and parse OpenAI-style tools in Ollama path
3. Select tool-optimized model (llama3-groq-tool-use:70b) for execution phases
4. Gate features, enforce non-streaming, add retries/logging
5. Achieve E2E success in mixed-provider workflows (Claude PRD gen -> Grok review
   -> Ollama execution)

### Architectural Approach

FOLLOW GROK CLIENT PATTERN:
The implementation will mirror the proven GrokClient structure found in
smart_proxy/lib/grok_client.rb:
- Method signature: chat_completions(payload) not chat(payload)
- Accept full payload including tools array
- Faraday with retry middleware
- Return OpenStruct with status and body
- Provider-specific transformations in client, not orchestrator

CORE CHANGES:
- lib/ollama_client.rb: normalization, validation, gating, parsing, retries
- lib/response_transformer.rb: handle tool_calls in ollama_to_openai method
- app.rb: early validation, ArgumentError catch for streaming + tools
- NO CHANGES to app/services/agent_hub/smart_proxy_client.rb (already supports
  tools in payload)

MODEL STRATEGY:
- Default: llama3.1:70b for planning/reasoning
- Tool-optimized: llama3-groq-tool-use:70b when tools present
  - Pull with: ollama pull llama3-groq-tool-use:70b
  - Q4_0 quantization, ~40-60 GB unified memory on M3 Ultra
  - 90%+ BFCL accuracy for function calling

INTEGRATION POINTS:
- ToolOrchestrator: Already checks client.respond_to?(:chat_completions)
- ResponseTransformer: Update ollama_to_openai to include tool_calls in message
- SmartProxyClient: No changes needed (test/smoke/smart_proxy_live_test.rb:63-82
  proves tools already work)

NON-FUNCTIONAL REQUIREMENTS:
- Local-only (localhost:11434)
- Max agent loop: 8
- Timeout per call: 120s (configurable via OLLAMA_TIMEOUT)
- Anonymized logs per junie-log-requirement.md
- 90%+ test coverage on new code

### End-State Capabilities

- Mixed-provider histories pass without errors
- Valid tools forwarded to Ollama; responses parsed to OpenAI format
- groq-tool-use model used for tool calls -> high obedience (90%+ BFCL accuracy)
- Full E2E script success with provider switching
- Comprehensive debug logs for troubleshooting
- No cloud calls; all local; secure for HNW financial simulations

---

## Environment Variables

NEW VARIABLES (add to .env.example):
```bash
# Enable/disable tool forwarding to Ollama (default: true)
OLLAMA_TOOLS_ENABLED=true

# Model to use when tools are present (optional, for tool-optimized model)
OLLAMA_TOOL_MODEL=llama3-groq-tool-use:70b
```

EXISTING VARIABLES (already used):
```bash
OLLAMA_MODEL=llama3.1:70b
OLLAMA_URL=http://localhost:11434/api/chat
OLLAMA_TIMEOUT=120
OLLAMA_TAGS_URL=http://localhost:11434/api/tags
```

---

## Implementation Reference: Refactored OllamaClient

This section provides the complete refactored OllamaClient code that implements
all PRD requirements. Use this as the reference implementation.

FILE: smart_proxy/lib/ollama_client.rb

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

  # PRIMARY METHOD: Match GrokClient pattern
  # Accepts full payload including tools, messages, model, stream
  def chat_completions(payload)
    # STEP 1: Normalize tool arguments (PRD-00)
    # Converts Grok/OpenAI string args -> Ollama object args
    normalized_payload = normalize_tool_arguments_in_payload(payload)

    # STEP 2: Validate and gate tools if present (PRD-01, PRD-02)
    if normalized_payload['tools']
      validated_tools = validate_and_gate_tools(normalized_payload['tools'])
      normalized_payload['tools'] = validated_tools
      normalized_payload.delete('tools') if validated_tools.nil?
    end

    # STEP 3: Select appropriate model based on tool presence (PRD-02)
    normalized_payload['model'] = select_model(
      normalized_payload['model'],
      has_tools: normalized_payload['tools']&.any?
    )

    # STEP 4: Enforce non-streaming for tools (PRD-04)
    if normalized_payload['stream'] == true && normalized_payload['tools']&.any?
      raise ArgumentError, "Ollama does not support streaming with tool calls"
    end

    # STEP 5: Ensure stream: false (Ollama API requirement)
    normalized_payload['stream'] = false

    # STEP 6: Make request with retry (PRD-02)
    resp = connection.post('') do |req|
      req.body = normalized_payload.to_json
    end

    # STEP 7: Parse and transform response (PRD-03)
    body = JSON.parse(resp.body)
    body = parse_tool_calls_if_present(body)

    OpenStruct.new(status: resp.status, body: body)
  rescue Faraday::Error => e
    handle_error(e)
  end

  private

  # PRD-00: NORMALIZATION
  # Handles Grok/OpenAI -> Ollama incompatibility
  # Converts tool_calls[].function.arguments from String -> Hash
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

  # PRD-01 + PRD-02: VALIDATION AND GATING
  # Always validate first (fail fast), then check gate
  def validate_and_gate_tools(tools)
    return nil unless tools.is_a?(Array)

    # Validate schema first (PRD-01)
    validate_tools_schema!(tools)

    # Check environment gate (PRD-02)
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

  # PRD-01: STRICT SCHEMA VALIDATION
  # Raises ArgumentError with path-specific error messages
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

  # PRD-02: MODEL SELECTION
  # Use tool-optimized model when appropriate
  def select_model(requested_model, has_tools:)
    env_model = ENV['OLLAMA_MODEL']
    env_model = nil if env_model.nil? || env_model.strip.empty?

    # If explicit model requested, use it
    return requested_model unless requested_model == 'ollama' || requested_model.nil?

    # Default: llama3.1:70b for general use
    default_model = env_model || 'llama3.1:70b'

    # If tools present, prefer groq-tool-use model if configured
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

  # PRD-03: RESPONSE PARSING
  # Convert Ollama tool_calls to OpenAI format
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

  # PRD-03: INDIVIDUAL TOOL CALL PARSING
  # Lenient: on parse fail, insert error object
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

  # PRD-05: LOGGING HELPERS
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

## Integration Changes

### ResponseTransformer Update

FILE: smart_proxy/lib/response_transformer.rb
METHOD: ollama_to_openai (line 122-159)

REQUIRED CHANGES:
```ruby
def ollama_to_openai(parsed)
  msg = parsed['message'] || {}
  created = begin
    Time.parse(parsed['created_at'].to_s).to_i
  rescue StandardError
    Time.now.to_i
  end

  prompt_tokens = parsed['prompt_eval_count'].to_i
  completion_tokens = parsed['eval_count'].to_i
  total_tokens = prompt_tokens + completion_tokens

  # BUILD MESSAGE HASH
  message_hash = {
    role: msg['role'] || 'assistant',
    content: msg['content']
  }

  # ADD: Include tool_calls if present (NEW)
  if msg['tool_calls'].is_a?(Array) && msg['tool_calls'].any?
    message_hash['tool_calls'] = msg['tool_calls']
  end

  {
    id: "chatcmpl-#{SecureRandom.hex(8)}",
    object: 'chat.completion',
    created: created,
    model: @model.to_s.empty? ? parsed['model'] : @model,
    choices: [
      {
        index: 0,
        finish_reason: msg['tool_calls']&.any? ? 'tool_calls' : 'stop',  # UPDATED
        message: message_hash  # UPDATED
      }
    ],
    usage: {
      prompt_tokens: prompt_tokens,
      completion_tokens: completion_tokens,
      total_tokens: total_tokens
    },
    smart_proxy: {
      tool_loop: { loop_count: 0, max_loops: Integer(ENV.fetch('SMART_PROXY_MAX_LOOPS', '3')) },
      tools_used: []
    }
  }
end
```

### App.rb Updates

FILE: smart_proxy/app.rb
LOCATION: post '/v1/chat/completions' (line 96-265)

REQUIRED CHANGES:

1. EARLY VALIDATION (add after line 135):
```ruby
# Validate tools schema early if present
if request_payload['tools']
  begin
    # Validation happens in OllamaClient, but we can add early check here
    # for consistency across providers
    validate_tools_schema!(request_payload['tools']) if routing[:use_ollama]
  rescue ArgumentError => e
    $logger.error({
      event: 'tools_validation_failed_early',
      session_id: @session_id,
      error: e.message
    })
    status 400
    halt {
      error: 'invalid_tools_schema',
      message: e.message,
      provider: 'ollama'
    }.to_json
  end
end
```

2. CATCH STREAMING + TOOLS ERROR (wrap orchestrate call, around line 170):
```ruby
begin
  response = orchestrator.orchestrate(
    upstream_payload,
    routing: routing,
    max_loops: max_loops_override
  )
rescue ArgumentError => e
  if e.message.include?('streaming with tool calls')
    $logger.warn({
      event: 'streaming_rejected_with_tools',
      session_id: @session_id,
      provider: 'ollama',
      error: e.message
    })
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

3. UPDATE ARTIFACT LOGGING (dump_llm_call_artifact! method, line 368):
```ruby
def dump_llm_call_artifact!(agent:, request_id:, correlation_id:, request_payload:, response_status:, response_body:, base_dir_override: nil)
  # ... existing code ...

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
    tools_count: (request_payload['tools'] || []).length,  # NEW
    tool_calls_count: parsed_response.dig('choices', 0, 'message', 'tool_calls')&.length || 0,  # NEW
    request: request_payload,
    response: parsed_response || response_body
  }

  # ... rest of method ...
end
```

NO CHANGES REQUIRED:
- app/services/agent_hub/smart_proxy_client.rb (already supports tools)
- smart_proxy/lib/tool_orchestrator.rb (already checks respond_to?(:chat_completions))

---

## Atomic PRDs (Implementation Order)

### PRD-AH-OLLAMA-TOOL-00: Conversation History Normalization

OVERVIEW:
Prerequisite fix for spike failure. Ensure Ollama receives tool call arguments
as JSON objects (not strings) to prevent HTTP 400 unmarshal errors in mixed-
provider histories.

IMPLEMENTATION:
- Method: normalize_tool_arguments_in_payload in OllamaClient
- Location: Lines 68-108 in reference implementation above
- Called: STEP 1 in chat_completions method

REQUIREMENTS:
- Functional: Walk every message; for each tool_call.function.arguments: if
  String, JSON.parse -> replace with Hash if successful, or {} on failure
- Non-functional: O(n) on message count; log count of normalized calls
- Log format: {event: 'tool_arguments_normalized', count: N, provider: 'ollama'}

ACCEPTANCE CRITERIA:
- Grok/Claude-style history with string args -> Ollama payload has Hash objects
- Bad JSON args -> replaced with {} and logged
- Messages without tool_calls unchanged
- Regression test reproduces original 400 and shows fix
- Normalization runs before every Ollama call

TEST CASES:
- Unit (spec/ollama_client_spec.rb): Helper with string/Hash/bad JSON inputs
- Integration: Mock Ollama; assert payload sent with normalized args
- Smoke test: test/smoke/smart_proxy_live_test.rb (mixed-provider history)

LOG REQUIREMENTS:
Follow knowledge_base/prds/prds-junie-log/junie-log-requirement.md
Debug level: count of tool calls normalized

---

### PRD-AH-OLLAMA-TOOL-01: Tool Schema Acceptance and Validation

OVERVIEW:
Make /v1/chat/completions accept and strictly validate OpenAI-compatible tools
before forwarding.

IMPLEMENTATION:
- Method: validate_tools_schema! in OllamaClient
- Location: Lines 141-165 in reference implementation above
- Called: From validate_and_gate_tools (STEP 2)
- Also: Early validation in app.rb (optional, for consistency)

REQUIREMENTS:
- Functional: Validate type=="function", function.name present/non-empty,
  function.parameters object, max 20 tools
- Error handling: Raise ArgumentError with detailed path (e.g., "tools[2].function.name
  is required")
- Response: HTTP 400 JSON {error: "...", message: "...", provider: "ollama"}

ACCEPTANCE CRITERIA:
- Valid tools -> proceed to client
- Invalid fields -> 400 with path-specific error
- >20 tools -> 400
- No tools -> no validation error

TEST CASES:
- Unit: Validation helper specs (good/invalid cases)
- Integration: Sinatra endpoint tests (200 vs 400 responses)

LOG REQUIREMENTS:
Debug level: {event: 'tools_validated', count: N}
Error level: {event: 'tools_validation_failed', error: message, tools_sent: N}

---

### PRD-AH-OLLAMA-TOOL-02: Gated Tool Forwarding with Model Selector

OVERVIEW:
Conditionally forward validated tools to Ollama and select tool-optimized model.

IMPLEMENTATION:
- Method: validate_and_gate_tools in OllamaClient
- Location: Lines 110-139 in reference implementation above
- Method: select_model in OllamaClient
- Location: Lines 167-187 in reference implementation above
- Called: STEP 2 and STEP 3 in chat_completions

REQUIREMENTS:
- Functional: If ENV['OLLAMA_TOOLS_ENABLED']=="true" (default) and tools valid,
  include tools in payload
- Model selection: Use ENV['OLLAMA_TOOL_MODEL'] (e.g., llama3-groq-tool-use:70b)
  when tools present, else ENV['OLLAMA_MODEL'] or default llama3.1:70b
- Retry: 3x with exponential backoff (2s/5s) on 5xx/429 (Faraday middleware)
- Gate behavior: If flag false, silently drop tools and log

ACCEPTANCE CRITERIA:
- Tools + flag true -> tools in Ollama payload, groq-tool-use model selected
- Flag false -> tools dropped, logged, content-only
- Retries attempted on transient errors
- Model selection logged

TEST CASES:
- Unit: Payload builder with/without flag/tools
- Unit: Model selection logic (tools vs no-tools)
- Mock HTTP: Assert correct JSON payload and model
- Integration: Retry behavior with mocked 5xx responses

LOG REQUIREMENTS:
Info level: {event: 'tools_dropped_disabled', count: N, reason: '...'}
Debug level: {event: 'tools_forwarded', count: N, names: [...]}
Debug level: {event: 'model_selected_for_tools', model: '...', reason: 'tools_present'}

---

### PRD-AH-OLLAMA-TOOL-03: Ollama Tool Calls Parsing to OpenAI Format

OVERVIEW:
Convert Ollama tool call responses to consistent OpenAI-compatible format.

IMPLEMENTATION:
- Method: parse_tool_calls_if_present in OllamaClient
- Location: Lines 189-209 in reference implementation above
- Method: parse_tool_call in OllamaClient
- Location: Lines 211-244 in reference implementation above
- Called: STEP 7 in chat_completions
- Also: Update ResponseTransformer.ollama_to_openai (see Integration Changes)

REQUIREMENTS:
- Functional: If response.message.tool_calls exists, map each to OpenAI format:
  - id: "call_" + SecureRandom.hex(6)
  - type: "function"
  - name from function.name
  - arguments: JSON.parse(string) -> Hash (lenient: on fail {error:, raw:, parse_error:})
- Response transform: Include tool_calls in choices[0].message
- Finish reason: Set to 'tool_calls' if tool_calls present, else 'stop'

ACCEPTANCE CRITERIA:
- Valid args -> Hash in output
- Invalid JSON -> error object in args + logged
- No tool_calls -> nil/empty array
- ResponseTransformer includes tool_calls in message

TEST CASES:
- Unit: Parsing helper with good/bad JSON inputs
- Unit: ResponseTransformer.ollama_to_openai with tool_calls
- Integration: Full round-trip with mock Ollama response containing tool_calls

LOG REQUIREMENTS:
Debug level: {event: 'tool_calls_parsed_from_ollama', count: N, tool_calls: [...]}
Warn level: {event: 'tool_call_argument_parse_error', error: '...', raw: '...'}

---

### PRD-AH-OLLAMA-TOOL-04: Streaming Restrictions and Error Handling

OVERVIEW:
Prevent tool calls in streaming mode (Ollama limitation).

IMPLEMENTATION:
- Location: STEP 4 in OllamaClient.chat_completions (line 45-47)
- Error handling: Catch in app.rb orchestrate call (see Integration Changes)

REQUIREMENTS:
- Functional: If stream:true and tools present, raise ArgumentError before Ollama
  call
- Error message: "Ollama does not support streaming with tool calls"
- Response: HTTP 400 {error: 'streaming_not_supported_with_tools', message: '...',
  provider: 'ollama'}

ACCEPTANCE CRITERIA:
- Streaming + tools -> 400 rejection before Ollama call
- Streaming no tools -> proceeds normally
- Non-streaming + tools -> proceeds normally

TEST CASES:
- Integration: Endpoint rejects with correct error
- Unit: OllamaClient raises ArgumentError for streaming + tools

LOG REQUIREMENTS:
Warn level: {event: 'streaming_rejected_with_tools', session_id: '...', provider:
'ollama', error: '...'}

---

### PRD-AH-OLLAMA-TOOL-05: Enhanced Logging for Tool Flows

OVERVIEW:
Comprehensive debug logging across tool-related events.

IMPLEMENTATION:
- Methods: log_debug, log_info, log_warn in OllamaClient
- Location: Lines 275-283 in reference implementation above
- Used throughout: normalization, validation, gating, parsing methods
- Format: Follow knowledge_base/prds/prds-junie-log/junie-log-requirement.md

REQUIREMENTS:
- Functional: Log in ollama_client.rb: normalization count, validation result,
  forwarded/dropped count + names, parsed count/names/failures, model selected
- Anonymization: Via lib/anonymizer.rb (already applied to request_payload in
  app.rb)
- Levels:
  - DEBUG: tool_arguments_normalized, tools_validated, tools_forwarded,
    model_selected_for_tools, tool_calls_parsed_from_ollama
  - INFO: tools_dropped_disabled
  - WARN: tool_call_argument_parse_error, streaming_rejected_with_tools

ACCEPTANCE CRITERIA:
- All key events logged at appropriate level
- PII anonymized before logging (already handled by app.rb)
- Logs include session_id, correlation_id where available

TEST CASES:
- Mock Logger; assert expected log calls
- Integration: Verify logs appear in log/smart_proxy.log

LOG FORMAT EXAMPLES:
```json
{
  "timestamp": "2026-01-16T10:30:45Z",
  "severity": "DEBUG",
  "event": "tool_arguments_normalized",
  "count": 2,
  "provider": "ollama"
}

{
  "timestamp": "2026-01-16T10:30:46Z",
  "severity": "INFO",
  "event": "tools_forwarded",
  "count": 3,
  "names": ["search", "execute", "analyze"]
}

{
  "timestamp": "2026-01-16T10:30:47Z",
  "severity": "WARN",
  "event": "tool_call_argument_parse_error",
  "error": "unexpected token at 'invalid'",
  "raw": "invalid"
}
```

---

### PRD-AH-OLLAMA-TOOL-06: Comprehensive Tests and Acceptance Criteria

OVERVIEW:
Full regression and coverage suite for the tool refactor.

IMPLEMENTATION:
- Location: smart_proxy/spec/ollama_client_spec.rb (new file)
- Update: smart_proxy/spec/response_transformer_spec.rb
- Update: smart_proxy/spec/app_spec.rb
- Update: test/smoke/smart_proxy_live_test.rb

REQUIREMENTS:
- Functional: RSpec unit tests for normalization, validation, parsing, retries
- Integration: Full round-trip with VCR cassettes
- Flakiness sims: Mock parse errors, network timeouts
- Coverage target: 90%+ on new code

ACCEPTANCE CRITERIA:
- 90%+ coverage on new code
- Regression suite passes (existing tests green)
- Mixed-provider history test passes

TEST CASES:

UNIT TESTS (spec/ollama_client_spec.rb):
```ruby
describe OllamaClient do
  describe '#normalize_tool_arguments_in_payload' do
    it 'converts string arguments to hash'
    it 'handles bad JSON gracefully'
    it 'preserves hash arguments unchanged'
    it 'handles messages without tool_calls'
    it 'logs normalization count'
  end

  describe '#validate_tools_schema!' do
    it 'accepts valid tools array'
    it 'rejects tools without type function'
    it 'rejects tools without function name'
    it 'rejects tools without parameters object'
    it 'rejects more than 20 tools'
    it 'provides path-specific error messages'
  end

  describe '#validate_and_gate_tools' do
    it 'forwards tools when gate enabled'
    it 'drops tools when gate disabled'
    it 'logs appropriate events'
  end

  describe '#select_model' do
    it 'uses tool model when tools present'
    it 'uses default model when no tools'
    it 'respects explicit model requests'
  end

  describe '#parse_tool_calls_if_present' do
    it 'parses valid tool calls'
    it 'handles parse errors gracefully'
    it 'generates OpenAI-style IDs'
  end

  describe '#chat_completions' do
    it 'raises ArgumentError for streaming + tools'
    it 'retries on 5xx errors'
    it 'returns OpenStruct with status and body'
  end
end
```

INTEGRATION TESTS (spec/response_transformer_spec.rb):
```ruby
describe ResponseTransformer do
  describe '.ollama_to_openai' do
    it 'includes tool_calls in message when present'
    it 'sets finish_reason to tool_calls when present'
    it 'handles responses without tool_calls'
  end
end
```

SMOKE TESTS (test/smoke/smart_proxy_live_test.rb):
```ruby
# EXISTING TEST (already passes tools)
def test_chat_completions_ollama_style_with_tools_returns_choices_and_usage
  # ... existing test at line 63-92 ...
end

# NEW TEST (mixed-provider history)
def test_ollama_tool_calling_with_normalization
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
              arguments: '{"query": "test"}'  # STRING (Grok style)
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

# NEW TEST (streaming rejection)
def test_ollama_rejects_streaming_with_tools
  res = http_post_json("/v1/chat/completions", {
    model: ENV.fetch("OLLAMA_MODEL", "llama3.1:70b"),
    messages: [
      { role: "user", content: "Hello" }
    ],
    stream: true,
    tools: [
      {
        type: "function",
        function: {
          name: "noop",
          description: "No-op",
          parameters: { type: "object", properties: {}, required: [] }
        }
      }
    ]
  })

  assert_equal 400, res.code.to_i
  body = JSON.parse(res.body)
  assert_equal 'streaming_not_supported_with_tools', body['error']
end
```

---

### PRD-AH-OLLAMA-TOOL-07: Rails Client Integration and E2E Workflow Validation

OVERVIEW:
Ensure Rails application can pass conversation histories and tool schemas to
SmartProxy, and validate end-to-end mixed-provider workflows.

IMPLEMENTATION:
- NO CHANGES to app/services/agent_hub/smart_proxy_client.rb (already works)
- New E2E script: script/run_agent_test_sdlc_ollama_tools_e2e.sh
- Evidence: test/smoke/smart_proxy_live_test.rb:63-82 proves tools already work

REQUIREMENTS:
- Functional: SmartProxyClient correctly serializes full message history including
  tool_calls/tool_results and tools array
- E2E script: Test mixed-provider workflow (Grok -> Ollama with tool execution)
- No performance regression: <2s added latency per loop

ACCEPTANCE CRITERIA:
- SmartProxy client passes full history + tools without serialization errors
- Model selector respected: groq-tool-use used for tool-heavy requests
- E2E script completes successfully with mixed providers
- No unhandled exceptions in tool loop
- Logs show full trajectory (tool calls, results, model used)

E2E TEST SCRIPT:
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

TEST CASES:
- Manual E2E: Run script above; verify completion without HTTP 400
- Smoke test: Verify existing test still passes (no regression)
- Logs: Verify tool normalization and model selection events appear

---

## Implementation Schedule

PHASE 1: OllamaClient Refactor (Week 1, Days 1-2)
- PRD-00: Add normalize_tool_arguments_in_payload method
- PRD-01: Add validate_tools_schema! method
- PRD-02: Add validate_and_gate_tools and select_model methods
- Add Faraday retry middleware
- Add logging helpers
- Rename chat -> chat_completions

PHASE 2: Response Parsing (Week 1, Days 3-4)
- PRD-03: Add parse_tool_calls_if_present and parse_tool_call methods
- Update ResponseTransformer.ollama_to_openai
- PRD-04: Add streaming + tools check

PHASE 3: App.rb Integration (Week 1, Day 5)
- Add ArgumentError catch for streaming + tools
- Add early validation for tools schema
- Update dump_llm_call_artifact! with tools_count, tool_calls_count
- Test with existing smoke tests

PHASE 4: Testing (Week 2, Days 1-3)
- PRD-06: Unit tests for all new methods
- Integration tests with VCR
- Smoke test updates
- E2E script creation

PHASE 5: Documentation + Cleanup (Week 2, Days 4-5)
- PRD-07: E2E validation
- Update README with tool usage examples
- Add inline documentation
- Clean up deprecated code
- Performance profiling

---

## Risk Mitigation

RISK: Normalization breaks non-Ollama providers
MITIGATION: Normalization only in OllamaClient; regression tests for Grok/Claude
EVIDENCE: Grok tests in test/smoke/smart_proxy_live_test.rb:94-149

RISK: Tool-optimized model (groq-tool-use:70b) not available
MITIGATION: Graceful fallback to llama3.1:70b; log warning
CONFIG: OLLAMA_TOOL_MODEL is optional

RISK: Performance impact of normalization
MITIGATION: O(n) complexity; negligible for <50 messages; profile with large
histories
MEASUREMENT: Add timing logs in debug mode

RISK: Ollama API changes tool_calls format
MITIGATION: Lenient parsing with error objects; log warnings; version pinning
DOCUMENTATION: Track Ollama version in .tool-versions or README

RISK: Existing workflows break
MITIGATION: chat_completions coexists with old chat method during transition;
deprecate slowly
EVIDENCE: ToolOrchestrator already checks respond_to?(:chat_completions)

---

## Approval Checklist

Before starting implementation:

- [ ] Review refactored OllamaClient code (lines 15-283 above)
- [ ] Confirm chat_completions method signature matches GrokClient pattern
- [ ] Confirm normalization logic handles Grok->Ollama conversion
- [ ] Confirm validation logic matches OpenAI tools schema
- [ ] Confirm ResponseTransformer.ollama_to_openai handles tool_calls
- [ ] Confirm app.rb catches streaming + tools ArgumentError
- [ ] Confirm SmartProxyClient requires no changes (tools already work)
- [ ] Confirm ENV variables added to .env.example
- [ ] Confirm test strategy covers all edge cases
- [ ] Confirm E2E script ready for mixed-provider testing
- [ ] Pull llama3-groq-tool-use:70b model: ollama pull llama3-groq-tool-use:70b
- [ ] All 10 questions from feedback-v1 resolved (see ollama-feedback-v2.md)

---

## References

IMPLEMENTATION FILES:
- smart_proxy/lib/ollama_client.rb (primary changes)
- smart_proxy/lib/grok_client.rb (pattern reference)
- smart_proxy/lib/tool_orchestrator.rb (integration point - no changes needed)
- smart_proxy/lib/response_transformer.rb (response handling - update ollama_to_openai)
- smart_proxy/app.rb (endpoint + error handling - add validation and catch)

TEST FILES:
- test/smoke/smart_proxy_live_test.rb (smoke tests with tools)
- smart_proxy/spec/ollama_client_spec.rb (new unit/integration tests)
- smart_proxy/spec/response_transformer_spec.rb (update for tool_calls)
- script/run_agent_test_sdlc_ollama_tools_e2e.sh (new E2E script)

DOCUMENTATION:
- knowledge_base/ignore/ollama-feedback-v2.md (architectural analysis)
- https://github.com/ollama/ollama/blob/main/docs/api.md (Ollama API docs)
- knowledge_base/prds/prds-junie-log/junie-log-requirement.md (log format)

REVIEW STATUS: READY FOR IMPLEMENTATION
CONFIDENCE LEVEL: High (architectural patterns proven, integration points clear,
all questions resolved)
RECOMMENDED ACTION: Begin PRD-00 implementation with refactored OllamaClient
