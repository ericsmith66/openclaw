# frozen_string_literal: true

require "faraday"
require "securerandom"
require "stringio"

module AgentDesk
  module Models
    # Thin HTTP client for OpenAI-compatible LLM endpoints.
    #
    # Sends POST requests to +/v1/chat/completions+ and normalizes responses
    # into a consistent hash. Supports streaming via SSE with block callbacks.
    #
    # @example Non-streaming
    #   manager = ModelManager.new(provider: :smart_proxy, api_key: "test")
    #   response = manager.chat(messages: [{ role: "user", content: "Hello" }])
    #   puts response[:content]
    #
    # @example Streaming
    #   manager.chat(messages: msgs) do |chunk|
    #     print chunk[:content]
    #   end
    class ModelManager
      # Provider presets: :openai, :smart_proxy, :custom
      # @return [Array<Symbol>] supported provider identifiers
      PROVIDERS = %i[openai smart_proxy custom].freeze

      # @return [Symbol] the configured provider
      attr_reader :provider

      # @return [String] the base URL for API requests
      attr_reader :base_url

      # @return [String] the model name
      attr_reader :model

      # @param provider [Symbol] one of :openai, :smart_proxy, :custom
      # @param api_key [String, nil] API key (required for :openai and :smart_proxy)
      # @param base_url [String, nil] override base URL (required for :custom)
      # @param model [String] model name (default: "gpt-4o-mini")
      # @param timeout [Integer] HTTP timeout in seconds (default: 120)
      # @raise [ConfigurationError] if required configuration is missing
      def initialize(provider:, api_key: nil, base_url: nil, model: "gpt-4o-mini", timeout: 120)
        @provider = provider
        @api_key = api_key
        @base_url = base_url || default_base_url(provider)
        @model = model
        @timeout = timeout
        @headers = build_headers(provider)
        validate_configuration!
      end

      # Sends a chat completion request to the configured LLM endpoint.
      #
      # @param messages [Array<Hash>] conversation messages in OpenAI format
      # @param tools [Array<Hash>, nil] tool definitions in OpenAI function calling format
      # @param temperature [Float, nil] sampling temperature
      # @param max_tokens [Integer, nil] maximum tokens in response
      # @yield [chunk] called for each streaming chunk when block is given
      # @yieldparam chunk [Hash] chunk with :type and :content keys
      # @return [Hash] normalized response with :role, :content, :tool_calls, :usage keys
      # @raise [ConfigurationError] if configuration is invalid
      # @raise [LLMError] if the endpoint returns an error or malformed response
      # @raise [TimeoutError] if the request exceeds the configured timeout
      # @raise [StreamError] if the SSE stream is interrupted (streaming only)
      def chat(messages:, tools: nil, temperature: nil, max_tokens: nil, &block)
        body = { model: @model, messages: messages }
        body[:tools] = tools if tools
        body[:temperature] = temperature if temperature
        body[:max_tokens] = max_tokens if max_tokens

        # Stream only when a block is given AND no tools are present.
        # Ollama (and some other providers) do not support streaming with tool calls.
        use_streaming = block_given? && !tools

        if use_streaming
          body[:stream] = true
          stream_request(body, &block)
        else
          response = request(body)
          # When a block was given but streaming was skipped (tools present),
          # simulate a single chunk callback so callers still receive the content.
          if block_given? && response[:content]
            block.call({ type: "chunk", content: response[:content] })
          end
          response
        end
      end

      private

      def default_base_url(provider)
        case provider
        when :openai      then "https://api.openai.com"
        when :smart_proxy then "http://localhost:4567"
          # :custom requires explicit base_url
        end
      end

      def build_headers(provider)
        headers = { "Content-Type" => "application/json" }
        headers["Authorization"] = "Bearer #{@api_key}" if @api_key
        if provider == :smart_proxy
          headers["X-Agent-Name"] = "agent_desk"
          headers["X-Correlation-ID"] = SecureRandom.uuid
          headers["X-LLM-Base-Dir"] = Dir.pwd
        end
        headers
      end

      def validate_configuration!
        unless PROVIDERS.include?(@provider)
          raise ConfigurationError,
                "Provider '#{@provider}' not configured. Must be one of: #{PROVIDERS.join(", ")}"
        end
        if %i[openai smart_proxy].include?(@provider) && (@api_key.nil? || @api_key.empty?)
          raise ConfigurationError, "api_key is required for provider :#{@provider}"
        end
        return unless @provider == :custom && @base_url.nil?

        raise ConfigurationError, "base_url is required for provider :custom"
      end

      def faraday_connection
        @faraday_connection ||= Faraday.new(
          url: @base_url,
          request: { timeout: @timeout }
        ) do |conn|
          conn.adapter Faraday.default_adapter
        end
      end

      def request(body)
        normalized = normalize_body(body)

        # Debug logging for 400 errors
        if ENV["DEBUG_AGENT_DESK"]
          warn "[AgentDesk] Request body: #{normalized.to_json[0..500]}"
        end

        response = faraday_connection.post("/v1/chat/completions") do |req|
          req.headers = @headers
          req.body = normalized.to_json
        end
        handle_response(response)
      rescue Faraday::TimeoutError
        raise TimeoutError, "Request timed out after #{@timeout} seconds"
      rescue Faraday::ConnectionFailed, Faraday::SSLError => e
        raise LLMError.new("Network error: #{e.message}")
      rescue JSON::ParserError => e
        raise LLMError.new("Malformed JSON response", response_body: e.message)
      end

      def stream_request(body, &block)
        response = faraday_connection.post("/v1/chat/completions") do |req|
          req.headers = @headers
          req.body = normalize_body(body).to_json
          # We read the entire response body as a string then parse SSE lines.
          # Real-time streaming would require stream_body: true with an on_data callback.
        end
        handle_stream_response(response, &block)
      rescue Faraday::TimeoutError
        raise TimeoutError, "Request timed out after #{@timeout} seconds"
      rescue Faraday::ConnectionFailed, Faraday::SSLError => e
        raise LLMError.new("Network error: #{e.message}")
      rescue JSON::ParserError => e
        raise LLMError.new("Malformed JSON response", response_body: e.message)
      end

      def handle_response(response)
        if response.status >= 400
          # Parse error details for debugging
          error_details = begin
            JSON.parse(response.body)
          rescue JSON::ParserError
            response.body
          end

          warn "[AgentDesk] 400 Error Details: #{error_details.inspect}"

          raise LLMError.new(
            "LLM endpoint returned #{response.status}",
            status: response.status,
            response_body: response.body
          )
        end
        parsed = JSON.parse(response.body)
        ResponseNormalizer.normalize(parsed)
      end

      def handle_stream_response(response, &block)
        if response.status >= 400
          raise LLMError.new(
            "LLM endpoint returned #{response.status}",
            status: response.status,
            response_body: response.body
          )
        end
        # Create an IO-like object from the response body string
        io = StringIO.new(response.body)
        SSEParser.parse(io, &block)
      end

      # Normalize the request body before JSON serialization.
      # Converts symbol-keyed message hashes to string keys and ensures
      # tool_call arguments are JSON strings (not Ruby Hashes), as required
      # by the OpenAI API specification.
      #
      # @param body [Hash] request body
      # @return [Hash] normalized body safe for JSON serialization
      def normalize_body(body)
        return body unless body[:messages]

        normalized = body.dup
        normalized[:messages] = body[:messages].map { |msg| normalize_message(msg) }
        normalized
      end

      # Normalize a single conversation message for API serialization.
      #
      # @param msg [Hash] message hash (may have symbol or string keys)
      # @return [Hash] string-keyed message with serialized tool_call arguments
      def normalize_message(msg)
        out = {}
        msg.each do |k, v|
          key = k.to_s
          if key == "tool_calls" && v.is_a?(Array)
            out[key] = v.map { |tc| normalize_tool_call(tc) }
          elsif !v.nil?
            # Skip nil values to avoid "key": null in JSON, which some providers
            # (e.g., Anthropic opus-4-6, sonnet-4-6) reject with 400 errors
            out[key] = v
          end
        end
        out
      end

      # Normalize a tool_call hash, ensuring arguments is a JSON string.
      #
      # @param tc [Hash] tool call hash
      # @return [Hash] normalized tool call with string arguments
      def normalize_tool_call(tc)
        out = {}
        tc.each do |k, v|
          key = k.to_s
          if key == "function" && v.is_a?(Hash)
            func = {}
            v.each do |fk, fv|
              fkey = fk.to_s
              if fkey == "arguments" && fv.is_a?(Hash)
                func[fkey] = fv.to_json
              else
                func[fkey] = fv
              end
            end
            out[key] = func
          else
            out[key] = v
          end
        end
        out
      end
    end
  end
end
