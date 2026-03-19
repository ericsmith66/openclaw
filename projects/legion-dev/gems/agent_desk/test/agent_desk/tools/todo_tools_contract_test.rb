# frozen_string_literal: true

require "test_helper"

class TodoToolsContractTest < Minitest::Test
  def setup
    @tool_set = AgentDesk::Tools::TodoTools.create
  end

  def test_set_items_tool_exists
    tool = @tool_set[AgentDesk.tool_id("todo", "set_items")]
    assert tool
    # Safe call with empty items returns a string
    result = tool.execute({ "items" => [] })
    assert_kind_of String, result
  end

  def test_get_items_tool_exists
    tool = @tool_set[AgentDesk.tool_id("todo", "get_items")]
    assert tool
    result = tool.execute({})
    assert_kind_of String, result
  end

  def test_update_item_completion_tool_exists
    tool = @tool_set[AgentDesk.tool_id("todo", "update_item_completion")]
    assert tool
    result = tool.execute({ "name" => "dummy", "completed" => false })
    assert_kind_of String, result
  end

  def test_clear_items_tool_exists
    tool = @tool_set[AgentDesk.tool_id("todo", "clear_items")]
    assert tool
    result = tool.execute({})
    assert_kind_of String, result
  end
end
