# frozen_string_literal: true

require "test_helper"

class TaskToolsContractTest < Minitest::Test
  def setup
    @tool_set = AgentDesk::Tools::TaskTools.create
  end

  def test_list_tasks_tool_exists
    tool = @tool_set[AgentDesk.tool_id("tasks", "list_tasks")]
    assert tool
    result = tool.execute({})
    assert_kind_of String, result
  end

  def test_get_task_tool_exists
    tool = @tool_set[AgentDesk.tool_id("tasks", "get_task")]
    assert tool
    result = tool.execute({ "id" => "non-existent" })
    assert_kind_of String, result
  end

  def test_create_task_tool_exists
    tool = @tool_set[AgentDesk.tool_id("tasks", "create_task")]
    assert tool
    result = tool.execute({ "name" => "Test", "prompt" => "Prompt" })
    assert_kind_of String, result
  end

  def test_delete_task_tool_exists
    tool = @tool_set[AgentDesk.tool_id("tasks", "delete_task")]
    assert tool
    result = tool.execute({ "id" => "non-existent" })
    assert_kind_of String, result
  end

  def test_get_task_message_tool_exists
    tool = @tool_set[AgentDesk.tool_id("tasks", "get_task_message")]
    assert tool
    result = tool.execute({ "taskId" => "non-existent", "messageIndex" => 0 })
    assert_kind_of String, result
  end

  def test_search_task_tool_exists
    tool = @tool_set[AgentDesk.tool_id("tasks", "search_task")]
    assert tool
    result = tool.execute({ "taskId" => "non-existent", "query" => "anything" })
    assert_kind_of String, result
  end

  def test_search_parent_task_tool_exists
    tool = @tool_set[AgentDesk.tool_id("tasks", "search_parent_task")]
    assert tool
    result = tool.execute({ "taskId" => "non-existent", "query" => "anything" })
    assert_kind_of String, result
  end
end
