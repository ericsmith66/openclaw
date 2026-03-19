# frozen_string_literal: true

require "test_helper"

class SSEParserTest < Minitest::Test
  def test_parse_yields_content_chunks
    io = StringIO.new(<<~SSE)
      data: {"choices":[{"delta":{"role":"assistant"}}]}
      data: {"choices":[{"delta":{"content":"Hello"}}]}
      data: {"choices":[{"delta":{"content":" world"}}]}
      data: [DONE]
    SSE
    chunks = []
    result = AgentDesk::Models::SSEParser.parse(io) { |chunk| chunks << chunk }
    assert_equal 2, chunks.size
    assert_equal "Hello", chunks.first[:content]
    assert_equal " world", chunks.last[:content]
    assert_equal "assistant", result[:role]
    assert_equal "Hello world", result[:content]
    assert_nil result[:tool_calls]
    assert_equal({ prompt_tokens: 0, completion_tokens: 0, total_tokens: 0 }, result[:usage])
    assert_nil result[:finish_reason]
  end

  def test_parse_ignores_empty_lines
    io = StringIO.new(<<~SSE)


      data: {"choices":[{"delta":{"role":"assistant"}}]}

      data: {"choices":[{"delta":{"content":"Hi"}}]}

      data: [DONE]
    SSE
    chunks = []
    result = AgentDesk::Models::SSEParser.parse(io) { |chunk| chunks << chunk }
    assert_equal 1, chunks.size
    assert_equal "Hi", result[:content]
  end

  def test_parse_stops_at_done_marker
    io = StringIO.new(<<~SSE)
      data: {"choices":[{"delta":{"content":"Hello"}}]}
      data: [DONE]
      data: {"should":"be ignored"}
    SSE
    chunks = []
    result = AgentDesk::Models::SSEParser.parse(io) { |chunk| chunks << chunk }
    assert_equal 1, chunks.size
    assert_equal "Hello", result[:content]
  end

  def test_parse_returns_accumulated_content
    io = StringIO.new(<<~SSE)
      data: {"choices":[{"delta":{"role":"assistant"}}]}
      data: {"choices":[{"delta":{"content":"Hello"}}]}
      data: {"choices":[{"delta":{"content":" "}}]}
      data: {"choices":[{"delta":{"content":"world"}}]}
      data: [DONE]
    SSE
    result = AgentDesk::Models::SSEParser.parse(io) { |_| }
    assert_equal "Hello world", result[:content]
  end

  def test_parse_accumulates_tool_calls_by_index
    io = StringIO.new(<<~SSE)
      data: {"choices":[{"delta":{"role":"assistant"}}]}
      data: {"choices":[{"delta":{"tool_calls":[{"index":0,"id":"call_1","function":{"name":"tool"}}]}}]}
      data: {"choices":[{"delta":{"tool_calls":[{"index":0,"function":{"arguments":"{\\"city\\":\\"Boston\\"}"}}]}}]}
      data: [DONE]
    SSE
    result = AgentDesk::Models::SSEParser.parse(io) { |_| }
    assert_equal 1, result[:tool_calls].size
    assert_equal "call_1", result[:tool_calls].first[:id]
    assert_equal "tool", result[:tool_calls].first.dig(:function, :name)
    assert_equal({ "city" => "Boston" }, result[:tool_calls].first.dig(:function, :arguments))
  end

  def test_parse_handles_multiple_parallel_tool_calls
    io = StringIO.new(<<~SSE)
      data: {"choices":[{"delta":{"role":"assistant"}}]}
      data: {"choices":[{"delta":{"tool_calls":[{"index":0,"id":"call_1","function":{"name":"tool1"}}]}}]}
      data: {"choices":[{"delta":{"tool_calls":[{"index":1,"id":"call_2","function":{"name":"tool2"}}]}}]}
      data: {"choices":[{"delta":{"tool_calls":[{"index":0,"function":{"arguments":"{}"}}]}}]}
      data: {"choices":[{"delta":{"tool_calls":[{"index":1,"function":{"arguments":"{\\"x\\":1}"}}]}}]}
      data: [DONE]
    SSE
    result = AgentDesk::Models::SSEParser.parse(io) { |_| }
    assert_equal 2, result[:tool_calls].size
    assert_equal "tool1", result[:tool_calls][0][:function][:name]
    assert_equal({}, result[:tool_calls][0][:function][:arguments])
    assert_equal "tool2", result[:tool_calls][1][:function][:name]
    assert_equal({ "x" => 1 }, result[:tool_calls][1][:function][:arguments])
  end

  def test_parse_parses_accumulated_tool_call_arguments
    io = StringIO.new(<<~SSE)
      data: {"choices":[{"delta":{"role":"assistant"}}]}
      data: {"choices":[{"delta":{"tool_calls":[{"index":0,"id":"call_1","function":{"name":"tool","arguments":"{\\"a\\":1"}}]}}]}
      data: {"choices":[{"delta":{"tool_calls":[{"index":0,"function":{"arguments":",\\"b\\":2}"}}]}}]}
      data: [DONE]
    SSE
    result = AgentDesk::Models::SSEParser.parse(io) { |_| }
    assert_equal({ "a" => 1, "b" => 2 }, result[:tool_calls].first.dig(:function, :arguments))
  end

  def test_parse_handles_malformed_tool_call_arguments
    io = StringIO.new(<<~SSE)
      data: {"choices":[{"delta":{"role":"assistant"}}]}
      data: {"choices":[{"delta":{"tool_calls":[{"index":0,"id":"call_1","function":{"name":"tool","arguments":"invalid"}}]}}]}
      data: [DONE]
    SSE
    result = AgentDesk::Models::SSEParser.parse(io) { |_| }
    assert_equal({}, result[:tool_calls].first.dig(:function, :arguments))
  end

  def test_parse_captures_finish_reason
    io = StringIO.new(<<~SSE)
      data: {"choices":[{"delta":{"role":"assistant"}}]}
      data: {"choices":[{"delta":{"content":"Hello"}}]}
      data: {"choices":[{"finish_reason":"stop"}]}
      data: [DONE]
    SSE
    result = AgentDesk::Models::SSEParser.parse(io) { |_| }
    assert_equal "stop", result[:finish_reason]
  end

  def test_parse_handles_data_without_space_after_colon
    io = StringIO.new(<<~SSE)
      data:{"choices":[{"delta":{"role":"assistant"}}]}
      data:{"choices":[{"delta":{"content":"Hello"}}]}
      data: [DONE]
    SSE
    chunks = []
    result = AgentDesk::Models::SSEParser.parse(io) { |chunk| chunks << chunk }
    assert_equal "Hello", result[:content]
  end

  def test_parse_skips_non_json_data_lines
    io = StringIO.new(<<~SSE)
      data: comment line
      data: {"choices":[{"delta":{"role":"assistant"}}]}
      data: {"choices":[{"delta":{"content":"Hello"}}]}
      data: [DONE]
    SSE
    chunks = []
    result = AgentDesk::Models::SSEParser.parse(io) { |chunk| chunks << chunk }
    assert_equal "Hello", result[:content]
  end

  def test_parse_handles_missing_delta_content
    io = StringIO.new(<<~SSE)
      data: {"choices":[{"delta":{"role":"assistant"}}]}
      data: {"choices":[{}]}
      data: [DONE]
    SSE
    result = AgentDesk::Models::SSEParser.parse(io) { |_| }
    assert_equal "assistant", result[:role]
    assert_nil result[:content]
  end

  def test_parse_captures_role_from_first_delta
    io = StringIO.new(<<~SSE)
      data: {"choices":[{"delta":{"role":"assistant"}}]}
      data: [DONE]
    SSE
    result = AgentDesk::Models::SSEParser.parse(io) { |_| }
    assert_equal "assistant", result[:role]
  end

  def test_parse_handles_usage_in_final_chunk
    io = StringIO.new(<<~SSE)
      data: {"choices":[{"delta":{"role":"assistant"}}]}
      data: {"choices":[{"delta":{"content":"Hello"}}]}
      data: {"usage":{"prompt_tokens":5,"completion_tokens":10,"total_tokens":15}}
      data: [DONE]
    SSE
    result = AgentDesk::Models::SSEParser.parse(io) { |_| }
    assert_equal({ prompt_tokens: 5, completion_tokens: 10, total_tokens: 15 }, result[:usage])
  end

  def test_parse_returns_nil_content_when_no_content_deltas
    io = StringIO.new(<<~SSE)
      data: {"choices":[{"delta":{"role":"assistant"}}]}
      data: [DONE]
    SSE
    result = AgentDesk::Models::SSEParser.parse(io) { |_| }
    assert_nil result[:content]
  end
end
