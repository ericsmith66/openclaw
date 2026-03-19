# frozen_string_literal: true

require "test_helper"

class ResponseNormalizerTest < Minitest::Test
  def test_normalize_with_full_response
    raw = {
      "choices" => [ {
        "message" => {
          "role" => "assistant",
          "content" => "Hello",
          "tool_calls" => [
            {
              "id" => "call_1",
              "function" => { "name" => "tool", "arguments" => "{}" }
            }
          ]
        }
      } ],
      "usage" => { "prompt_tokens" => 5, "completion_tokens" => 10, "total_tokens" => 15 }
    }
    normalized = AgentDesk::Models::ResponseNormalizer.normalize(raw)
    assert_equal "assistant", normalized[:role]
    assert_equal "Hello", normalized[:content]
    assert_equal 1, normalized[:tool_calls].size
    assert_equal "call_1", normalized[:tool_calls].first[:id]
    assert_equal "tool", normalized[:tool_calls].first.dig(:function, :name)
    assert_equal({}, normalized[:tool_calls].first.dig(:function, :arguments))
    assert_equal({ prompt_tokens: 5, completion_tokens: 10, total_tokens: 15 }, normalized[:usage])
  end

  def test_normalize_without_tool_calls
    raw = {
      "choices" => [ {
        "message" => {
          "role" => "assistant",
          "content" => "Hello"
        }
      } ]
    }
    normalized = AgentDesk::Models::ResponseNormalizer.normalize(raw)
    assert_equal "assistant", normalized[:role]
    assert_equal "Hello", normalized[:content]
    assert_nil normalized[:tool_calls]
    assert_equal({ prompt_tokens: 0, completion_tokens: 0, total_tokens: 0 }, normalized[:usage])
  end

  def test_normalize_with_empty_tool_calls_array
    raw = {
      "choices" => [ {
        "message" => {
          "role" => "assistant",
          "content" => "Hello",
          "tool_calls" => []
        }
      } ]
    }
    normalized = AgentDesk::Models::ResponseNormalizer.normalize(raw)
    assert_nil normalized[:tool_calls]
  end

  def test_normalize_without_usage
    raw = {
      "choices" => [ {
        "message" => {
          "role" => "assistant",
          "content" => "Hello"
        }
      } ]
    }
    normalized = AgentDesk::Models::ResponseNormalizer.normalize(raw)
    assert_equal({ prompt_tokens: 0, completion_tokens: 0, total_tokens: 0 }, normalized[:usage])
  end

  def test_normalize_with_partial_usage
    raw = {
      "choices" => [ {
        "message" => {
          "role" => "assistant",
          "content" => "Hello"
        }
      } ],
      "usage" => { "prompt_tokens" => 5 }
    }
    normalized = AgentDesk::Models::ResponseNormalizer.normalize(raw)
    assert_equal({ prompt_tokens: 5, completion_tokens: 0, total_tokens: 0 }, normalized[:usage])
  end

  def test_normalize_tool_calls_parses_arguments
    raw_tool_calls = [
      {
        "id" => "call_1",
        "function" => { "name" => "tool", "arguments" => '{"key":"value"}' }
      }
    ]
    normalized = AgentDesk::Models::ResponseNormalizer.normalize_tool_calls(raw_tool_calls)
    assert_equal "call_1", normalized.first[:id]
    assert_equal "tool", normalized.first.dig(:function, :name)
    assert_equal({ "key" => "value" }, normalized.first.dig(:function, :arguments))
  end

  def test_normalize_tool_calls_handles_malformed_json_arguments
    raw_tool_calls = [
      {
        "id" => "call_1",
        "function" => { "name" => "tool", "arguments" => "invalid json" }
      }
    ]
    normalized = AgentDesk::Models::ResponseNormalizer.normalize_tool_calls(raw_tool_calls)
    assert_equal({}, normalized.first.dig(:function, :arguments))
  end

  def test_normalize_tool_calls_handles_nil_arguments
    raw_tool_calls = [
      {
        "id" => "call_1",
        "function" => { "name" => "tool", "arguments" => nil }
      }
    ]
    normalized = AgentDesk::Models::ResponseNormalizer.normalize_tool_calls(raw_tool_calls)
    assert_equal({}, normalized.first.dig(:function, :arguments))
  end

  def test_normalize_usage_defaults_to_zero
    assert_equal({ prompt_tokens: 0, completion_tokens: 0, total_tokens: 0 },
                 AgentDesk::Models::ResponseNormalizer.normalize_usage(nil))
  end

  def test_normalize_handles_missing_choices
    raw = {}
    normalized = AgentDesk::Models::ResponseNormalizer.normalize(raw)
    assert_nil normalized[:role]
    assert_nil normalized[:content]
    assert_nil normalized[:tool_calls]
    assert_equal({ prompt_tokens: 0, completion_tokens: 0, total_tokens: 0 }, normalized[:usage])
  end

  def test_normalize_preserves_reasoning_content
    raw = {
      "choices" => [ {
        "message" => {
          "role" => "assistant",
          "content" => "The answer is 42",
          "reasoning_content" => "Let me think step by step..."
        }
      } ]
    }
    normalized = AgentDesk::Models::ResponseNormalizer.normalize(raw)
    assert_equal "The answer is 42", normalized[:content]
    assert_equal "Let me think step by step...", normalized[:reasoning_content]
  end

  def test_normalize_omits_reasoning_content_when_absent
    raw = {
      "choices" => [ {
        "message" => {
          "role" => "assistant",
          "content" => "Hello"
        }
      } ]
    }
    normalized = AgentDesk::Models::ResponseNormalizer.normalize(raw)
    refute normalized.key?(:reasoning_content)
  end
end
