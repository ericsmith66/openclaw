# Implementation Reference: Refactored OllamaClient

This document provides the complete refactored OllamaClient code that implements
all PRD requirements. Use this as the reference implementation.

VERSION: 3.0 (User-approved with incremental rollout)
LAST UPDATED: 2026-01-16

IMPORTANT NOTES:
- chat method is NOT deprecated - it coexists permanently with chat_completions
- chat_completions is for tool-aware requests
- chat remains for non-tool requests and backward compatibility
- Incremental rollout: Phase 1A adds normalization to existing chat method first

DEFERRED FEATURES (not in this implementation):
- Model availability check with caching (future enhancement)
- Semantic tool call validation (OLLAMA_VALIDATE_TOOL_REFS)
- Strict vs. lenient parsing modes (OLLAMA_STRICT_TOOL_PARSING)
- Middleware pattern for transformations

---

## Complete OllamaClient Code

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
    start_time = Time.now
    
    # STEP 1: Normalize tool arguments (PRD-00)
    # Converts Grok/OpenAI string args -> Ollama object args
    normalize_start = Time.now
    normalized_payload = normalize_tool_arguments_in_payload(payload)
    normalize_duration = Time.now - normalize_start

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
    request_start = Time.now
    resp = connection.post('') do |req|
      req.body = normalized_payload.to_json
    end
    request_duration = Time.now - request_start

    # STEP 7: Parse and transform response (PRD-03)
    body = JSON.parse(resp.body)
    body = parse_tool_calls_if_present(body)

    total_duration = Time.now - start_time
    
    # Performance monitoring
    log_debug(
      event: 'chat_completions_performance',
      total_ms: (total_duration * 1000).round(2),
      normalize_ms: (normalize_duration * 1000).round(2),
      request_ms: (request_duration * 1000).round(2),
      message_count: payload['messages']&.length || 0,
      tools_count: payload['tools']&.length || 0
    )

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
  # Raises ArgumentError with path-specific error messages and remediation hints
  def validate_tools_schema!(tools)
    unless tools.is_a?(Array)
      raise ArgumentError, "tools must be an array. Got: #{tools.class}"
    end
    
    if tools.length > 20
      raise ArgumentError, "maximum 20 tools allowed (got #{tools.length}). " \
                           "Consider splitting into multiple requests or reducing tool count."
    end

    tools.each_with_index do |tool, index|
      unless tool.is_a?(Hash) && tool['type'] == 'function'
        raise ArgumentError, "tools[#{index}].type must be 'function' (got: #{tool['type'].inspect}). " \
                             "Valid format: { type: 'function', function: { name: '...', parameters: {...} } }"
      end

      function = tool['function']
      unless function.is_a?(Hash)
        raise ArgumentError, "tools[#{index}].function must be an object (got: #{function.class}). " \
                             "Expected: { name: 'tool_name', description: '...', parameters: {...} }"
      end

      if function['name'].to_s.strip.empty?
        raise ArgumentError, "tools[#{index}].function.name is required and cannot be empty. " \
                             "Provide a unique identifier for this tool."
      end

      unless function['parameters'].is_a?(Hash)
        raise ArgumentError, "tools[#{index}].function.parameters must be an object (got: #{function['parameters'].class}). " \
                             "Expected JSON Schema format: { type: 'object', properties: {...}, required: [...] }"
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

#### 1. Early Validation (add after line 135)

```ruby
# Validate tools schema early if present
if request_payload['tools']
  begin
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

#### 2. Catch Streaming + Tools Error (wrap orchestrate call)

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

#### 3. Update Artifact Logging (dump_llm_call_artifact! method)

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

---

## No Changes Required

- app/services/agent_hub/smart_proxy_client.rb (already supports tools)
- smart_proxy/lib/tool_orchestrator.rb (already checks respond_to?(:chat_completions))

---

## Implementation Checklist

- [ ] Copy OllamaClient code to smart_proxy/lib/ollama_client.rb
- [ ] Update ResponseTransformer.ollama_to_openai method
- [ ] Add early validation in app.rb
- [ ] Add ArgumentError catch in app.rb
- [ ] Update dump_llm_call_artifact! in app.rb
- [ ] Add OLLAMA_TOOLS_ENABLED and OLLAMA_TOOL_MODEL to .env.example
- [ ] Pull llama3-groq-tool-use:70b model
- [ ] Run tests (unit, integration, smoke)
- [ ] Verify logs contain expected events
- [ ] Run E2E script
