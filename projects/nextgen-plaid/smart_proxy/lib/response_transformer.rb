require 'json'
require 'securerandom'
require 'time'

class ResponseTransformer
  def self.to_openai_format(response_body, model:, streaming: false)
    new(response_body, model: model, streaming: streaming).transform
  end

  def initialize(response_body, model:, streaming: false)
    @response_body = response_body
    @model = model
    @streaming = streaming
  end

  def transform
    raw_body = @response_body.to_s

    if @streaming
      return transform_to_sse(raw_body)
    end

    # Non-streaming
    if raw_body.lstrip.start_with?('data:')
      return { body: raw_body, content_type: 'text/event-stream' }
    end

    parsed = JSON.parse(raw_body) rescue nil

    if parsed.is_a?(Hash) && parsed.key?('choices')
      # Some providers (notably Ollama) may return tool_calls with empty content.
      # Ensure OpenAI-shaped responses always have a non-empty `message.content`.
      msg = parsed.dig('choices', 0, 'message')
      if msg.is_a?(Hash) && msg['content'].to_s.strip.empty? && msg['tool_calls'].is_a?(Array) && msg['tool_calls'].any?
        tool_names = msg['tool_calls'].map { |tc| tc.dig('function', 'name') }.compact
        hint = tool_names.any? ? tool_names.join(', ') : 'tool'
        msg['content'] = "(Tool call requested: #{hint})"
      end

      parsed['usage'] ||= { 'prompt_tokens' => 0, 'completion_tokens' => 0, 'total_tokens' => 0 }
      return { body: parsed.to_json, content_type: 'application/json' }
    end

    if parsed.is_a?(Hash) && parsed['message'].is_a?(Hash)
      return { body: ollama_to_openai(parsed).to_json, content_type: 'application/json' }
    end

    { body: raw_body, content_type: 'application/json' }
  end

  private

  def transform_to_sse(raw_body)
    if raw_body.lstrip.start_with?('data:')
      return { body: raw_body, content_type: 'text/event-stream' }
    end

    parsed = JSON.parse(raw_body) rescue nil

    if parsed.is_a?(Hash) && parsed.key?('choices')
      return { body: convert_openai_to_sse(parsed), content_type: 'text/event-stream' }
    end

    if parsed.is_a?(Hash) && parsed['message'].is_a?(Hash)
      return { body: convert_ollama_to_sse(parsed), content_type: 'text/event-stream' }
    end

    { body: raw_body, content_type: 'text/event-stream' }
  end

  def convert_openai_to_sse(parsed)
    msg = parsed.dig('choices', 0, 'message', 'content').to_s
    if msg.strip.empty?
      msg = "Sorry, I couldn't produce a response from the live-search model. Please try again or switch models."
    end
    chunk_id = parsed['id'] || "chatcmpl-#{SecureRandom.hex(8)}"
    created = parsed['created'].to_i
    created = Time.now.to_i if created <= 0
    stream_model = parsed['model'] || @model

    build_sse_chunks(chunk_id, created, stream_model, msg)
  end

  def convert_ollama_to_sse(parsed)
    msg = parsed.dig('message', 'content').to_s
    if msg.strip.empty?
      msg = "Sorry, I couldn't produce a response from the live-search model. Please try again or switch models."
    end
    created = begin
      Time.parse(parsed['created_at'].to_s).to_i
    rescue StandardError
      Time.now.to_i
    end
    stream_model = @model.empty? ? parsed['model'] : @model
    chunk_id = "chatcmpl-#{SecureRandom.hex(8)}"

    build_sse_chunks(chunk_id, created, stream_model, msg)
  end

  def build_sse_chunks(chunk_id, created, model, content)
    sse = +""
    sse << "data: #{ {
      id: chunk_id,
      object: 'chat.completion.chunk',
      created: created,
      model: model,
      choices: [
        {
          index: 0,
          delta: { role: 'assistant', content: content }
        }
      ]
    }.to_json }\n\n"
    sse << "data: #{ {
      id: chunk_id,
      object: 'chat.completion.chunk',
      created: created,
      model: model,
      choices: [
        {
          index: 0,
          delta: {},
          finish_reason: 'stop'
        }
      ]
    }.to_json }\n\n"
    sse << "data: [DONE]\n\n"
    sse
  end

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

    # Build message hash
    content = msg['content'].to_s
    message_hash = {
      role: msg['role'] || 'assistant',
      content: content
    }

    tool_calls = msg['tool_calls']

    # Include tool_calls if present
    if tool_calls.is_a?(Array) && tool_calls.any?
      message_hash['tool_calls'] = tool_calls

      # Ollama may return tool_calls with an empty assistant content. For OpenAI-shaped
      # responses we still want a non-empty `message.content` so callers/tests don't
      # treat it as a missing response.
      if message_hash[:content].to_s.strip.empty?
        tool_names = tool_calls.map { |tc| tc.dig('function', 'name') || tc.dig(:function, :name) }.compact
        tool_hint = tool_names.any? ? tool_names.join(', ') : 'tool'
        message_hash[:content] = "(Tool call requested: #{tool_hint})"
      end
    end

    # Set finish_reason based on tool_calls presence
    finish_reason = msg['tool_calls']&.any? ? 'tool_calls' : 'stop'

    {
      id: "chatcmpl-#{SecureRandom.hex(8)}",
      object: 'chat.completion',
      created: created,
      model: @model.to_s.empty? ? parsed['model'] : @model,
      choices: [
        {
          index: 0,
          finish_reason: finish_reason,
          message: message_hash
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
end
