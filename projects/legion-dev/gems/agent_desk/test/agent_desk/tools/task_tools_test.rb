# frozen_string_literal: true

require "test_helper"
require "json"

class TaskToolsTest < Minitest::Test
  def setup
    @registry = AgentDesk::Tools::TaskTools::TaskRegistry.new
    @tool_set = AgentDesk::Tools::TaskTools.create(registry: @registry)
  end

  def tool(name)
    @tool_set[AgentDesk.tool_id(AgentDesk::TASKS_TOOL_GROUP_NAME, name)]
  end

  def parse(raw)
    JSON.parse(raw, symbolize_names: true)
  end

  def test_create_and_list_tasks
    create_tool = tool(AgentDesk::TASKS_TOOL_CREATE_TASK)
    list_tool = tool(AgentDesk::TASKS_TOOL_LIST_TASKS)

    raw = create_tool.execute({ "name" => "Task 1", "prompt" => "Do something" })
    parsed = parse(raw)
    assert_equal "Task 1", parsed[:name]
    assert_equal "Do something", parsed[:prompt]
    assert_match(/\A[0-9a-f\-]{36}\z/, parsed[:id])

    raw = list_tool.execute({})
    parsed = parse(raw)
    assert_equal 1, parsed.size
    assert_equal "Task 1", parsed[0][:name]
  end

  def test_get_task_by_id
    create_tool = tool(AgentDesk::TASKS_TOOL_CREATE_TASK)
    raw = create_tool.execute({ "name" => "Find me", "prompt" => "Prompt" })
    created = parse(raw)
    task_id = created[:id]

    get_tool = tool(AgentDesk::TASKS_TOOL_GET_TASK)
    raw = get_tool.execute({ "id" => task_id })
    retrieved = parse(raw)
    assert_equal "Find me", retrieved[:name]
    assert_equal task_id, retrieved[:id]
  end

  def test_get_task_not_found
    get_tool = tool(AgentDesk::TASKS_TOOL_GET_TASK)
    raw = get_tool.execute({ "id" => "non-existent-uuid" })
    parsed = parse(raw)
    assert_equal "task not found", parsed[:error]
    assert_equal "non-existent-uuid", parsed[:id]
  end

  def test_delete_task_returns_true
    create_tool = tool(AgentDesk::TASKS_TOOL_CREATE_TASK)
    raw = create_tool.execute({ "name" => "Delete me", "prompt" => "..." })
    created = parse(raw)
    task_id = created[:id]

    delete_tool = tool(AgentDesk::TASKS_TOOL_DELETE_TASK)
    raw = delete_tool.execute({ "id" => task_id })
    parsed = parse(raw)
    assert_equal true, parsed[:deleted]

    get_tool = tool(AgentDesk::TASKS_TOOL_GET_TASK)
    raw = get_tool.execute({ "id" => task_id })
    parsed = parse(raw)
    assert_equal "task not found", parsed[:error]
  end

  def test_delete_nonexistent_returns_false
    delete_tool = tool(AgentDesk::TASKS_TOOL_DELETE_TASK)
    raw = delete_tool.execute({ "id" => "non-existent-uuid" })
    parsed = parse(raw)
    assert_equal false, parsed[:deleted]
  end

  def test_get_task_message_index_0
    create_tool = tool(AgentDesk::TASKS_TOOL_CREATE_TASK)
    raw = create_tool.execute({ "name" => "Message test", "prompt" => "Initial prompt content" })
    created = parse(raw)
    task_id = created[:id]

    msg_tool = tool(AgentDesk::TASKS_TOOL_GET_TASK_MESSAGE)
    raw = msg_tool.execute({ "taskId" => task_id, "messageIndex" => 0 })
    parsed = parse(raw)
    assert_equal 0, parsed[:index]
    assert_equal "user", parsed[:role]
    assert_equal "Initial prompt content", parsed[:content]
  end

  def test_get_task_message_out_of_range
    create_tool = tool(AgentDesk::TASKS_TOOL_CREATE_TASK)
    raw = create_tool.execute({ "name" => "Out of range", "prompt" => "..." })
    created = parse(raw)
    task_id = created[:id]

    msg_tool = tool(AgentDesk::TASKS_TOOL_GET_TASK_MESSAGE)
    raw = msg_tool.execute({ "taskId" => task_id, "messageIndex" => 5 })
    parsed = parse(raw)
    assert_equal "message index out of range", parsed[:error]
  end

  def test_search_task_returns_empty_array
    search_tool = tool(AgentDesk::TASKS_TOOL_SEARCH_TASK)
    raw = search_tool.execute({ "taskId" => "any-id", "query" => "anything" })
    parsed = parse(raw)
    assert_equal [], parsed
  end

  def test_search_parent_task_returns_empty_array
    search_tool = tool(AgentDesk::TASKS_TOOL_SEARCH_PARENT_TASK)
    raw = search_tool.execute({ "taskId" => "any-id", "query" => "anything" })
    parsed = parse(raw)
    assert_equal [], parsed
  end

  def test_all_tools_exist
    expected = [
      AgentDesk::TASKS_TOOL_LIST_TASKS,
      AgentDesk::TASKS_TOOL_GET_TASK,
      AgentDesk::TASKS_TOOL_CREATE_TASK,
      AgentDesk::TASKS_TOOL_DELETE_TASK,
      AgentDesk::TASKS_TOOL_GET_TASK_MESSAGE,
      AgentDesk::TASKS_TOOL_SEARCH_TASK,
      AgentDesk::TASKS_TOOL_SEARCH_PARENT_TASK
    ]
    expected.each do |name|
      t = tool(name)
      refute_nil t, "missing tool #{name}"
      assert_kind_of AgentDesk::Tools::BaseTool, t
    end
  end
end
