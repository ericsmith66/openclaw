require 'faraday'
require 'faraday/retry'
require 'json'
require 'ostruct'

class OllamaClient
  DEFAULT_URL = 'http://localhost:11434/api/chat'
  DEFAULT_TAGS_URL = 'http://localhost:11434/api/tags'

  def initialize(url: nil, logger: nil)
    @url = url || ENV['OLLAMA_URL'] || DEFAULT_URL
    @logger = logger
  end

  def list_models
    resp = tags_connection.get('')
    body = resp.body.is_a?(String) ? JSON.parse(resp.body) : resp.body
    (body['models'] || []).map do |m|
      {
        id:          m['name'],
        object:      'model',
        owned_by:    'ollama',
        created:     (Time.parse(m['modified_at']).to_i rescue Time.now.to_i),
        smart_proxy: {
          provider: 'ollama',
          size:     m['size'],
          digest:   m['digest'],
          details:  m['details']
        }.compact
      }
    end
  rescue StandardError => e
    @logger&.warn({ event: 'ollama_list_models_error', error: e.message })
    []
  end

  def chat(payload)
    # Map Grok-style payload to Ollama-style if needed
    # Grok: { model: '...', messages: [...] }
    # Ollama: { model: '...', messages: [...], stream: false }

    env_model = ENV['OLLAMA_MODEL']
    env_model = nil if env_model.nil? || env_model.strip.empty?

    ollama_payload = {
      model: payload['model'] == 'ollama' ? (env_model || 'llama3.1:8b') : payload['model'],
      messages: payload['messages'],
      stream: false
    }

    connection.post('') do |req|
      req.body = ollama_payload.to_json
    end
  rescue Faraday::Error => e
    handle_error(e)
  end

  def chat_completions(payload)
    # Normalize tool_calls arguments from string to hash
    normalized_payload = normalize_tool_arguments_in_payload(payload)

    # Validate and gate tools if present
    if normalized_payload['tools']
      validated_tools = validate_and_gate_tools(normalized_payload['tools'])
      normalized_payload['tools'] = validated_tools
      normalized_payload.delete('tools') if validated_tools.nil?
    end

    # Select appropriate model based on tool presence
    selected_model = select_model(
      normalized_payload['model'],
      has_tools: normalized_payload['tools']&.any?
    )

    # STEP 4: Enforce non-streaming for tools (PRD-04)
    if normalized_payload['stream'] == true && normalized_payload['tools']&.any?
      raise ArgumentError, "Ollama does not support streaming with tool calls"
    end

    ollama_payload = {
      model: selected_model,
      messages: normalized_payload['messages'],
      stream: false
    }

    # Include tools if present
    ollama_payload[:tools] = normalized_payload['tools'] if normalized_payload['tools']

    resp = chat_connection.post('') do |req|
      req.body = ollama_payload.to_json
    end

    # Parse tool_calls in response if present
    body = JSON.parse(resp.body)
    body = parse_tool_calls_if_present(body)

    OpenStruct.new(status: resp.status, body: body.to_json)
  rescue Faraday::Error => e
    handle_error(e)
  end

  private

  def connection
    @connection ||= Faraday.new(url: @url) do |f|
      f.request :json
      f.options.timeout = ENV.fetch('OLLAMA_TIMEOUT', '120').to_i
      f.options.open_timeout = 10
      f.adapter Faraday.default_adapter
    end
  end

  def chat_connection
    @chat_connection ||= Faraday.new(url: @url) do |f|
      f.request :json
      f.options.timeout = ENV.fetch('OLLAMA_TIMEOUT', '120').to_i
      f.options.open_timeout = 10
      f.request :retry, {
        max: 3,
        interval: 2,
        interval_randomness: 0.5,
        backoff_factor: 2,
        retry_statuses: [ 429, 500, 502, 503, 504 ]
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
          'error' => 'invalid_json',
          'raw' => args,
          'parse_error' => e.message
        }
      end
    else
      args
    end

    {
      'id' => "call_#{SecureRandom.hex(6)}",
      'type' => "function",
      'function' => {
        'name' => ollama_tool_call.dig('function', 'name'),
        'arguments' => parsed_args
      }
    }
  end

  def log_debug(data)
    return unless @logger
    @logger.debug(data.to_json)
  end

  def log_info(data)
    return unless @logger
    @logger.info(data.to_json)
  end

  def log_warn(data)
    return unless @logger
    @logger.warn(data.to_json)
  end

  def handle_error(error)
    status = error.response ? error.response[:status] : 500
    body = error.response ? error.response[:body] : { error: error.message }

    OpenStruct.new(status: status, body: body)
  end
end
