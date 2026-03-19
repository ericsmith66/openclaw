require 'faraday'
require 'faraday/retry'
require 'json'
require 'ostruct'

class ClaudeClient
  BASE_URL = 'https://api.anthropic.com/v1'

  def initialize(api_key:)
    @api_key = api_key
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
      Response.new(resp.status, parsed_body)
    end
  rescue Faraday::Error => e
    handle_error(e)
  end

  private

  def hget(hash, key)
    return nil unless hash.respond_to?(:[])
    hash[key.to_s] || hash[key.to_sym]
  end

  def normalize_content_for_claude(content)
    # Claude Messages API expects `content` to be an array of blocks.
    # Most of our callers provide OpenAI-style string content; wrap it.
    return [] if content.nil?

    return content if content.is_a?(Array)

    text = content.to_s
    return [] if text.strip.empty?

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
        system_parts << content.to_s
        next
      end

      # Claude Messages API only accepts `user` and `assistant` roles.
      next unless role == 'user' || role == 'assistant'

      other_messages << { role: role, content: normalize_content_for_claude(content) }
    end

    # Map OpenAI model names to Anthropic model names if necessary
    model = hget(payload, 'model')
    # If the user passed something like 'claude-3-5-sonnet-latest' or others not in the API list,
    # we could map them here, but for now we'll just use what's passed if it's already a valid id.
    # The tests were using claude-3-5-sonnet-20241022 which is NOT in the list from curl.

    system_text = system_parts.map(&:to_s).map(&:strip).reject(&:empty?).join("\n\n")

    {
      model: model,
      messages: other_messages,
      max_tokens: hget(payload, 'max_tokens') || 4096,
      system: system_text.empty? ? nil : system_text,
      temperature: hget(payload, 'temperature'),
      stream: hget(payload, 'stream') || false,
      tools: map_tools_to_claude(hget(payload, 'tools'))
    }.compact
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
      'usage' => {
        'prompt_tokens' => body.dig('usage', 'input_tokens'),
        'completion_tokens' => body.dig('usage', 'output_tokens'),
        'total_tokens' => body.dig('usage', 'input_tokens').to_i + body.dig('usage', 'output_tokens').to_i
      }
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
