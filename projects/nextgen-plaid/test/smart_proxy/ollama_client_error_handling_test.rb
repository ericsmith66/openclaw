# frozen_string_literal: true

require "test_helper"
require "faraday"
require "ostruct"

# Load OllamaClient directly (SmartProxy is a Sinatra app, not Rails)
require_relative "../../smart_proxy/lib/ollama_client"

# Tests for OllamaClient#handle_error — verifies correct HTTP status codes
# are returned for each error type. The old implementation fabricated 500 for
# ALL errors including timeouts, causing a retry storm that killed 88% of runs.
# See knowledge_base/epics/wip/epic-2-planning/500-ERROR-ROOT-CAUSE-AND-FIX.md
class OllamaClientErrorHandlingTest < Minitest::Test
  def setup
    @client = OllamaClient.new(url: "http://localhost:8765/v1/chat/completions")
  end

  # ---------------------------------------------------------------------------
  # handle_error — Faraday::TimeoutError → 504
  # ---------------------------------------------------------------------------

  def test_timeout_error_returns_504
    error = Faraday::TimeoutError.new("execution expired")
    result = @client.send(:handle_error, error)
    assert_equal 504, result.status
  end

  def test_timeout_error_body_includes_upstream_timeout_key
    error = Faraday::TimeoutError.new("execution expired")
    result = @client.send(:handle_error, error)
    body = JSON.parse(result.body)
    assert_equal "upstream_timeout", body["error"]
  end

  def test_timeout_error_body_is_retryable
    error = Faraday::TimeoutError.new("execution expired")
    result = @client.send(:handle_error, error)
    body = JSON.parse(result.body)
    assert_equal true, body["retryable"]
  end

  def test_timeout_error_body_includes_message
    error = Faraday::TimeoutError.new("execution expired")
    result = @client.send(:handle_error, error)
    body = JSON.parse(result.body)
    assert_equal "execution expired", body["message"]
  end

  # ---------------------------------------------------------------------------
  # handle_error — Faraday::ConnectionFailed → 503
  # ---------------------------------------------------------------------------

  def test_connection_failed_returns_503
    error = Faraday::ConnectionFailed.new("Connection refused - connect(2) for localhost port 8765")
    result = @client.send(:handle_error, error)
    assert_equal 503, result.status
  end

  def test_connection_failed_body_includes_connection_failed_key
    error = Faraday::ConnectionFailed.new("Connection refused")
    result = @client.send(:handle_error, error)
    body = JSON.parse(result.body)
    assert_equal "connection_failed", body["error"]
  end

  def test_connection_failed_body_is_retryable
    error = Faraday::ConnectionFailed.new("Connection refused")
    result = @client.send(:handle_error, error)
    body = JSON.parse(result.body)
    assert_equal true, body["retryable"]
  end

  # ---------------------------------------------------------------------------
  # handle_error — Faraday::Error with response → forward actual status
  # ---------------------------------------------------------------------------

  def test_error_with_response_forwards_actual_status
    response = { status: 429, body: '{"error":"rate_limited"}', headers: {} }
    error = Faraday::ClientError.new("rate limited", response)
    result = @client.send(:handle_error, error)
    assert_equal 429, result.status
  end

  def test_error_with_response_forwards_actual_body
    response = { status: 422, body: '{"error":"unprocessable"}', headers: {} }
    error = Faraday::ClientError.new("unprocessable", response)
    result = @client.send(:handle_error, error)
    assert_equal '{"error":"unprocessable"}', result.body
  end

  # ---------------------------------------------------------------------------
  # handle_error — unknown Faraday::Error without response → 502
  # ---------------------------------------------------------------------------

  def test_unknown_error_without_response_returns_502
    error = Faraday::Error.new("something unexpected")
    result = @client.send(:handle_error, error)
    assert_equal 502, result.status
  end

  def test_unknown_error_body_includes_bad_gateway_key
    error = Faraday::Error.new("something unexpected")
    result = @client.send(:handle_error, error)
    body = JSON.parse(result.body)
    assert_equal "bad_gateway", body["error"]
  end

  # ---------------------------------------------------------------------------
  # Timeout default — both connection methods default to 300s
  # ---------------------------------------------------------------------------

  def test_chat_connection_timeout_default_is_300
    # Temporarily unset OLLAMA_TIMEOUT to test default
    original = ENV.delete("OLLAMA_TIMEOUT")
    client = OllamaClient.new(url: "http://localhost:8765/v1/chat/completions")
    # Access the connection to trigger lazy initialization
    conn = client.send(:chat_connection)
    assert_equal 300, conn.options.timeout
  ensure
    ENV["OLLAMA_TIMEOUT"] = original if original
  end

  def test_connection_timeout_default_is_300
    original = ENV.delete("OLLAMA_TIMEOUT")
    client = OllamaClient.new(url: "http://localhost:8765/v1/chat/completions")
    conn = client.send(:connection)
    assert_equal 300, conn.options.timeout
  ensure
    ENV["OLLAMA_TIMEOUT"] = original if original
  end

  def test_ollama_timeout_env_overrides_default
    ENV["OLLAMA_TIMEOUT"] = "60"
    client = OllamaClient.new(url: "http://localhost:8765/v1/chat/completions")
    conn = client.send(:chat_connection)
    assert_equal 60, conn.options.timeout
  ensure
    ENV.delete("OLLAMA_TIMEOUT")
  end

  # ---------------------------------------------------------------------------
  # chat_connection — no retry middleware
  # ---------------------------------------------------------------------------

  def test_chat_connection_has_no_retry_middleware
    client = OllamaClient.new(url: "http://localhost:8765/v1/chat/completions")
    conn = client.send(:chat_connection)
    # Faraday builder exposes middleware stack via builder.handlers
    handler_names = conn.builder.handlers.map(&:name)
    refute_includes handler_names, "Faraday::Request::Retry",
      "chat_connection must NOT have retry middleware — retrying into a slow MLX server " \
      "adds KV cache pressure. See 500-ERROR-ROOT-CAUSE-AND-FIX.md"
  end
end
