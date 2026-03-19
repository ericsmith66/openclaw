require "faraday"
require "json"

module AgentHub
  class SmartProxyClient
    DEFAULT_TIMEOUT = 300
    KEEPALIVE_INTERVAL_SECONDS = 10

    def initialize(model: nil, stream: true)
      @model = model || ENV.fetch("AI_DEV_MODEL", "llama3.1:8b")
      @stream = stream
      @base_url = Agents.configuration.openai_api_base if defined?(Agents) && Agents.respond_to?(:configuration)
      @base_url ||= ENV.fetch("OPENAI_API_BASE", "http://localhost:11434/v1")
      @api_key = Agents.configuration.openai_api_key if defined?(Agents) && Agents.respond_to?(:configuration)
      @api_key ||= ENV.fetch("OPENAI_API_KEY", "ollama")
    end

    # @param stream_to [String, nil] legacy AgentHub stream id (will broadcast to "agent_hub_channel_#{stream_to}")
    # @param broadcast_stream [String, nil] full ActionCable stream name to broadcast tokens to (preferred for new channels)
    def chat(messages, stream_to: nil, message_id: nil, broadcast_stream: nil)
      conn = Faraday.new(url: @base_url) do |f|
        f.request :json
        f.options.timeout = DEFAULT_TIMEOUT
        f.options.open_timeout = 10
      end

      payload = {
        model: @model,
        messages: messages,
        stream: @stream
      }

      if @stream
        chat_stream(conn, payload, stream_to, message_id, broadcast_stream)
      else
        chat_non_stream(conn, payload)
      end
    rescue Faraday::TimeoutError => e
      Rails.logger.error(JSON.generate({ event: "smart_proxy_timeout", model: @model, error: e.message }))
      { "error" => "Timeout after #{DEFAULT_TIMEOUT}s" }
    rescue StandardError => e
      Rails.logger.error(JSON.generate({ event: "smart_proxy_error", model: @model, error: e.message }))
      { "error" => e.message }
    end

    private

    def chat_non_stream(conn, payload)
      response = conn.post("chat/completions", payload) do |req|
        req.headers["Authorization"] = "Bearer #{@api_key}" if @api_key
      end
      JSON.parse(response.body)
    end

    def chat_stream(conn, payload, stream_to, message_id, broadcast_stream)
      full_content = ""
      last_error = nil
      response_is_sse = false
      captured_body = ""
      last_keepalive_at = nil

      response = conn.post("chat/completions", payload) do |req|
        req.headers["Authorization"] = "Bearer #{@api_key}" if @api_key
        req.options.on_data = Proc.new do |chunk, _overall_received_bytes|
          captured_body << chunk
          # Ollama/OpenAI stream format: data: {"choices": [{"delta": {"content": "..."}}]}
          chunk.split("\n").each do |line|
            next if line.strip.empty?
            next if line.strip == "data: [DONE]"

            if line.start_with?("data: ")
              response_is_sse = true
              begin
                data = JSON.parse(line.sub("data: ", ""))

                # If the provider is streaming tool calls or other non-content deltas, we may not
                # emit any `token` events for a long time. Send a throttled keepalive so the
                # ActionCable client can reset its local timeout and show "still working".
                if stream_to || broadcast_stream
                  last_keepalive_at = broadcast_keepalive(
                    stream_to: stream_to,
                    message_id: message_id,
                    broadcast_stream: broadcast_stream,
                    last_keepalive_at: last_keepalive_at
                  )
                end

                # Some providers stream tool/live-search deltas (e.g. `tool_calls`) or
                # send full message fragments under different keys. Be permissive.
                token = data.dig("choices", 0, "delta", "content") ||
                        data.dig("choices", 0, "message", "content") ||
                        data.dig("choices", 0, "delta", "text")

                if token && !token.empty?
                  full_content << token
                  broadcast_token(token, stream_to, message_id, broadcast_stream) if stream_to || broadcast_stream
                  next
                end

                # Capture errors surfaced in-stream.
                if data["error"].present?
                  last_error = data["error"].is_a?(Hash) ? (data["error"]["message"] || data["error"].to_s) : data["error"].to_s
                end

                # Ignore tool/live-search chunks, but remember we saw data.
              rescue JSON::ParserError => e
                Rails.logger.warn("Failed to parse stream chunk: #{e.message}")
              end
            end
          end
        end
      end

      if !response_is_sse && response.status >= 400
        begin
          error_data = JSON.parse(captured_body)
          return { "error" => error_data["error"] || "Status #{response.status}: #{captured_body}" }
        rescue JSON::ParserError
          return { "error" => "Status #{response.status}: #{captured_body}" }
        end
      end

      if full_content.blank?
        # If we streamed but got no assistant content, return a structured error so the caller can fail gracefully.
        message = last_error ? last_error.to_s.strip : ""
        message = "No assistant content received from model #{@model} (possible unsupported streaming schema)" if message.empty?
        return { "error" => message }
      end

      { "choices" => [ { "message" => { "role" => "assistant", "content" => full_content } } ] }
    end

    def broadcast_token(token, stream_to, message_id, broadcast_stream)
      # stream_to is the legacy AgentHub channel/stream ID.
      # broadcast_stream is a fully-qualified ActionCable stream name.
      payload = { type: "token", token: token, message_id: message_id }

      target = broadcast_stream.presence || "agent_hub_channel_#{stream_to}"
      ActionCable.server.broadcast(target, payload)
    end

    def broadcast_keepalive(stream_to:, message_id:, broadcast_stream:, last_keepalive_at:)
      now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      if last_keepalive_at && (now - last_keepalive_at) < KEEPALIVE_INTERVAL_SECONDS
        return last_keepalive_at
      end

      payload = { type: "keepalive", message_id: message_id }
      target = broadcast_stream.presence || "agent_hub_channel_#{stream_to}"
      ActionCable.server.broadcast(target, payload)
      now
    end
  end
end
