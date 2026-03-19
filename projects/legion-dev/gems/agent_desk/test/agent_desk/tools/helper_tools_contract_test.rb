# frozen_string_literal: true

require "test_helper"

class HelperToolsContractTest < Minitest::Test
  def setup
    @tool_set = AgentDesk::Tools::HelperTools.create
  end

  def test_no_such_tool_tool_exists
    tool = @tool_set[AgentDesk.tool_id("helpers", "no_such_tool")]
    assert tool
    result = tool.execute({
      "toolName" => "fake---tool",
      "availableTools" => [ "power---bash" ]
    })
    assert_kind_of String, result
  end

  def test_invalid_tool_arguments_tool_exists
    tool = @tool_set[AgentDesk.tool_id("helpers", "invalid_tool_arguments")]
    assert tool
    result = tool.execute({
      "toolName" => "power---bash",
      "toolInput" => '{"command": 123}',
      "error" => "property 'command' must be a string"
    })
    assert_kind_of String, result
  end
end
