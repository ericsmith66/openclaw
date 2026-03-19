# frozen_string_literal: true

require "test_helper"

class ErrorsTest < Minitest::Test
  def test_error_inherits_from_standard_error
    assert_kind_of StandardError, AgentDesk::Error.new("test")
  end

  def test_configuration_error_inherits_from_error
    error = AgentDesk::ConfigurationError.new("missing api_key")
    assert_kind_of AgentDesk::Error, error
    assert_equal "missing api_key", error.message
  end

  def test_llm_error_inherits_from_error
    error = AgentDesk::LLMError.new("API error", status: 400, response_body: "Bad Request")
    assert_kind_of AgentDesk::Error, error
    assert_equal "API error", error.message
  end

  def test_llm_error_carries_status_and_response_body
    error = AgentDesk::LLMError.new("Not found", status: 404, response_body: "{}")
    assert_equal 404, error.status
    assert_equal "{}", error.response_body
  end

  def test_llm_error_accepts_nil_status_and_response_body
    error = AgentDesk::LLMError.new("parse error")
    assert_nil error.status
    assert_nil error.response_body
  end

  def test_timeout_error_inherits_from_error
    error = AgentDesk::TimeoutError.new("request timed out")
    assert_kind_of AgentDesk::Error, error
    assert_equal "request timed out", error.message
  end

  def test_stream_error_inherits_from_error
    error = AgentDesk::StreamError.new("stream interrupted", partial_content: "partial")
    assert_kind_of AgentDesk::Error, error
    assert_equal "stream interrupted", error.message
  end

  def test_stream_error_carries_partial_content
    error = AgentDesk::StreamError.new("stream interrupted", partial_content: "partial")
    assert_equal "partial", error.partial_content
  end

  def test_stream_error_accepts_nil_partial_content
    error = AgentDesk::StreamError.new("stream interrupted")
    assert_nil error.partial_content
  end
end
