# frozen_string_literal: true

require "test_helper"

class MockModelManagerTest < Minitest::Test
  def setup
    @mock = AgentDesk::Test::MockModelManager.new
  end

  # --- Default response shape ---

  def test_default_response_has_correct_keys
    response = @mock.chat(messages: [])
    assert_respond_to response, :keys
    assert response.key?(:role),       "response must have :role key"
    assert response.key?(:content),    "response must have :content key"
    assert response.key?(:tool_calls), "response must have :tool_calls key"
    assert response.key?(:usage),      "response must have :usage key"
  end

  def test_text_only_response_content
    response = @mock.chat(messages: [], tools: [])
    assert_equal "assistant", response[:role]
    assert_equal "Mock response", response[:content]
    assert_nil response[:tool_calls]
  end

  def test_default_response_usage_is_normalized_hash
    response = @mock.chat(messages: [])
    assert_equal({ prompt_tokens: 0, completion_tokens: 0, total_tokens: 0 }, response[:usage])
  end

  # --- Custom tool-call responses ---

  def test_tool_call_response
    tool_call = { id: "call_1", function: { name: "search", arguments: { "q" => "hello" } } }
    mock = AgentDesk::Test::MockModelManager.new(
      responses: [
        {
          role: "assistant",
          content: nil,
          tool_calls: [ tool_call ],
          usage: { prompt_tokens: 10, completion_tokens: 5, total_tokens: 15 }
        }
      ]
    )
    response = mock.chat(messages: [], tools: [])
    assert_nil response[:content]
    assert_equal 1, response[:tool_calls].size
    assert_equal "call_1", response[:tool_calls].first[:id]
    assert_equal "search", response[:tool_calls].first.dig(:function, :name)
    assert_equal({ prompt_tokens: 10, completion_tokens: 5, total_tokens: 15 }, response[:usage])
  end

  # --- Multi-turn conversation ---

  def test_multi_turn_tool_calls
    mock = AgentDesk::Test::MockModelManager.new(
      responses: [
        {
          role: "assistant",
          content: nil,
          tool_calls: [ { id: "1", function: { name: "tool1", arguments: {} } } ],
          usage: { prompt_tokens: 5, completion_tokens: 3, total_tokens: 8 }
        },
        {
          role: "assistant",
          content: "Final answer",
          tool_calls: nil,
          usage: { prompt_tokens: 20, completion_tokens: 10, total_tokens: 30 }
        }
      ]
    )
    # First call returns tool call
    response1 = mock.chat(messages: [], tools: [])
    assert_nil response1[:content]
    refute_nil response1[:tool_calls]
    assert_equal "assistant", response1[:role]
    # Second call returns text
    response2 = mock.chat(messages: [], tools: [])
    assert_equal "Final answer", response2[:content]
    assert_nil response2[:tool_calls]
    assert_equal "assistant", response2[:role]
  end

  def test_exhausted_responses_return_default
    mock = AgentDesk::Test::MockModelManager.new(responses: [])
    response = mock.chat(messages: [])
    assert_equal "Mock response", response[:content]
    assert_equal "assistant", response[:role]
  end

  # --- Call recording ---

  def test_records_chat_calls
    @mock.chat(messages: [ { role: "user", content: "Hello" } ], tools: [], temperature: 0.5, max_tokens: 100)
    assert_equal 1, @mock.calls.size
    call = @mock.calls.first
    assert_equal [ { role: "user", content: "Hello" } ], call[:messages]
    assert_equal [], call[:tools]
    assert_equal 0.5, call[:temperature]
    assert_equal 100, call[:max_tokens]
  end

  def test_records_multiple_calls
    @mock.chat(messages: [ { role: "user", content: "First" } ])
    @mock.chat(messages: [ { role: "user", content: "Second" } ])
    assert_equal 2, @mock.calls.size
  end

  # --- Streaming simulation ---

  def test_streaming_yields_content_chunks_when_block_given
    mock = AgentDesk::Test::MockModelManager.new(
      responses: [
        {
          role: "assistant",
          content: "Hello world",
          tool_calls: nil,
          usage: { prompt_tokens: 5, completion_tokens: 5, total_tokens: 10 }
        }
      ]
    )
    chunks = []
    response = mock.chat(messages: []) { |chunk| chunks << chunk }
    refute_empty chunks
    joined = chunks.map { |c| c[:content] }.join
    assert_equal "Hello world", joined
    # Full response still returned
    assert_equal "Hello world", response[:content]
  end

  def test_no_streaming_when_no_block_given
    # Should not raise even without a block
    response = @mock.chat(messages: [])
    assert_equal "Mock response", response[:content]
  end

  def test_no_streaming_for_nil_content_response
    mock = AgentDesk::Test::MockModelManager.new(
      responses: [
        {
          role: "assistant",
          content: nil,
          tool_calls: [ { id: "1", function: { name: "fn", arguments: {} } } ],
          usage: { prompt_tokens: 3, completion_tokens: 2, total_tokens: 5 }
        }
      ]
    )
    chunks = []
    mock.chat(messages: []) { |chunk| chunks << chunk }
    assert_empty chunks
  end
end
