require "test_helper"

class AgentHub::CommandParserTest < ActiveSupport::TestCase
  test "returns nil for non-command input" do
    assert_nil AgentHub::CommandParser.call("hello world")
  end

  test "parses /search command with args" do
    result = AgentHub::CommandParser.call("/search stock prices")
    assert_equal :search, result[:type]
    assert_equal "search", result[:command]
    assert_equal "stock prices", result[:args]
    assert_equal "/search stock prices", result[:raw]
  end

  test "parses /handoff command without args" do
    result = AgentHub::CommandParser.call("/handoff")
    assert_equal :handoff, result[:type]
    assert_equal "handoff", result[:command]
    assert_nil result[:args]
    assert_equal "/handoff", result[:raw]
  end

  test "returns type :unknown for unrecognized commands" do
    result = AgentHub::CommandParser.call("/invalid cmd")
    assert_equal :unknown, result[:type]
    assert_equal "invalid", result[:command]
    assert_equal "cmd", result[:args]
  end

  test "handles leading/trailing whitespace" do
    result = AgentHub::CommandParser.call("  /search test  ")
    assert_equal :search, result[:type]
    assert_equal "test", result[:args]
  end
end
