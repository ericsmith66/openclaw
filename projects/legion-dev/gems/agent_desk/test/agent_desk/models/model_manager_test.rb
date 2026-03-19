# frozen_string_literal: true

require "test_helper"
require "faraday/adapter/test"

class ModelManagerTest < Minitest::Test
  def setup
    @stubs = Faraday::Adapter::Test::Stubs.new
    conn = Faraday.new do |builder|
      builder.adapter :test, @stubs
    end
    # Subclass overrides faraday_connection so the test adapter is used instead of a real socket.
    @manager_class = Class.new(AgentDesk::Models::ModelManager) do
      define_method(:faraday_connection) { conn }
    end
  end

  # ---------------------------------------------------------------------------
  # Initialization / configuration
  # ---------------------------------------------------------------------------

  def test_initializes_with_openai_preset
    manager = @manager_class.new(provider: :openai, api_key: "sk-test")
    assert_equal :openai, manager.provider
    assert_equal "https://api.openai.com", manager.base_url
  end

  def test_initializes_with_smart_proxy_preset
    manager = @manager_class.new(provider: :smart_proxy, api_key: "test")
    assert_equal :smart_proxy, manager.provider
    assert_equal "http://localhost:4567", manager.base_url
  end

  def test_initializes_with_custom_base_url
    manager = @manager_class.new(provider: :custom, api_key: nil, base_url: "https://custom.example.com")
    assert_equal :custom, manager.provider
    assert_equal "https://custom.example.com", manager.base_url
  end

  def test_initializes_with_custom_model_name
    manager = @manager_class.new(provider: :openai, api_key: "sk-test", model: "gpt-4o")
    assert_equal "gpt-4o", manager.model
  end

  def test_missing_api_key_for_openai_raises_configuration_error
    assert_raises AgentDesk::ConfigurationError do
      @manager_class.new(provider: :openai, api_key: nil)
    end
  end

  def test_missing_api_key_for_smart_proxy_raises_configuration_error
    assert_raises AgentDesk::ConfigurationError do
      @manager_class.new(provider: :smart_proxy, api_key: nil)
    end
  end

  def test_empty_api_key_for_openai_raises_configuration_error
    assert_raises AgentDesk::ConfigurationError do
      @manager_class.new(provider: :openai, api_key: "")
    end
  end

  def test_missing_base_url_for_custom_raises_configuration_error
    assert_raises AgentDesk::ConfigurationError do
      @manager_class.new(provider: :custom, api_key: nil)
    end
  end

  def test_unknown_provider_raises_configuration_error
    assert_raises AgentDesk::ConfigurationError do
      @manager_class.new(provider: :unknown, api_key: "test")
    end
  end

  def test_custom_provider_does_not_require_api_key
    # :custom only requires base_url; api_key is optional
    manager = @manager_class.new(provider: :custom, api_key: nil, base_url: "https://custom.example.com")
    assert_equal :custom, manager.provider
  end

  # ---------------------------------------------------------------------------
  # SmartProxy header injection (AC7)
  # ---------------------------------------------------------------------------

  def test_smart_proxy_headers_include_agent_name_and_correlation_id
    captured_headers = nil
    @stubs.post("/v1/chat/completions") do |env|
      captured_headers = env.request_headers
      [ 200, { "Content-Type" => "application/json" },
        '{"choices":[{"message":{"role":"assistant","content":"OK"}}]}' ]
    end
    @manager_class.new(provider: :smart_proxy, api_key: "proxy-key").chat(messages: [])
    assert_equal "agent_desk", captured_headers["X-Agent-Name"],
                 "SmartProxy requests must include X-Agent-Name header"
    assert_match(/\A[0-9a-f-]{36}\z/, captured_headers["X-Correlation-ID"],
                 "SmartProxy requests must include X-Correlation-ID UUID header")
    assert_equal Dir.pwd, captured_headers["X-LLM-Base-Dir"],
                 "SmartProxy requests must include X-LLM-Base-Dir header"
  end

  def test_openai_headers_do_not_include_smart_proxy_headers
    captured_headers = nil
    @stubs.post("/v1/chat/completions") do |env|
      captured_headers = env.request_headers
      [ 200, { "Content-Type" => "application/json" },
        '{"choices":[{"message":{"role":"assistant","content":"OK"}}]}' ]
    end
    @manager_class.new(provider: :openai, api_key: "sk-test").chat(messages: [])
    refute captured_headers.key?("X-Agent-Name"),    "OpenAI requests must NOT include X-Agent-Name"
    refute captured_headers.key?("X-Correlation-ID"), "OpenAI requests must NOT include X-Correlation-ID"
    refute captured_headers.key?("X-LLM-Base-Dir"),  "OpenAI requests must NOT include X-LLM-Base-Dir"
  end

  def test_custom_provider_does_not_include_smart_proxy_headers
    captured_headers = nil
    @stubs.post("/v1/chat/completions") do |env|
      captured_headers = env.request_headers
      [ 200, { "Content-Type" => "application/json" },
        '{"choices":[{"message":{"role":"assistant","content":"OK"}}]}' ]
    end
    @manager_class.new(provider: :custom, base_url: "https://custom.example.com").chat(messages: [])
    refute captured_headers.key?("X-Agent-Name"), "Custom provider must NOT include SmartProxy headers"
  end

  def test_smart_proxy_correlation_id_is_unique_per_instance
    ids = 5.times.map do
      @manager_class.new(provider: :smart_proxy, api_key: "key").instance_variable_get(:@headers)["X-Correlation-ID"]
    end
    assert_equal ids.uniq.size, ids.size, "Each ModelManager instance must have a unique X-Correlation-ID"
  end

  # ---------------------------------------------------------------------------
  # Request body construction
  # ---------------------------------------------------------------------------

  def test_chat_sends_post_to_v1_chat_completions
    @stubs.post("/v1/chat/completions") do |env|
      assert_equal "application/json", env.request_headers["Content-Type"]
      assert_equal "Bearer sk-test", env.request_headers["Authorization"]
      [ 200, { "Content-Type" => "application/json" },
        '{"choices":[{"message":{"role":"assistant","content":"Hello"}}]}' ]
    end
    manager = @manager_class.new(provider: :openai, api_key: "sk-test")
    manager.chat(messages: [ { role: "user", content: "Hi" } ])
    @stubs.verify_stubbed_calls
  end

  def test_chat_sends_correct_request_body
    captured_body = nil
    @stubs.post("/v1/chat/completions") do |env|
      captured_body = JSON.parse(env.body)
      [ 200, { "Content-Type" => "application/json" },
        '{"choices":[{"message":{"role":"assistant","content":"Hello"}}]}' ]
    end
    manager = @manager_class.new(provider: :openai, api_key: "sk-test")
    manager.chat(messages: [ { role: "user", content: "Hi" } ], tools: [], temperature: 0.7, max_tokens: 100)
    assert_equal "gpt-4o-mini", captured_body["model"]
    assert_equal [ { "role" => "user", "content" => "Hi" } ], captured_body["messages"]
    assert_equal [], captured_body["tools"]
    assert_equal 0.7, captured_body["temperature"]
    assert_equal 100, captured_body["max_tokens"]
    refute captured_body.key?("stream")
  end

  def test_chat_without_tools_omits_tools_key
    captured_body = nil
    @stubs.post("/v1/chat/completions") do |env|
      captured_body = JSON.parse(env.body)
      [ 200, { "Content-Type" => "application/json" },
        '{"choices":[{"message":{"role":"assistant","content":"Hello"}}]}' ]
    end
    manager = @manager_class.new(provider: :openai, api_key: "sk-test")
    manager.chat(messages: [])
    refute captured_body.key?("tools")
  end

  def test_chat_with_block_sets_stream_true
    captured_body = nil
    @stubs.post("/v1/chat/completions") do |env|
      captured_body = JSON.parse(env.body)
      [ 200, { "Content-Type" => "text/event-stream" }, "data: [DONE]\n\n" ]
    end
    manager = @manager_class.new(provider: :openai, api_key: "sk-test")
    manager.chat(messages: []) { |_chunk| }
    assert_equal true, captured_body["stream"]
  end

  def test_chat_without_block_omits_stream_key
    captured_body = nil
    @stubs.post("/v1/chat/completions") do |env|
      captured_body = JSON.parse(env.body)
      [ 200, { "Content-Type" => "application/json" },
        '{"choices":[{"message":{"role":"assistant","content":"Hello"}}]}' ]
    end
    manager = @manager_class.new(provider: :openai, api_key: "sk-test")
    manager.chat(messages: [])
    refute captured_body.key?("stream"), "Non-streaming request must not include stream key"
  end

  def test_chat_omits_nil_temperature
    captured_body = nil
    @stubs.post("/v1/chat/completions") do |env|
      captured_body = JSON.parse(env.body)
      [ 200, { "Content-Type" => "application/json" },
        '{"choices":[{"message":{"role":"assistant","content":"Hello"}}]}' ]
    end
    manager = @manager_class.new(provider: :openai, api_key: "sk-test")
    manager.chat(messages: [], temperature: nil)
    refute captured_body.key?("temperature")
  end

  def test_chat_omits_nil_max_tokens
    captured_body = nil
    @stubs.post("/v1/chat/completions") do |env|
      captured_body = JSON.parse(env.body)
      [ 200, { "Content-Type" => "application/json" },
        '{"choices":[{"message":{"role":"assistant","content":"Hello"}}]}' ]
    end
    manager = @manager_class.new(provider: :openai, api_key: "sk-test")
    manager.chat(messages: [], max_tokens: nil)
    refute captured_body.key?("max_tokens")
  end

  # ---------------------------------------------------------------------------
  # Response normalization
  # ---------------------------------------------------------------------------

  def test_chat_returns_normalized_response
    @stubs.post("/v1/chat/completions") do |_env|
      [ 200, { "Content-Type" => "application/json" }, '
        {
          "choices": [{
            "message": {
              "role": "assistant",
              "content": "Hello, world!",
              "tool_calls": [
                {
                  "id": "call_123",
                  "function": {
                    "name": "get_weather",
                    "arguments": "{\"city\": \"Boston\"}"
                  }
                }
              ]
            }
          }],
          "usage": {
            "prompt_tokens": 10,
            "completion_tokens": 20,
            "total_tokens": 30
          }
        }
      ' ]
    end
    manager = @manager_class.new(provider: :openai, api_key: "sk-test")
    response = manager.chat(messages: [])
    assert_equal "assistant", response[:role]
    assert_equal "Hello, world!", response[:content]
    assert_equal 1, response[:tool_calls].size
    assert_equal "call_123", response[:tool_calls].first[:id]
    assert_equal "get_weather", response[:tool_calls].first.dig(:function, :name)
    assert_equal({ "city" => "Boston" }, response[:tool_calls].first.dig(:function, :arguments))
    assert_equal({ prompt_tokens: 10, completion_tokens: 20, total_tokens: 30 }, response[:usage])
  end

  def test_chat_response_has_symbol_keys
    @stubs.post("/v1/chat/completions") do |_env|
      [ 200, { "Content-Type" => "application/json" },
        '{"choices":[{"message":{"role":"assistant","content":"Hi"}}]}' ]
    end
    manager = @manager_class.new(provider: :openai, api_key: "sk-test")
    response = manager.chat(messages: [])
    assert response.key?(:role),       "response must use symbol key :role"
    assert response.key?(:content),    "response must use symbol key :content"
    assert response.key?(:tool_calls), "response must use symbol key :tool_calls"
    assert response.key?(:usage),      "response must use symbol key :usage"
  end

  # ---------------------------------------------------------------------------
  # Streaming
  # ---------------------------------------------------------------------------

  def test_streaming_yields_content_chunks
    sse_data = <<~SSE
      data: {"choices":[{"delta":{"role":"assistant"}}]}
      data: {"choices":[{"delta":{"content":"Hello"}}]}
      data: {"choices":[{"delta":{"content":" world"}}]}
      data: [DONE]
    SSE
    @stubs.post("/v1/chat/completions") do |_env|
      [ 200, { "Content-Type" => "text/event-stream" }, sse_data ]
    end
    manager = @manager_class.new(provider: :openai, api_key: "sk-test")
    chunks = []
    response = manager.chat(messages: []) { |chunk| chunks << chunk }
    assert_equal 2, chunks.size
    assert_equal "Hello", chunks.first[:content]
    assert_equal " world", chunks.last[:content]
    assert_equal "assistant", response[:role]
    assert_equal "Hello world", response[:content]
  end

  def test_streaming_returns_full_accumulated_response
    sse_data = <<~SSE
      data: {"choices":[{"delta":{"role":"assistant"}}]}
      data: {"choices":[{"delta":{"content":"Part1"}}]}
      data: {"choices":[{"delta":{"content":"Part2"}}]}
      data: {"usage":{"prompt_tokens":5,"completion_tokens":10,"total_tokens":15}}
      data: [DONE]
    SSE
    @stubs.post("/v1/chat/completions") do |_env|
      [ 200, { "Content-Type" => "text/event-stream" }, sse_data ]
    end
    manager = @manager_class.new(provider: :openai, api_key: "sk-test")
    response = manager.chat(messages: []) { |_chunk| }
    assert_equal "Part1Part2", response[:content]
    assert_equal({ prompt_tokens: 5, completion_tokens: 10, total_tokens: 15 }, response[:usage])
  end

  # ---------------------------------------------------------------------------
  # Error handling
  # ---------------------------------------------------------------------------

  def test_http_timeout_raises_timeout_error
    manager = @manager_class.new(provider: :openai, api_key: "sk-test")
    manager.define_singleton_method(:faraday_connection) do
      raise Faraday::TimeoutError, "timeout"
    end
    assert_raises AgentDesk::TimeoutError do
      manager.chat(messages: [])
    end
  end

  def test_http_timeout_in_stream_raises_timeout_error
    manager = @manager_class.new(provider: :openai, api_key: "sk-test")
    manager.define_singleton_method(:faraday_connection) do
      raise Faraday::TimeoutError, "timeout"
    end
    assert_raises AgentDesk::TimeoutError do
      manager.chat(messages: []) { |_chunk| }
    end
  end

  def test_connection_failed_raises_llm_error
    manager = @manager_class.new(provider: :openai, api_key: "sk-test")
    manager.define_singleton_method(:faraday_connection) do
      raise Faraday::ConnectionFailed, "connection refused"
    end
    error = assert_raises AgentDesk::LLMError do
      manager.chat(messages: [])
    end
    assert_match "Network error", error.message
  end

  def test_non_200_response_raises_llm_error_with_status
    @stubs.post("/v1/chat/completions") do |_env|
      [ 400, { "Content-Type" => "application/json" }, '{"error": "Bad request"}' ]
    end
    manager = @manager_class.new(provider: :openai, api_key: "sk-test")
    error = assert_raises AgentDesk::LLMError do
      manager.chat(messages: [])
    end
    assert_equal 400, error.status
    assert_equal '{"error": "Bad request"}', error.response_body
  end

  def test_500_response_raises_llm_error
    @stubs.post("/v1/chat/completions") do |_env|
      [ 500, { "Content-Type" => "application/json" }, '{"error": "Internal error"}' ]
    end
    manager = @manager_class.new(provider: :openai, api_key: "sk-test")
    error = assert_raises AgentDesk::LLMError do
      manager.chat(messages: [])
    end
    assert_equal 500, error.status
  end

  def test_malformed_json_response_raises_llm_error
    @stubs.post("/v1/chat/completions") do |_env|
      [ 200, { "Content-Type" => "application/json" }, "not json" ]
    end
    manager = @manager_class.new(provider: :openai, api_key: "sk-test")
    assert_raises AgentDesk::LLMError do
      manager.chat(messages: [])
    end
  end

  # ---------------------------------------------------------------------------
  # StreamError — stream interruption detection (AC: StreamError raised)
  # ---------------------------------------------------------------------------

  def test_stream_interrupted_raises_stream_error_with_partial_content
    # Simulate a response that ends abruptly — no [DONE] sentinel
    sse_data = <<~SSE
      data: {"choices":[{"delta":{"role":"assistant"}}]}
      data: {"choices":[{"delta":{"content":"Hello"}}]}
    SSE
    @stubs.post("/v1/chat/completions") do |_env|
      [ 200, { "Content-Type" => "text/event-stream" }, sse_data ]
    end
    manager = @manager_class.new(provider: :openai, api_key: "sk-test")
    error = assert_raises AgentDesk::StreamError do
      manager.chat(messages: []) { |_chunk| }
    end
    assert_match "interrupted", error.message
    assert_equal "Hello", error.partial_content,
                 "StreamError must carry content accumulated before interruption"
  end

  def test_stream_interrupted_with_no_content_has_nil_partial_content
    # Stream ends with no [DONE] but also no content chunks received
    sse_data = "data: {\"choices\":[{\"delta\":{\"role\":\"assistant\"}}]}\n"
    @stubs.post("/v1/chat/completions") do |_env|
      [ 200, { "Content-Type" => "text/event-stream" }, sse_data ]
    end
    manager = @manager_class.new(provider: :openai, api_key: "sk-test")
    error = assert_raises AgentDesk::StreamError do
      manager.chat(messages: []) { |_chunk| }
    end
    assert_nil error.partial_content
  end

  def test_complete_stream_does_not_raise_stream_error
    sse_data = <<~SSE
      data: {"choices":[{"delta":{"role":"assistant"}}]}
      data: {"choices":[{"delta":{"content":"Hi"}}]}
      data: [DONE]
    SSE
    @stubs.post("/v1/chat/completions") do |_env|
      [ 200, { "Content-Type" => "text/event-stream" }, sse_data ]
    end
    manager = @manager_class.new(provider: :openai, api_key: "sk-test")
    # Must NOT raise StreamError
    response = manager.chat(messages: []) { |_chunk| }
    assert_equal "Hi", response[:content]
  end
end
