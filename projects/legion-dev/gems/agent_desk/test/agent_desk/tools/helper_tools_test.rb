# frozen_string_literal: true

require "test_helper"
require "json"

class HelperToolsTest < Minitest::Test
  def setup
    @tool_set = AgentDesk::Tools::HelperTools.create(available_tools: [ "power---bash", "power---glob" ])
  end

  def tool(name)
    @tool_set[AgentDesk.tool_id(AgentDesk::HELPERS_TOOL_GROUP_NAME, name)]
  end

  def parse(raw)
    JSON.parse(raw, symbolize_names: true)
  end

  def test_no_such_tool_returns_error
    tool = tool(AgentDesk::HELPERS_TOOL_NO_SUCH_TOOL)
    refute_nil tool

    raw = tool.execute({
      "toolName" => "foo---bar",
      "availableTools" => [ "power---bash", "power---glob" ]
    })
    parsed = parse(raw)
    assert_equal "Tool 'foo---bar' does not exist.", parsed[:error]
    assert_equal [ "power---bash", "power---glob" ], parsed[:availableTools]
  end

  def test_no_such_tool_uses_args_available_tools
    tool = tool(AgentDesk::HELPERS_TOOL_NO_SUCH_TOOL)
    raw = tool.execute({
      "toolName" => "fake---tool",
      "availableTools" => [ "custom---tool" ]
    })
    parsed = parse(raw)
    assert_equal [ "custom---tool" ], parsed[:availableTools]
  end

  def test_invalid_tool_arguments_returns_message
    tool = tool(AgentDesk::HELPERS_TOOL_INVALID_TOOL_ARGUMENTS)
    refute_nil tool

    raw = tool.execute({
      "toolName" => "power---bash",
      "toolInput" => '{"command": 123}',
      "error" => "property 'command' must be a string"
    })
    parsed = parse(raw)
    assert_equal "Invalid arguments for tool 'power---bash'.", parsed[:error]
    assert_equal '{"command": 123}', parsed[:toolInput]
    assert_equal "property 'command' must be a string", parsed[:validationError]
  end

  def test_both_tools_exist
    expected = [
      AgentDesk::HELPERS_TOOL_NO_SUCH_TOOL,
      AgentDesk::HELPERS_TOOL_INVALID_TOOL_ARGUMENTS
    ]
    expected.each do |name|
      t = tool(name)
      refute_nil t, "missing tool #{name}"
      assert_kind_of AgentDesk::Tools::BaseTool, t
    end
  end
end
