require 'faraday'
require 'faraday/retry'
require 'json'
require 'ostruct'

class ClaudeClient
  BASE_URL = 'https://api.anthropic.com/v1'

  def initialize(api_key:, logger: nil)
    @api_key = api_key
    @logger = logger
  end

  def list_models
    response = connection.get('models')
    return models_from_env_fallback unless response.status == 200

    body = response.body.is_a?(String) ? JSON.parse(response.body) : response.body
    live = (body['data'] || [])
      .reject { |m| m['id'].to_s.end_with?('-with-live-search') }
      .map do |m|
        {
          id:          m['id'],
          object:      'model',
          owned_by:    'anthropic',
          created:     (Time.parse(m['created_at']).to_i rescue Time.now.to_i),
          smart_proxy: { provider: 'anthropic' }
        }
      end
    live.empty? ? models_from_env_fallback : live
  rescue Faraday::Error
    models_from_env_fallback
  rescue StandardError
    models_from_env_fallback
  end

  def chat(payload)
    # Map OpenAI-style payload to Claude-style
    # Claude uses /v1/messages

    claude_payload = map_to_claude(payload)

    resp = connection.post('messages') do |req|
      req.body = claude_payload.to_json
    end

    if resp.status == 200
      body = JSON.parse(resp.body)
      # Map back to OpenAI-style response
      mapped_body = map_from_claude(body, payload)
      Response.new(resp.status, mapped_body)
    else
      parsed_body = begin
                      JSON.parse(resp.body)
                    rescue StandardError
                      resp.body
                    end
      # Log error response body for debugging (especially 400s from malformed payloads)
      if resp.status >= 400
        $logger&.error({
          event: 'claude_api_error',
          status: resp.status,
          body: parsed_body,
          model: hget(payload, 'model'),
          message_count: (hget(payload, 'messages') || []).size
        })
      end
      Response.new(resp.status, parsed_body)
    end
  rescue Faraday::Error => e
    handle_error(e)
  end

  private

  def models_from_env_fallback
    str = ENV.fetch('ANTHROPIC_MODELS', '')
    return [] if str.empty?

    str.split(',').map(&:strip).reject(&:empty?).reject { |id| id.end_with?('-with-live-search') }.map do |model_id|
      {
        id:          model_id,
        object:      'model',
        owned_by:    'anthropic',
        created:     Time.now.to_i,
        smart_proxy: { provider: 'anthropic' }
      }
    end
  end

  def hget(hash, key)
    return nil unless hash.respond_to?(:[])
    hash[key.to_s] || hash[key.to_sym]
  end

  def normalize_content_for_claude(content)
    # Claude Messages API expects `content` to be a non-empty array of blocks
    # or a non-empty string. Anthropic returns 400 if content is [] or nil.
    return nil if content.nil?

    if content.is_a?(Array)
      # Filter out empty/nil blocks, but preserve blocks that carry cache_control
      # even if their text is empty (cache_control annotations must not be stripped).
      filtered = content.reject do |block|
        block.nil? ||
          (block.is_a?(Hash) &&
           block['text'].to_s.strip.empty? &&
           block['type'] == 'text' &&
           !block.key?('cache_control'))
      end
      return nil if filtered.empty?
      return filtered
    end

    text = content.to_s
    return nil if text.strip.empty?

    [ { type: 'text', text: text } ]
  end

  def connection
    @connection ||= Faraday.new(url: BASE_URL) do |f|
      f.request :json
      f.options.timeout = ENV.fetch('CLAUDE_TIMEOUT', '120').to_i
      f.options.open_timeout = 10
      f.request :retry, {
        max: 3,
        interval: 0.5,
        interval_randomness: 0.5,
        backoff_factor: 2,
        retry_statuses: [ 429, 500, 502, 503, 504 ]
      }
      f.headers['x-api-key'] = @api_key
      f.headers['anthropic-version'] = '2023-06-01'
      f.headers['content-type'] = 'application/json'
      f.adapter Faraday.default_adapter
    end
  end

  def map_to_claude(payload)
    messages = hget(payload, 'messages') || []

    # Anthropic doesn't support 'system' or 'developer' roles in the messages array.
    # Those must be provided via the top-level `system` parameter.
    system_parts = []
    other_messages = []

    messages.each do |m|
      role = hget(m, 'role').to_s
      content = hget(m, 'content')

      if role == 'system' || role == 'developer'
        # Preserve structured content blocks (including cache_control annotations)
        # instead of flattening to a plain string.
        if content.is_a?(Array)
          content.each do |block|
            if block.is_a?(Hash)
              system_parts << block
            elsif block.to_s.strip.length > 0
              system_parts << { 'type' => 'text', 'text' => block.to_s }
            end
          end
        elsif content.to_s.strip.length > 0
          system_parts << { 'type' => 'text', 'text' => content.to_s }
        end
        next
      end

      if role == 'assistant'
        tool_calls = hget(m, 'tool_calls')
        if tool_calls.is_a?(Array) && tool_calls.any?
          # Convert assistant message with tool_calls to Claude's tool_use content blocks.
          # Claude expects: { role: "assistant", content: [ {type: "tool_use", id:, name:, input:}, ... ] }
          blocks = []
          text = content.to_s.strip
          blocks << { type: 'text', text: text } unless text.empty?
          tool_calls.each do |tc|
            func = hget(tc, 'function') || {}
            args_raw = hget(func, 'arguments')
            input = if args_raw.is_a?(String)
                      begin; JSON.parse(args_raw); rescue StandardError; {}; end
            elsif args_raw.is_a?(Hash)
                      args_raw
            else
                      {}
            end
            blocks << {
              type: 'tool_use',
              id: hget(tc, 'id'),
              name: hget(func, 'name'),
              input: input
            }
          end
          other_messages << { role: 'assistant', content: blocks }
          next
        end

        normalized = normalize_content_for_claude(content)
        next if normalized.nil?
        other_messages << { role: 'assistant', content: normalized }
        next
      end

      if role == 'tool'
        # Convert OpenAI tool result messages to Claude's tool_result content blocks
        # within a user message. Multiple consecutive tool results are merged.
        tool_result_block = {
          type: 'tool_result',
          tool_use_id: hget(m, 'tool_call_id'),
          content: content.to_s
        }

        # Merge into previous user message if it only contains tool_result blocks
        if other_messages.last && other_messages.last[:role] == 'user' &&
           other_messages.last[:content].is_a?(Array) &&
           other_messages.last[:content].all? { |b| b.is_a?(Hash) && b[:type] == 'tool_result' }
          other_messages.last[:content] << tool_result_block
        else
          other_messages << { role: 'user', content: [ tool_result_block ] }
        end
        next
      end

      # Regular user messages
      next unless role == 'user'

      normalized = normalize_content_for_claude(content)
      next if normalized.nil?

      other_messages << { role: role, content: normalized }
    end

    # Map OpenAI model names to Anthropic model names if necessary
    model = hget(payload, 'model')
    # If the user passed something like 'claude-3-5-sonnet-latest' or others not in the API list,
    # we could map them here, but for now we'll just use what's passed if it's already a valid id.
    # The tests were using claude-3-5-sonnet-20241022 which is NOT in the list from curl.

    # Automatic prompt caching: inject top-level cache_control so Anthropic
    # caches the longest reusable prefix and advances the breakpoint as
    # conversations grow. The client's explicit cache_control takes precedence
    # if provided. Gated by CLAUDE_PROMPT_CACHING (default: true).
    cache_ctl = hget(payload, 'cache_control')
    if cache_ctl.nil? && prompt_caching_enabled?
      cache_ctl = { 'type' => 'ephemeral' }
    end

    {
      model: model,
      messages: other_messages,
      max_tokens: hget(payload, 'max_tokens') || 4096,
      system: system_parts.empty? ? nil : system_parts,
      cache_control: cache_ctl,
      temperature: hget(payload, 'temperature'),
      stream: hget(payload, 'stream') || false,
      tools: map_tools_to_claude(hget(payload, 'tools'))
    }.compact
  end

  def prompt_caching_enabled?
    ENV.fetch('CLAUDE_PROMPT_CACHING', 'true').downcase == 'true'
  end

  def map_tools_to_claude(tools)
    return nil if tools.nil? || tools.empty?

    tools.map do |t|
      next unless hget(t, 'type') == 'function'
      f = hget(t, 'function')
      {
        name: hget(f, 'name'),
        description: hget(f, 'description'),
        input_schema: hget(f, 'parameters')
      }
    end.compact
  end

  def map_from_claude(body, original_payload)
    # body is Anthropic format: { content: [{type: 'text', text: '...'}], usage: {...}, ... }

    text_content = body['content'].select { |c| c['type'] == 'text' }.map { |c| c['text'] }.join("\n")
    tool_calls = body['content'].select { |c| c['type'] == 'tool_use' }.map do |c|
      {
        'id' => c['id'],
        'type' => 'function',
        'function' => {
          'name' => c['name'],
          'arguments' => c['input'].to_json
        }
      }
    end

    cache_read     = body.dig('usage', 'cache_read_input_tokens')
    cache_creation = body.dig('usage', 'cache_creation_input_tokens')

    usage = {
      'prompt_tokens'     => body.dig('usage', 'input_tokens'),
      'completion_tokens' => body.dig('usage', 'output_tokens'),
      'total_tokens'      => body.dig('usage', 'input_tokens').to_i + body.dig('usage', 'output_tokens').to_i
    }

    cache_details = {}
    cache_details['cached_tokens']         = cache_read     if cache_read
    cache_details['cache_creation_tokens'] = cache_creation  if cache_creation
    usage['prompt_tokens_details'] = cache_details unless cache_details.empty?

    {
      'id' => body['id'],
      'object' => 'chat.completion',
      'created' => Time.now.to_i,
      'model' => body['model'],
      'choices' => [
        {
          'index' => 0,
          'message' => {
            'role' => 'assistant',
            'content' => text_content.empty? ? nil : text_content,
            'tool_calls' => tool_calls.empty? ? nil : tool_calls
          }.compact,
          'finish_reason' => map_finish_reason(body['stop_reason'])
        }
      ],
      'usage' => usage
    }
  end

  def map_finish_reason(reason)
    case reason
    when 'end_turn' then 'stop'
    when 'max_tokens' then 'length'
    when 'tool_use' then 'tool_calls'
    else reason
    end
  end

  def handle_error(error)
    status = error.response ? error.response[:status] : 500
    body = error.response ? error.response[:body] : { error: error.message }

    Response.new(status, body)
  end

  class Response
    attr_accessor :status, :body

    def initialize(status, body)
      @status = status
      @body = body
    end

    def success?
      status == 200
    end
  end
end
